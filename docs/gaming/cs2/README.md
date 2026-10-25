# Counter-Strike 2 (CS2) — Linux Status & Experience Log

**Platform:** Native Linux (Vulkan)  
**Runner:** Custom launcher `~/.local/bin/cs2-launch` (locked immutable via `chattr +i`, Rule 11), invoked from Steam via `/home/onyx/.local/bin/cs2-launch %command%` (the `%command%` token is mandatory; MangoHud is intentionally not used for CS2)  
**Execution Environment:** i3wm (X11) / Sway (Wayland) · CachyOS rolling · NVIDIA RTX 5050 Mobile

---

## 1. Quick Status Overview

| Component | Status | Notes |
|---|---|---|
| **Engine & Graphics** | **WORKING** | Runs on native Vulkan via NVIDIA PRIME offload. |
| **Resolution & Scaling** | **WORKING** | 1600x1200 4:3 stretched to the 1920x1200 panel via SDL Wayland viewport stretch (`MODE_SCALING=stretch` + `SCALE_TO_DISPLAY=1`, native Wayland). The launcher locks exclusive fullscreen in `cs2_video.txt` on every launch — zero black bars. |
| **High Refresh Rate** | **WORKING** | Custom 165Hz modeline runs at 164.85 Hz smoothly. |
| **Framerate & Latency** | **WORKING** | Averages ~407.6 FPS with 1% lows at ~170.3 FPS (exceeds 165Hz refresh ceiling). |
| **Audio** | **WORKING** | Low-latency audio streaming via PipeWire/PulseAudio. |
| **Anti-Cheat (VAC)** | **WORKING** | Native Linux client connects cleanly to official Valve servers. |

---

## 2. What's Working

- **Stable P-Core Multithreading:** Pinning to threads `0-11` via `taskset -c 0-11` keeps all rendering workloads on Intel Performance cores and prevents micro-stutter from E-core thread migration.
- **Uncomposited Presentation:** Launcher terminates `picom` under X11 or uses native Wayland presentation on Sway, ensuring immediate presentation without double-buffering lag.
- **Dynamic 4:3 Modes:** Switching between `1344x1008`, `1440x1080`, and `1600x1200` works on-demand via the launcher's `CS2_RES` environment variable.
- **Self-Healing Exclusive Fullscreen:** `cs2-launch` ensures `cs2_video.txt` enforces `setting.fullscreen 1`, `setting.coop_fullscreen 0`, `setting.nowindowborder 0`, and the exact target resolution before start and on cleanup, preventing borderless windowed fallback.
- **Protected Immutable Baseline:** `~/.local/bin/cs2-launch` is protected with filesystem immutability (`chattr +i`) and covered by global Rule 11.

---

## 3. What Did Not Work & How It Was Resolved

- **Issue: Asymmetric 320 px Black Bar on Right Side at 1600x1200 Max 4:3 (2026-10-25)**
  - *Cause 1 (Steam Launch Options):* Steam App 730 `LaunchOptions` in `localconfig.vdf` had been clobbered by GTA IV's Proton overrides (`DISABLE_LSFGVK=1 WINEDLLOVERRIDES="dinput8=n,b" ...`), bypassing `cs2-launch` so CS2 started under XWayland (`SDL_VIDEO_DRIVER=x11`), where 1600x1200 cannot stretch and is left-anchored at `(0, 0)` on the 1920x1200 panel.
  - *Cause 2 (CS2 Video Config):* In `~/.local/share/Steam/userdata/875656642/730/local/cfg/cs2_video.txt`, CS2 was set to Fullscreen Windowed (`setting.fullscreen 0`, `setting.coop_fullscreen 1`). Under SDL3 Wayland, `SDL_VIDEO_WAYLAND_MODE_SCALING=stretch` only activates when `window->fullscreen_exclusive` is true; borderless windowed mode clamps the viewport to 1600x1200.
  - *Fix:* Restored Steam LaunchOptions to `/home/onyx/.local/bin/cs2-launch %command%`. Updated `cs2-launch` to automatically enforce `setting.fullscreen 1`, `setting.coop_fullscreen 0`, `setting.nowindowborder 0`, `setting.defaultres $TARGET_W`, and `setting.defaultresheight $TARGET_H` in `cs2_video.txt` pre-launch and on exit. Locked `~/.local/bin/cs2-launch` with `chattr +i` and added AGENTS.md invariant Rule 11. Full analysis: [wayland-43-stretched.md](./wayland-43-stretched.md).
- **Issue: In-Menu GPU Choking / Thermal Spikes**
  - *Cause:* Having `+fps_max_ui 0` forced the GPU to render the 3D menu background at hundreds of FPS, spiking temperatures before matches.
  - *Fix:* Menu FPS cap via `+fps_max_ui` in `~/.local/bin/cs2-launch` (launcher currently ships `+fps_max 0 +fps_max_ui 0`; re-add a menu cap if thermal spikes return).
- **Issue: Black Bars, No MangoHud, No Perf Stack on Normal Steam Launches (2026-10-17)**
  - *Cause:* The Steam launch option was missing `%command%`; Steam appends such a string to the game command line as arguments, so `cs2-launch` never executed and the game fell back to XWayland.
  - *Fix:* Launch option is now `/home/onyx/.local/bin/cs2-launch %command%`. Full analysis: [wayland-43-stretched.md](./wayland-43-stretched.md) §0.
- **Issue: Argv Token Concatenation in Bash**
  - *Cause:* Passing `"+fps_max $FPS_MAX"` as a single quoted array item prevented Source 2's command-line parser from seeing the flag.
  - *Fix:* Separated flags and arguments into distinct tokens (`+fps_max "$FPS_MAX"`).
- **Issue: Window Stacking Bleed-Through under i3**
  - *Cause:* X11 stacking order occasionally allowed background tiled windows to show during workspace switches.
  - *Fix:* Created `~/.local/bin/cs2-restack-hook` to toggle fullscreen and raise the CS2 window immediately when focused.

---

## 4. Related Docs
- [Native Wayland 4:3 Stretched Fix Log](./wayland-43-stretched.md)
- [VProf Benchmark Telemetry Report](./performance-benchmarks.md)
