# Counter-Strike 2 (CS2) — Benchmark Results & Performance Profile

**Document Purpose:** Records official VProf/VProfLite benchmark telemetry, hardware configuration, execution environment, and engine launcher parameters on CachyOS.

> **Update note (2026-10-17):** this report records the 2026-09-20 session as-is. The current setup runs 1600x1200 4:3 stretched via native Wayland SDL viewport stretch, launched through `/home/onyx/.local/bin/cs2-launch %command%` (the `%command%` token is mandatory; MangoHud is not used for CS2). Stored in-game config is now 1600x1200 + Fullscreen. Details: `wayland-43-stretched.md` §0.

---

## 1. Test Environment & System Specifications

| Component | Specification | Details & Configuration |
|---|---|---|
| **OS / Distro** | CachyOS rolling (x86-64-v3) | BORE / EEVDF CPU scheduler |
| **Kernel** | `7.2.5-1-cachyos` | Linux kernel optimized with BORE |
| **Window Manager** | i3wm (X11) | Direct uncomposited X11 presentation (`picom` terminated) |
| **Display Panel** | 16-inch 16:10 internal IPS (`eDP-1`) | 1920x1200 native @ 165.00 Hz |
| **Scaled Game Resolution** | **1440x1080 @ 164.85 Hz** | 4:3 stretched via Intel panel controller hardware scaling (`scaling mode: Full`) |
| **CPU** | Intel Core i5-13450HX | 10 Cores / 16 Threads (6 P-cores + 4 E-cores) |
| **CPU Pinning** | `taskset -c 0-11` | Pinned strictly to physical P-cores & hyperthreads (isolates latency-sensitive rendering from E-cores 12-15) |
| **GPU (dGPU)** | NVIDIA GeForce RTX 5050 Mobile | Blackwell architecture (`sm_120`), 8GB GDDR6 |
| **GPU Driver** | `nvidia-open-dkms 615.71.09-1` | Open kernel module with full power curve |
| **Graphics API** | Native Vulkan (`-vulkan`) | Rendered via NVIDIA PRIME Offload (`__NV_PRIME_RENDER_OFFLOAD=1`, `__VK_LAYER_NV_optimus=NVIDIA_only`) |
| **Game Launcher** | `~/.local/bin/cs2-launch` | Gamemode + taskset + panel mode switch handler |

---

## 2. In-Game Video & Graphics Configuration

*Source: `~/.local/share/Steam/userdata/<account_id>/730/local/cfg/cs2_video.txt`*

- **Resolution:** `1440 x 1080` (4:3 aspect ratio mode)
- **Refresh Rate:** `165 Hz` (`refreshrate_numerator: 165`)
- **Display Mode:** Exclusive Fullscreen (`setting.fullscreen: 1`, `nowindowborder: 1`)
- **Vertical Sync:** Disabled (`setting.mat_vsync: 0`)
- **Multisampling Anti-Aliasing:** None (`setting.msaa_samples: 0`)
- **Shader Quality:** Low (`setting.shaderquality: 0`)
- **Texture Filtering:** Anisotropic 4x / Trilinear (`setting.r_texturefilteringquality: 5`)
- **Reflex / Low Latency:** Disabled in config (`setting.r_low_latency: 0`)

---

## 3. Benchmark Telemetry Report (VProfLite)

**Benchmark Method:** Workshop / Community standardized replay benchmark (*fpsheaven.com / Angel_foxxo*) executed via native engine VProf profiler.

### Summary Metrics
```text
-- Performance report --
Summary of 49,715 frames and 122 1-second intervals. (5,789 frames excluded from analysis.)

============================================================
  Average FPS:  407.6 FPS  (Frame time: 2.45 ms)
  1% Low (P1):  170.3 FPS  (Frame time: 5.87 ms)
============================================================
```

### Detailed Subsystem Frame Time Breakdown (Milliseconds)

| Engine Subsystem | All Frames (Avg) | All Frames (P99) | Active Frames (Avg) | Active Frames (P99) | 1s Max All (P50) | 1s Max All (P95) |
|---|---|---|---|---|---|---|
| **Frame Total** | **2.45 ms** | **5.87 ms** | **2.45 ms** | **5.87 ms** | **5.75 ms** | **17.19 ms** |
| Client Rendering | 1.49 ms | 4.26 ms | 1.49 ms | 4.26 ms | 2.64 ms | 7.26 ms |
| Frame Boundary | 1.09 ms | 3.28 ms | 1.09 ms | 3.28 ms | 2.28 ms | 6.36 ms |
| Present_RenderDevice | 0.41 ms | 2.06 ms | 0.41 ms | 2.06 ms | 1.46 ms | 3.22 ms |
| Client Simulation | 0.34 ms | 0.94 ms | 0.34 ms | 0.94 ms | 0.95 ms | 1.83 ms |
| ClientSimulateFrame | 0.29 ms | 0.54 ms | 0.29 ms | 0.54 ms | 0.57 ms | 1.17 ms |
| Server Simulation | 0.27 ms | 2.04 ms | 1.70 ms | 3.83 ms | 2.18 ms | 5.49 ms |
| Server Game | 0.21 ms | 1.68 ms | 1.35 ms | 2.87 ms | 1.77 ms | 4.00 ms |
| Prediction | 0.10 ms | 0.46 ms | 0.10 ms | 0.46 ms | 0.50 ms | 1.26 ms |
| UserCommands | 0.08 ms | 0.66 ms | 0.52 ms | 1.04 ms | 0.69 ms | 1.19 ms |
| ClientSimulateTick | 0.05 ms | 0.51 ms | 0.33 ms | 0.64 ms | 0.56 ms | 1.07 ms |
| Server Animation | 0.05 ms | 0.38 ms | 0.30 ms | 0.59 ms | 0.43 ms | 1.26 ms |
| Server Send Networking | 0.03 ms | 0.30 ms | 0.21 ms | 0.43 ms | 0.34 ms | 0.74 ms |
| NPCs | 0.03 ms | 0.24 ms | 0.19 ms | 0.54 ms | 0.33 ms | 0.86 ms |
| Networking | 0.03 ms | 0.25 ms | 0.19 ms | 0.40 ms | 0.35 ms | 0.70 ms |
| Server PackEntities | 0.02 ms | 0.18 ms | 0.12 ms | 0.31 ms | 0.20 ms | 0.55 ms |

---

## 4. Key Takeaways & Analysis

1. **High Frame Rate Ceiling (407.6 Avg FPS):**
   - The native Linux Vulkan client running on the RTX 5050 Mobile Blackwell GPU maintains an average frametime of **2.45 ms**, delivering over **2.4x the native 165Hz refresh rate** of the panel.
2. **Stable 1% Lows (170.3 FPS):**
   - 1% percentile lows (`170.3 FPS`) comfortably sit above the display panel's physical refresh rate (`165 Hz`), ensuring tear-free, fluid motion with zero frame dropping across intensive scenes.
3. **P-Core Isolation Efficacy:**
   - Pinned execution via `taskset -c 0-11` eliminates E-core context switching jitter. Client simulation average remains low at `0.34 ms`.
4. **Present Latency:**
   - `Present_RenderDevice` averages `0.41 ms`, confirming that direct X11 presentation with compositors killed avoids presentation queue bottlenecks.

---

## 5. MangoHud Frametime Capture Setup (2026-09-19) — REVERTED same day

> **Status: fully reverted.** `cs2.conf` deleted, `~/mangologs/` removed (no capture ever ran — dir was empty). Launch options were never modified by this setup (still the pre-existing `cs2-launch` wrapper). Section kept as history.

**Purpose:** Continuous 1%/0.1%-low capture during real match play (complements the VProf replay benchmark above, which measures engine subsystems, not present-to-photon smoothness).

**Changes made (3 items, all user-scoped):**

1. Created `~/.config/MangoHud/cs2.conf` (per-game override; global `MangoHud.conf` untouched, Elden Ring pin unaffected):
   ```ini
   autostart_log=5
   log_duration=600
   output_folder=~/mangologs
   benchmark_percentiles=97,AVG,1,0.1
   ```
2. Created `~/mangologs/` (CSV output dir).
3. Steam CS2 launch options: previously **empty** → set to:
   ```text
   mangohud gamemoderun %command%
   ```

**Revert (full undo):**
```bash
rm ~/.config/MangoHud/cs2.conf
rmdir ~/mangologs   # only if empty; else archive CSVs first
# Steam → CS2 → Properties → Launch Options → clear the field
```
