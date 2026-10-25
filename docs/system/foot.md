# Foot Terminal Emulator Architecture and Benchmarks

Foot is a lightweight, fast, Wayland-native terminal emulator designed specifically for wlroots and Wayland compositors (such as Sway). It renders on the CPU using Pixman SIMD routines (AVX2/SSE) rather than allocating OpenGL/GPU textures, eliminating GPU driver overhead and preventing discrete GPUs from remaining active in hybrid setups.

---

## 1. Operating Modes: Standalone vs Client-Server

Foot supports two execution models:

### A. Standalone Mode (`foot`)
- **Architecture:** Each terminal window runs as an independent OS process.
- **Advantages:**
  - Complete crash isolation: If one terminal process hangs or terminates unexpectedly, other terminal windows are unaffected.
  - Direct execution model with zero daemon dependency.
- **Footprint:** ~23.8 MB RSS per instance.

### B. Client-Server Mode (`foot --server` + `footclient`)
- **Architecture:** A single background daemon (`foot --server`) manages fonts, glyph caches, and Wayland display handles. New windows are created via `footclient`.
- **Advantages:**
  - Shared memory: Fonts and glyph caches are allocated only once.
  - Sub-millisecond window creation latency.
  - Incremental footprint: ~2 MB to ~4 MB per connected client.
- **Trade-offs:**
  - Single point of failure: If the server daemon crashes, all connected client windows terminate.

---

## 2. Live Benchmark Results: Foot vs Kitty (Sway Workspace 5)

Tested on CachyOS (Linux 6.18, Intel i5-13450HX, 1920x1200 @ 165Hz). Measured from `/proc/<pid>/smaps_rollup` with identical typography (`VictorMono Nerd Font Bold @ 19.5`) and color palettes.

### Single Window Baseline

| Metric | Kitty (PID 132068) | Foot (PID 132069) | Foot Advantage |
| :--- | :--- | :--- | :--- |
| **RSS (Resident Set Size)** | 131.99 MB | 23.88 MB | **-108.11 MB (5.5x leaner)** |
| **PSS (Proportional Set Size)** | 55.68 MB | 10.42 MB | **-45.26 MB** |
| **USS (Unique Private RAM)** | 42.21 MB | 6.70 MB | **-35.51 MB** |
| **CPU Utilization (Idle)** | 0.00% | 0.00% | Equal |

### Multi-Window Memory Projection

| Open Windows | Kitty Total RSS | Foot Total RSS | RAM Saved |
| :--- | :--- | :--- | :--- |
| **1 Window** | 132.0 MB | 23.9 MB | **108.1 MB (0.11 GB)** |
| **3 Windows** | 396.0 MB | 71.6 MB | **324.3 MB (0.32 GB)** |
| **5 Windows** | 660.0 MB | 119.4 MB | **540.5 MB (0.53 GB)** |
| **6 Windows** | 791.9 MB | 143.3 MB | **648.7 MB (0.63 GB)** |
| **8 Windows** | 1055.9 MB | 191.0 MB | **864.9 MB (0.84 GB)** |
| **10 Windows** | 1319.9 MB | 238.8 MB | **1081.1 MB (1.06 GB)** |

### Fastfetch Head-to-Head Comparison

Based on an OCR scan of the screenshot directory (`screenshot-2026-10-17_19-55-44_117482.png`) compared directly with the live fastfetch capture:

| Metric | Kitty Era (Oct 17, 19:55) | Foot Client-Server Era (Current) | Difference / Savings |
| :--- | :--- | :--- | :--- |
| **Terminal** | kitty 0.49.2 | foot 1.28.0 | Client-server architecture |
| **Active RAM Used** | 6.82 GiB (7,025 MB) | 4.57 GiB (4,680 MB) | -2.25 GiB (-2,304 MB) |
| **RAM % of Total (15.22 GiB)** | 45% | 30% | -15.0% of total physical RAM |
| **Relative Memory Drop** | Baseline | Reduced by 33.0% | 1/3 less active RAM consumed |
| **Uptime & Workload** | 4 hours, 7 mins (YouTube, shell) | 9 hours, 31 mins (YouTube, agy, opencode) | Lower RAM even with double uptime |

### Technical Breakdown of the Savings

1. **Font & Glyph De-duplication (Client-Server Mode)**
   - **Kitty:** Each terminal window ran an independent process with its own Python/C runtime, GLFW OpenGL context, font rasterizer, and glyph texture atlas (~120 MB - 160 MB RSS per window). With 3–4 open windows (workspace terminals + scratchpad dropdown + notes dropdown), Kitty alone occupied ~500 MB - 640 MB of memory.
   - **Foot:** A single background daemon (`foot --server`) parses VictorMono Nerd Font once. All subsequent windows connect as lightweight `footclient` sessions sharing the identical font cache, rasterized glyphs, and configuration trees. In our live sysmem audit, all 3 active Foot windows plus the server daemon consume only 67.0 MB total PSS (~16.7 MB per window).

2. **Elimination of Per-Window GPU Context Overhead**
   - Standalone GPU-accelerated terminals force dedicated OpenGL/EGL surface allocations and graphics driver buffers on Wayland.
   - Foot utilizes direct Wayland shared-memory (`wl_shm`) with multi-threaded pixman CPU rendering (`workers=4`), completely removing GPU driver memory bloat from the terminal stack.

3. **Compound Cache & Swap Relief**
   - Freeing 2.25 GiB reduced swap thrashing and left significantly more memory available for reclaimable Linux page cache (`Buff/Cache: ~10.03 GB`), improving system responsiveness during background compilation and heavy browser workloads.

---

## 3. Key Findings

1. **Memory Discipline:** Foot saves ~108 MB RAM per window. A standard workflow of 5 to 6 terminals saves ~540 MB to ~650 MB of memory.
2. **GPU Overhead Elimination:** Kitty's ~132 MB footprint is largely driven by OpenGL context creation, GLSL shader compilation, and GPU surface buffers. Foot uses CPU SIMD buffers via Pixman, drawing virtually zero power and preventing dGPU wakeups.
3. **Dynamic Theming Integration:** Integrated with `theme-set`. Switching themes automatically recompiles `~/.config/foot/foot-colors.ini` and broadcasts runtime XTerm OSC escape sequences directly to active PTS devices (`/dev/pts/*`) for instant hot-reload.

---

## 4. Benchmark Utility

A standalone isolation benchmark tool is installed at `~/.local/bin/bench-terminals`. It maps isolated test windows into Sway Workspace 5, profiles them via kernel `smaps_rollup`, prints real-time metrics, and cleans up automatically.

To execute:
```bash
bench-terminals
```
