# Counter-Strike 2 (CS2) — Linux Status & Experience Log

**Platform:** Native Linux (Vulkan)  
**Runner:** Custom launcher `~/.local/bin/cs2-launch`\
**Execution Environment:** i3wm (X11) / Sway (Wayland) · CachyOS rolling · NVIDIA RTX 5050 Mobile

---

## 1. Quick Status Overview

| Component | Status | Notes |
|---|---|---|
| **Engine & Graphics** | **WORKING** | Runs on native Vulkan via NVIDIA PRIME offload. |
| **Resolution & Scaling** | **WORKING** | Hardware panel scaling (`scaling mode: Full`) stretches 1440x1080 to 1920x1200 panel with zero black bars or added display latency. |
| **High Refresh Rate** | **WORKING** | Custom 165Hz modeline runs at 164.85 Hz smoothly. |
| **Framerate & Latency** | **WORKING** | Averages ~407.6 FPS with 1% lows at ~170.3 FPS (exceeds 165Hz refresh ceiling). |
| **Audio** | **WORKING** | Low-latency audio streaming via PipeWire/PulseAudio. |
| **Anti-Cheat (VAC)** | **WORKING** | Native Linux client connects cleanly to official Valve servers. |

---

## 2. What's Working

- **Stable P-Core Multithreading:** Pinning to threads `0-11` via `taskset -c 0-11` keeps all rendering workloads on Intel Performance cores and prevents micro-stutter from E-core thread migration.
- **Uncomposited Presentation:** Launcher terminates `picom` under X11 or uses native Wayland presentation on Sway, ensuring immediate presentation without double-buffering lag.
- **Dynamic 4:3 Modes:** Switching between `1344x1008`, `1440x1080`, and `1600x1200` works on-demand via the launcher's `CS2_RES` environment variable.

---

## 3. What Did Not Work & How It Was Resolved

- **Issue: In-Menu GPU Choking / Thermal Spikes**
  - *Cause:* Having `+fps_max_ui 0` forced the GPU to render the 3D menu background at hundreds of FPS, spiking temperatures before matches.
  - *Fix:* Set `+fps_max_ui 120` in `~/.local/bin/cs2-launch`.
- **Issue: Argv Token Concatenation in Bash**
  - *Cause:* Passing `"+fps_max $FPS_MAX"` as a single quoted array item prevented Source 2's command-line parser from seeing the flag.
  - *Fix:* Separated flags and arguments into distinct tokens (`+fps_max "$FPS_MAX"`).
- **Issue: Window Stacking Bleed-Through under i3**
  - *Cause:* X11 stacking order occasionally allowed background tiled windows to show during workspace switches.
  - *Fix:* Created `~/.local/bin/cs2-restack-hook` to toggle fullscreen and raise the CS2 window immediately when focused.

---

## 4. Related Docs
- [VProf Benchmark Telemetry Report](./performance-benchmarks.md)
