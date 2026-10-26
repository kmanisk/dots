# Wayland Screen Sharing & Overlay Cloaking Architecture

A deep technical guide on bypassing the Linux display server's screen-capture limitations to run invisible real-time AI overlays (Meetingly AI) during full-desktop screen sharing on Sway (Wayland).

---

## 1. Problem Statement: Why Window Cloaking Fails on Linux

On Windows and macOS, commercial and open-source interview copilots appear invisible during full-screen sharing by calling kernel- and compositor-level window protection APIs:
- **Windows**: The Desktop Window Manager (DWM) provides `SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE)`. When any screen capture API (DirectX Desktop Duplication, Windows Graphics Capture, BitBlt) grabs a frame, the DWM skips surfaces marked with this affinity bit during composition.
- **macOS**: Quartz Compositor provides `NSWindowSharingNone`. The compositor strips the window from the shared video buffer.

### The Architectural Limitation on Linux

```
X11 Architecture (Shared Buffer):
[ Client Window A ] \
[ Client Window B ] --+--> [ X11 Root Window Framebuffer ] ---> [ Screen Capture API ]
[ Overlay Window  ] /       (No client isolation; ANY app can read all pixels)

Standard Wayland / Sway Architecture (wlr-screencopy):
[ Client Window A ] \
[ Client Window B ] --+--> [ Compositor Output Buffer: eDP-1 ] ---> [ PipeWire Stream ]
[ Overlay Window  ] /       (Everything rendered to eDP-1 is captured indiscriminately)
```

1. **X11 Has Zero Client Boundaries**: Any X11 client can read pixels from any other window or the root window via XComposite or `XGetImage`. There is no mechanism to hide a window from capture while showing it to the user.
2. **Wayland Screencopy Captures Full Output Buffers**: In wlroots-based compositors like Sway, screen sharing operates through `xdg-desktop-portal-wlr` using the `wlr-screencopy-unstable-v1` protocol. When you share an output (such as your physical monitor `eDP-1`), the compositor passes the final composited GPU framebuffer to PipeWire.
3. **Intentional Security Rejection**: Upstream Wayland protocol maintainers have deliberately rejected requests for an arbitrary `WDA_EXCLUDEFROMCAPTURE` window flag (tracked in KeePassXC Issue #10476). Exposing an API that allows windows to become invisible to screen recorders creates severe security risks, such as undetectable clickjacking overlays and silent keyloggers.

---

## 2. The Clean Virtual Headless Screen Architecture

To share a full desktop without leaking an overlay, the capture pipeline must be physically decoupled from the display scanout pipeline:

```
+---------------------------------------------------------------------------------------+
|                                    Sway Compositor                                    |
+---------------------------------------------------------------------------------------+
                                        |
                   +--------------------+--------------------+
                   |                                         |
                   v                                         v
   [ Virtual Output: HEADLESS-X ]             [ Physical Output: eDP-1 ]
   +----------------------------+             +----------------------------+
   | - Houses Work Workspace 1  |             | - Houses Workspace 2       |
   | - Contains IDE, Browser,   |             | - Tiled borderless window: |
   |   and active Terminal      |             |   wl-mirror (HEADLESS-X)   |
   | - Target of Keyboard Focus |             | - Floating & Sticky Layer: |
   +--------------+-------------+             |   Meetingly AI Overlay     |
                  |                           +----------------------------+
                  v                                         |
        wlr-screencopy buffer                               v
                  |                            Rendered ONLY to physical
                  v                            panel (invisible to portal)
      [ xdg-desktop-portal-wlr ]
                  |
                  v
         [ PipeWire Stream ]
                  |
                  v
       [ Google Meet / Zoom ]
```

### Core Components
1. **Dynamic Virtual Output (`HEADLESS-X`)**: Created in Sway userspace via `swaymsg create_output`. It functions as a fully operational monitor with its own workspace layout, but possesses no physical display panel.
2. **Work Relocation**: Your working applications (VS Code, terminal, browser) are relocated onto Workspace 1 on `HEADLESS-X`.
3. **Local Visual Bridge (`wl-mirror`)**: A lightweight Wayland client that captures the frame buffer of `HEADLESS-X` and renders it onto a window on your physical screen (`eDP-1`).
4. **Physical Overlay Isolation**: Meetingly AI is configured via Sway rules to remain strictly on `eDP-1` in the floating layer. Because Meetingly never touches the frame buffer of `HEADLESS-X`, it is physically impossible for the screencopy capture stream to record it.

---

## 3. Deep Dive: Three Critical Edge Cases and How They Were Solved

During the engineering of this pipeline on CachyOS with an RTX 5050 Laptop GPU and Sway 1.12, three critical bugs had to be resolved.

### Edge Case 1: Sway Stacking Order & Fullscreen Occlusion
- **The Pitfall**: An intuitive approach is to launch `wl-mirror` and enter `fullscreen enable` so it covers the entire 1920x1200 laptop panel.
- **The Mechanical Failure**: In Sway, when a window enters `fullscreen`, the compositor promotes that container above the workspace's floating layer. As a result, the fullscreen mirror completely occluded Meetingly, hiding the AI overlay from the user.
- **The Engineering Fix**: Configure `wl-mirror` as a **tiled window with zero borders**:
  ```ini
  for_window [app_id="^wl-mirror$"] border none, move to output eDP-1
  ```
  Because Sway's default layout on `eDP-1` is tabbed/tiled, a single borderless window fills 100% of the display area. Sway's floating layer (`floating enable, sticky enable`) renders strictly above all tiled windows, guaranteeing that Meetingly floats permanently on top of the mirror.

### Edge Case 2: Output Assignment vs. Active Workspace Movement
- **The Pitfall**: The initial script attempted to relocate the workspace using:
  ```bash
  swaymsg workspace 1 output "$HEADLESS_OUT"
  ```
- **The Mechanical Failure**: In Sway IPC, `workspace <num> output <name>` is a configuration directive that specifies where a workspace should be created *in the future*. It does **not** move an active, existing workspace. Workspace 1 remained on `eDP-1`, and `wl-mirror` ended up capturing an empty screen.
- **The Engineering Fix**: Use Sway's container criteria command to explicitly relocate the active workspace:
  ```bash
  swaymsg "[workspace=1] move workspace to output $HEADLESS_OUT"
  ```
- **Focus Routing**: When Workspace 1 moves to the headless display, `eDP-1` automatically displays an alternate workspace (Workspace 2) to host `wl-mirror`. If focus remained on `eDP-1`, all keyboard strokes would be swallowed by `wl-mirror` (which drops input). The start script explicitly routes keyboard focus back to Workspace 1:
  ```bash
  sleep 0.3
  swaymsg "[workspace=1] focus"
  ```
  Now, keyboard strokes go directly into your code editor on `HEADLESS-X`, while your eyes view the output through the mirror on `eDP-1`.

### Edge Case 3: Dynamic Display Resolution Matching
- **The Pitfall**: Hardcoding `1920x1200` breaks if the panel resolution changes or scaling is applied, resulting in black letterboxing or cropped video feeds in Google Meet.
- **The Engineering Fix**: Dynamically query `eDP-1`'s active geometry using `jq`:
  ```bash
  read -r W H < <(swaymsg -t get_outputs | jq -r '.[] | select(.name=="eDP-1") | "\(.current_mode.width) \(.current_mode.height)"')
  swaymsg output "$HEADLESS_OUT" resolution "${W}x${H}" position "$W" 0
  ```
  This creates a 1:1 pixel-accurate virtual canvas matching your laptop panel.

---

## 4. Audio Architecture & PipeWire Isolation

A common concern when creating virtual displays is whether the audio stack gets disrupted.

### Audio Pipeline Invariants
1. **Zero Virtual Audio Nodes**: Sway's `create_output` command operates entirely inside the wlroots compositor display pipeline. It creates DRM/Wayland surfaces only; it registers zero ALSA devices or PipeWire audio sinks.
2. **Source & Sink Verification**:
   ```bash
   pactl get-default-sink
   # Output: alsa_output.pci-0000_00_1f.3.analog-stereo (or active Dolby sink)

   pactl get-default-source
   # Output: ghelper-audio (virtual mic with DPDFNet neural denoising)
   ```
3. **Meetingly Dual-Stream Capture**:
   - Candidate Speech: Captured via `ghelper-audio` (internal laptop mic array).
   - Interviewer Speech: Captured via the PipeWire monitor source of the active output sink.

---

## 5. Complete Implementation & Script Architecture

### 5.1 Start Script: `meet-start.sh`
Located at [`/home/onyx/.local/bin/meet-start.sh`](file:///home/onyx/.local/bin/meet-start.sh):

```bash
#!/usr/bin/env bash
# meet-start.sh - Start clean virtual presentation mode for Sway
set -eo pipefail

# 1. Reuse or create HEADLESS output dynamically
HEADLESS_OUT=$(swaymsg -t get_outputs | jq -r '.[].name | select(startswith("HEADLESS-"))' | head -n1)
if [[ -z "$HEADLESS_OUT" ]]; then
    swaymsg create_output
    HEADLESS_OUT=$(swaymsg -t get_outputs | jq -r '.[].name | select(startswith("HEADLESS-"))' | head -n1)
fi

if [[ -z "$HEADLESS_OUT" ]]; then
    notify-send -a "Presentation Mode" -u critical -r 8899 -i dialog-error \
        "Presentation Mode: ERROR" "Failed to create headless display"
    exit 1
fi

# 2. Match eDP-1 panel resolution dynamically
read -r W H < <(swaymsg -t get_outputs | jq -r '.[] | select(.name=="eDP-1") | "\(.current_mode.width) \(.current_mode.height)"')
swaymsg output "$HEADLESS_OUT" resolution "${W}x${H}" position "$W" 0

# 3. Move work workspace 1 to the headless display
swaymsg "[workspace=1] move workspace to output $HEADLESS_OUT"

# 4. Launch wl-mirror (dragged to eDP-1 by window rule: border none, move to output eDP-1)
if ! pgrep -x "wl-mirror" > /dev/null; then
    wl-mirror "$HEADLESS_OUT" > /dev/null 2>&1 &
fi

# 5. Ensure keyboard focus is on Workspace 1 so typing routes to active apps
sleep 0.3
swaymsg "[workspace=1] focus"

# 6. Display notification (synchronous replace ID 8899 for Mako)
notify-send -a "Presentation Mode" -u normal -t 4000 -r 8899 -i video-display \
    "Presentation Mode: ON" \
    "Sharing Target: ${HEADLESS_OUT} (${W}x${H})\nMeetingly AI overlay cloaked"
```

### 5.2 Stop Script: `meet-stop.sh`
Located at [`/home/onyx/.local/bin/meet-stop.sh`](file:///home/onyx/.local/bin/meet-stop.sh):

```bash
#!/usr/bin/env bash
# meet-stop.sh - Stop clean virtual presentation mode and restore Sway state
set -eo pipefail

# 1. Terminate wl-mirror
pkill -x wl-mirror || true

# 2. Restore workspace 1 back to the physical panel eDP-1 and focus it
swaymsg "[workspace=1] move workspace to output eDP-1, workspace 1"

# 3. Unplug all active HEADLESS virtual outputs
for out in $(swaymsg -t get_outputs | jq -r '.[].name | select(startswith("HEADLESS-"))'); do
    swaymsg output "$out" unplug || true
done

# 4. Display notification
notify-send -a "Presentation Mode" -u normal -t 3000 -r 8899 -i video-display \
    "Presentation Mode: OFF" \
    "Headless display unplugged\nRestored to eDP-1"
```

### 5.3 Toggle Script: `meet-toggle.sh`
Located at [`/home/onyx/.local/bin/meet-toggle.sh`](file:///home/onyx/.local/bin/meet-toggle.sh):

```bash
#!/usr/bin/env bash
# meet-toggle.sh - Toggle Presentation Mode ON and OFF
set -eo pipefail

HAS_HEADLESS=$(swaymsg -t get_outputs | jq -r '.[].name | select(startswith("HEADLESS-"))' | head -n 1)

if [[ -n "$HAS_HEADLESS" ]] || pgrep -x "wl-mirror" > /dev/null; then
    exec "$HOME/.local/bin/meet-stop.sh"
else
    exec "$HOME/.local/bin/meet-start.sh"
fi
```

---

## 6. Sway Configuration Rules & Keybindings

Configured in [`~/.config/sway/config.d/30-window-rules.conf`](file:///home/onyx/.config/sway/config.d/30-window-rules.conf) and [`40-keybindings.conf`](file:///home/onyx/.config/sway/config.d/40-keybindings.conf):

```ini
# Window Rules
for_window [app_id="(?i)^meetingly.*"] floating enable, sticky enable, border pixel 1
for_window [class="(?i)^meetingly.*"] floating enable, sticky enable, border pixel 1
for_window [app_id="^wl-mirror$"] border none, move to output eDP-1

# Keybindings
bindsym $mod+Shift+m exec --no-startup-id ~/.local/bin/meet-toggle.sh
bindsym $mod+Shift+n exec --no-startup-id ~/.local/bin/meet-stop.sh
```

---

## 7. Operational Checklist for Interviews

1. **Before the Interview**:
   - Launch your code editor, terminal, and Brave on Workspace 1.
   - Launch Meetingly AI (`meetingly`).
   - Press **`Super + Shift + M`**.
   - Verify the Mako notification: `Presentation Mode: ON (Sharing Target: HEADLESS-X)`.
2. **In Google Meet**:
   - Click **Present now** -> select the **Entire Screen** tab.
   - Choose **`HEADLESS-X`** (never select `eDP-1`).
   - Click **Share**.
3. **During the Interview**:
   - Code, type, and navigate normally.
   - Meetingly displays transcription and AI answers on your laptop screen.
   - The remote video stream captures only `HEADLESS-X`, keeping the assistant 100% invisible.
4. **Teardown**:
   - Stop screen sharing in Google Meet.
   - Press **`Super + Shift + M`** (or `Super + Shift + N`) to restore your desktop layout.
