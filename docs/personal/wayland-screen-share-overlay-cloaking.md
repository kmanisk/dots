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
   | - Houses Work Workspace 2  |             | - Houses Alternate WS      |
   | - Contains Brave, IDE,     |             | - Tiled borderless window: |
   |   and active Terminal      |             |   wl-mirror (HEADLESS-X)   |
   | - Target of Keyboard Focus |             | - Floating Layer:          |
   | - Spawns any new windows   |             |   Meetingly AI Overlay     |
   | - Completely isolated from |             |   (Strictly pinned to      |
   |   Meetingly overlay        |             |    physical output eDP-1)  |
   +----------------------------+             +----------------------------+
                   |                                         |
                   v                                         v
       [ wlr-screencopy Portal ]                      [ Physical Eyes ]
                   |                               (Sees work + overlay)
                   v
          [ PipeWire Stream ]
                   |
                   v
        [ Google Meet / Zoom ]
```

### Core Components & Dynamics
1. **Dynamic Virtual Output (`HEADLESS-X`)**: Created in Sway userspace via `swaymsg create_output`. It functions as a fully operational monitor with its own workspace layout, but possesses no physical display panel.
2. **Workspace 2 as the Work Hub**: Workspace 2 hosts the entire interview workspace (Brave, code editor, terminals). In our Sway configuration, Brave is strictly bound via `assign` rules to Workspace 2 (`$ws2`). By migrating Workspace 2 to `HEADLESS-X`, all browser windows, meeting tabs, code editors, and terminals live on the shared display.
3. **Opening New Windows & Apps Dynamically**: Once `meet-start.sh` transfers Workspace 2 to `HEADLESS-X` and focuses it, **any new application or window you launch (terminals via `Super+Enter`, new browser windows via `Super+b`, or editor windows) automatically spawns on Workspace 2 inside `HEADLESS-X`**. It immediately mirrors onto your screen through `wl-mirror` and streams to Google Meet.
4. **Local Visual Bridge (`wl-mirror`)**: A lightweight Wayland client that captures the frame buffer of `HEADLESS-X` and renders it onto a window on your physical screen (`eDP-1`).
5. **Physical Overlay Isolation**: Meetingly AI is configured via Sway rules to remain strictly on `eDP-1` in the floating layer without `sticky enable`. Because Meetingly never touches the frame buffer of `HEADLESS-X`, it is physically impossible for the screencopy capture stream to record it.

---

## 3. Deep Dive: Edge Cases and Engineering Solutions

During live testing and implementation on CachyOS with Sway 1.12, seven distinct failure modes and edge cases were identified and solved.

### Edge Case 1: Sway Stacking Order and Fullscreen Occlusion
- **The Pitfall**: Launching `wl-mirror` and entering `fullscreen enable` so it covers the entire 1920x1200 laptop panel.
- **The Mechanical Failure**: In Sway, when a window enters `fullscreen`, the compositor promotes that container above the workspace floating layer. As a result, fullscreen `wl-mirror` completely occludes Meetingly, hiding the AI overlay from your view.
- **The Engineering Fix**: Configure `wl-mirror` as a **tiled window with zero borders**:
  ```ini
  for_window [app_id="(?i).*(wl[-_]?mirror|at\.yrlf\.wl_mirror).*"] border none, move to output eDP-1
  ```
  Because Sway fills the output with tiled windows, a single borderless window covers 100% of the display area. Sway floating layers render strictly above tiled containers, guaranteeing Meetingly floats permanently visible on top of the mirror.

### Edge Case 2: Output Assignment vs. Active Workspace Movement
- **The Pitfall**: Attempting to relocate the workspace using passive assignment:
  ```bash
  swaymsg workspace 2 output "$HEADLESS_OUT"
  ```
- **The Mechanical Failure**: In Sway IPC, `workspace <num> output <name>` is a configuration directive defining where that workspace should be instantiated in the future. It does **not** move an active, existing workspace. Workspace 2 remained on `eDP-1`, leaving `wl-mirror` capturing an empty output.
- **The Engineering Fix**: Use Sway criteria syntax to explicitly migrate the active container:
  ```bash
  swaymsg "[workspace=2] move workspace to output $HEADLESS_OUT"
  ```

### Edge Case 3: Workspace 2 Alignment (Brave Window Rules)
- **The Pitfall**: Moving Workspace 1 while Brave is strictly locked to Workspace 2 via configuration:
  ```ini
  assign [app_id="(?i)^(brave|brave-browser|brave-origin...)$"] workspace number $ws2
  for_window [app_id="(?i)^(brave...)$"] move to workspace number $ws2, floating disable, layout tabbed
  ```
- **The Mechanical Failure**: If the script targets Workspace 1, any new browser window or Google Meet tab gets forced back to Workspace 2 on `eDP-1`, colliding with `wl-mirror` and escaping the shared stream.
- **The Engineering Fix**: Target Workspace 2 (`TARGET_WS=2`) as the universal presentation workspace. All browser instances, meeting tabs, editor windows, and terminals remain unified on Workspace 2.

### Edge Case 4: The `sticky enable` Overlay Leak Trap
- **The Pitfall**: Configuring Meetingly with `sticky enable` to follow workspace changes:
  ```ini
  for_window [app_id="(?i)^meetingly.*"] floating enable, sticky enable, border pixel 1
  ```
- **The Mechanical Failure**: In Sway, `sticky enable` binds a floating container to the output's active workspace. If Workspace 2 is active on `eDP-1` when Meetingly launches, running `swaymsg "[workspace=2] move workspace to output $HEADLESS_OUT"` migrates the workspace and all attached floating containers onto `HEADLESS-OUT`. Meetingly ends up rendered inside the `HEADLESS-OUT` buffer, leaking directly into the Google Meet stream.
- **The Engineering Fix**: Drop `sticky enable` entirely. Instead, strictly pin Meetingly to `eDP-1`:
  ```ini
  for_window [app_id="(?i)^meetingly.*"] floating enable, move to output eDP-1, border pixel 1
  for_window [class="(?i)^meetingly.*"] floating enable, move to output eDP-1, border pixel 1
  ```
  Additionally, `meet-start.sh` proactively relocates Meetingly to `eDP-1` before moving Workspace 2:
  ```bash
  swaymsg '[app_id="(?i)^meetingly.*"] move to output eDP-1' 2>/dev/null || true
  swaymsg '[class="(?i)^meetingly.*"] move to output eDP-1' 2>/dev/null || true
  ```
  This guarantees that even if Meetingly was launched prior to presentation mode on Workspace 2, it is safely pulled onto `eDP-1` before Workspace 2 is transferred to the headless output.

### Edge Case 5: `wl-mirror` Exact `app_id` Mismatch
- **The Pitfall**: Writing window rules with exact name assumptions:
  ```ini
  for_window [app_id="^wl-mirror$"] border none, move to output eDP-1
  ```
- **The Mechanical Failure**: Upstream `wl-mirror` exports its Wayland application ID as `at.yrlf.wl_mirror` (the author reverse-DNS ID). An exact regex match against `^wl-mirror$` silently fails. Without matching the `move to output eDP-1` rule, `wl-mirror` opens on whichever output currently has focus (`HEADLESS-OUT`), mirroring the headless display onto itself.
- **The Engineering Fix**: Use a resilient regex that matches both standard names and the reverse-DNS identifier:
  ```ini
  for_window [app_id="(?i).*(wl[-_]?mirror|at\.yrlf\.wl_mirror).*"] border none, move to output eDP-1
  ```

### Edge Case 6: Input Focus Race Conditions
- **The Pitfall**: Using a fixed `sleep 0.3` delay before refocusing Workspace 2:
  ```bash
  wl-mirror "$HEADLESS_OUT" &
  sleep 0.3
  swaymsg "[workspace=2] focus"
  ```
- **The Mechanical Failure**: On cold launches or under GPU driver initialization latency, `wl-mirror` may take longer than 300 ms to map its Wayland surface. If the focus command executes before `wl-mirror` maps, `wl-mirror` maps afterwards and steals keyboard focus on `eDP-1`, swallowing all keystrokes.
- **The Engineering Fix**: Implement an active polling loop that queries Sway tree state until `wl-mirror` is registered:
  ```bash
  for _ in $(seq 1 30); do
      if swaymsg -t get_tree | jq -r '.. | select(.type?=="con" and .app_id?!=null) | .app_id' | grep -qiE 'wl[-_]mirror|at\.yrlf\.wl_mirror'; then
          break
      fi
      sleep 0.1
  done
  swaymsg "[workspace=2] focus"
  ```

### Edge Case 7: Dynamic Display Resolution Matching
- **The Pitfall**: Hardcoding `1920x1200` breaks if the panel resolution changes or scaling is applied, resulting in black letterboxing or cropped video feeds in Google Meet.
- **The Engineering Fix**: Dynamically query `eDP-1` active geometry using `jq`:
  ```bash
  read -r W H < <(swaymsg -t get_outputs | jq -r '.[] | select(.name=="eDP-1") | "\(.current_mode.width) \(.current_mode.height)"')
  swaymsg output "$HEADLESS_OUT" resolution "${W}x${H}" position "$W" 0
  ```
  This creates a 1:1 pixel-accurate virtual canvas matching your laptop panel.

---

## 4. Audio Architecture & PipeWire Isolation

Virtual display output creation does not interfere with the PipeWire audio pipeline.

### Audio Pipeline Invariants
1. **Zero Virtual Audio Nodes**: Sway's `create_output` command operates entirely inside the wlroots display pipeline. It creates DRM/Wayland surfaces only; it registers zero ALSA devices or PipeWire audio sinks.
2. **Default Routing Remains Intact**:
   - Audio Sink: Internal DAC or active speaker DSP runner (`alsa_output.pci-0000_00_1f.3.analog-stereo`).
   - Recording Source: Virtual neural-denoised microphone (`ghelper-audio`).
3. **Meetingly Dual-Stream Capture**:
   - Candidate Speech: Captured via `ghelper-audio` (internal laptop microphone array).
   - Interviewer Speech: Captured via the PipeWire monitor source of the active output sink.

---

## 5. Production Implementation Scripts

### 5.1 Start Script: `meet-start.sh`
Located at [`/home/onyx/.local/bin/meet-start.sh`](file:///home/onyx/.local/bin/meet-start.sh):

```bash
#!/usr/bin/env bash
# meet-start.sh - Start clean virtual presentation mode for Sway (Target: Workspace 2)
set -eo pipefail

TARGET_WS=2

# 1. Reuse or create HEADLESS output dynamically
HEADLESS_OUT=$(swaymsg -t get_outputs | jq -r '.[].name | select(startswith("HEADLESS-"))' | head -n1)
if [[ -z "$HEADLESS_OUT" ]]; then
    swaymsg create_output
    HEADLESS_OUT=$(swaymsg -t get_outputs | jq -r '.[].name | select(startswith("HEADLESS-"))' | head -n1)
fi

if [[ -z "$HEADLESS_OUT" ]]; then
    notify-send -a "Presentation Mode" -u critical -r 8899 -i dialog-error "Presentation Mode: ERROR" "Failed to create headless display"
    exit 1
fi

# 2. Match eDP-1 panel resolution dynamically
read -r W H < <(swaymsg -t get_outputs | jq -r '.[] | select(.name=="eDP-1") | "\(.current_mode.width) \(.current_mode.height)"')
swaymsg output "$HEADLESS_OUT" resolution "${W}x${H}" position "$W" 0

# 3. Proactively isolate Meetingly onto physical panel eDP-1 before moving workspaces
swaymsg '[app_id="(?i)^meetingly.*"] move to output eDP-1' 2>/dev/null || true
swaymsg '[class="(?i)^meetingly.*"] move to output eDP-1' 2>/dev/null || true

# 4. Move target workspace (Workspace 2: Brave, editor, terminal) to the headless display
swaymsg "[workspace=${TARGET_WS}] move workspace to output $HEADLESS_OUT"

# 5. Launch wl-mirror if not already running (rule places it tiled borderless on eDP-1)
if ! pgrep -x "wl-mirror" > /dev/null; then
    wl-mirror "$HEADLESS_OUT" > /dev/null 2>&1 &
fi

# 6. Active polling loop: wait for wl-mirror container to appear in the tree (up to 3.0s)
for _ in $(seq 1 30); do
    if swaymsg -t get_tree | jq -r '.. | select(.type?=="con" and .app_id?!=null) | .app_id' | grep -qiE 'wl[-_]mirror|at\.yrlf\.wl_mirror'; then
        break
    fi
    sleep 0.1
done

# 7. Re-verify Meetingly remains exclusively on eDP-1
swaymsg '[app_id="(?i)^meetingly.*"] move to output eDP-1' 2>/dev/null || true
swaymsg '[class="(?i)^meetingly.*"] move to output eDP-1' 2>/dev/null || true

# 8. Return keyboard and window focus to Workspace 2 so typing and new windows route to HEADLESS-OUT
swaymsg "[workspace=${TARGET_WS}] focus"

# 9. Display notification (synchronous replace ID for Mako)
notify-send -a "Presentation Mode" -u normal -t 4000 -r 8899 -i video-display \
    "Presentation Mode: ON" \
    "Sharing Target: ${HEADLESS_OUT} (Workspace ${TARGET_WS})\nMeetingly AI overlay cloaked"
```

### 5.2 Stop Script: `meet-stop.sh`
Located at [`/home/onyx/.local/bin/meet-stop.sh`](file:///home/onyx/.local/bin/meet-stop.sh):

```bash
#!/usr/bin/env bash
# meet-stop.sh - Stop clean virtual presentation mode and restore Sway state
set -eo pipefail

TARGET_WS=2

# 1. Terminate wl-mirror
pkill -x wl-mirror || true

# 2. Restore target workspace (Workspace 2) back to the physical panel eDP-1 and focus it
swaymsg "[workspace=${TARGET_WS}] move workspace to output eDP-1"
swaymsg "[workspace=${TARGET_WS}] focus"

# 3. Unplug all active HEADLESS virtual outputs
for out in $(swaymsg -t get_outputs | jq -r '.[].name | select(startswith("HEADLESS-"))'); do
    swaymsg output "$out" unplug || true
done

# 4. Display notification (synchronous replace ID for Mako)
notify-send -a "Presentation Mode" -u normal -t 3000 -r 8899 -i video-display \
    "Presentation Mode: OFF" \
    "Headless display unplugged\nWorkspace ${TARGET_WS} restored to eDP-1"
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
# Window Rules (Dropped sticky enable to prevent buffer leaks across outputs)
for_window [app_id="(?i)^meetingly.*"] floating enable, move to output eDP-1, border pixel 1
for_window [class="(?i)^meetingly.*"] floating enable, move to output eDP-1, border pixel 1

# Tile wl-mirror without borders so floating Meetingly floats on top
for_window [app_id="(?i).*(wl[-_]?mirror|at\.yrlf\.wl_mirror).*"] border none, move to output eDP-1

# Keybindings
bindsym $mod+Shift+m exec --no-startup-id ~/.local/bin/meet-toggle.sh
bindsym $mod+Shift+n exec --no-startup-id ~/.local/bin/meet-stop.sh
```

---

## 7. Pre-Interview Verification Checklist & Smoke Test

Perform this verification before using the setup in an actual interview:

1. **Pre-Flight Launch**:
   - Open your browser (Brave), IDE, and terminal on Workspace 2.
   - Launch Meetingly AI (`meetingly`).
   - Press **`Super + Shift + M`** to activate Presentation Mode.
   - Confirm the Mako desktop notification indicates `Presentation Mode: ON (Workspace 2)`.
2. **Opening Applications While Active**:
   - Press **`Super + Enter`** to spawn a new terminal, or **`Super + b`** for a new browser window.
   - Confirm the window opens directly inside Workspace 2 on the virtual display and renders immediately inside `wl-mirror`.
3. **Definitive Google Meet Self-View Verification**:
   - Open a test meeting by visiting `meet.new` in Brave.
   - Click **Present now** -> select the **Entire Screen** tab.
   - Select **`HEADLESS-X`** as the sharing source (never choose `eDP-1`).
   - Look directly at your own **Self-View Video Tile** in Google Meet:
     - **Verification Pass**: Your shared desktop (IDE, browser, terminal) is visible in the video stream, but the Meetingly AI overlay is completely absent from the stream.
     - **Visual Check**: On your physical laptop panel, Meetingly remains fully visible and interactive, floating over `wl-mirror`.
4. **Focus & Keystroke Verification**:
   - Click inside your IDE or terminal.
   - Type sample code and verify keystrokes register immediately without focus loss.
5. **Teardown Test**:
   - Stop sharing in Google Meet.
   - Press **`Super + Shift + M`** (or `Super + Shift + N`).
   - Confirm `wl-mirror` exits, `HEADLESS-X` is unplugged, and Workspace 2 restores to `eDP-1`.
