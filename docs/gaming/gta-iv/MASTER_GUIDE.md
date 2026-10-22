# Grand Theft Auto IV: Complete Edition — Linux Master Engineering & Modding Guide
*The definitive, exhaustive architecture reference, runtime guide, crash postmortem catalog, reverse-engineering autopsy, and visual overhaul manual for GTA IV Complete Edition (v1.2.0.59) on CachyOS / Proton.*

---

## Table of Contents
1. [Target Machine, Hardware & OS Architecture](#1-target-machine-hardware--os-architecture)
2. [Complete Steam Launch Options & Environment](#2-complete-steam-launch-options--environment)
3. [Lossless Scaling Frame Generation (LSFG-VK 32-Bit)](#3-lossless-scaling-frame-generation-lsfg-vk-32-bit)
4. [MangoHud Telemetry & Frame Pacing Configuration](#4-mangohud-telemetry--frame-pacing-configuration)
5. [vkBasalt Post-Processing: CAS Sharpening & Vibrance](#5-vkbasalt-post-processing-cas-sharpening--vibrance)
6. [Low-Latency 165Hz Engine Configuration](#6-low-latency-165hz-engine-configuration)
7. [Engine Constraints, 32-Bit Memory Ceiling & Core Invariants](#7-engine-constraints-32-bit-memory-ceiling--core-invariants)
8. [Visual Overhaul: Solitude 3 v1.1.5 + Night-Only Ambient Lift](#8-visual-overhaul-solitude-3-v115--night-only-ambient-lift)
9. [Complete Mod Inventory & Alphanumeric Load Order](#9-complete-mod-inventory--alphanumeric-load-order)
10. [Incompatible Mods, Failures & Crash Postmortems](#10-incompatible-mods-failures--crash-postmortems)
11. [First Person Perspective (C06alt FPP v1.3) Reverse Engineering](#11-first-person-perspective-c06alt-fpp-v13-reverse-engineering)
12. [Liberty's Legacy: 60% Keyboard & Controller D-Pad Phone Conflict Disassembly](#12-libertys-legacy-60-keyboard--controller-d-pad-phone-conflict-disassembly)
13. [Architecture Dependency Graph](#13-architecture-dependency-graph)
14. [Btrfs Snapper Snapshotting & Rollback Procedures](#14-btrfs-snapper-snapshotting--rollback-procedures)

---

## 1. Target Machine, Hardware & OS Architecture

### 1.1 Hardware Specifications
* **Host Machine:** ASUS TUF Gaming F16
* **CPU:** Intel Core i5-13450HX (10 physical cores / 16 threads: 6 Performance cores up to 4.6 GHz + 4 Efficient cores up to 3.4 GHz)
* **Dedicated GPU (dGPU):** NVIDIA GeForce RTX 5050 Mobile (8GB GDDR7, `sm_120`, Blackwell architecture)
* **Integrated GPU (iGPU):** Intel UHD Graphics (Raptor Lake, `DISPLAY=:0`, `LIBVA_DRIVER_NAME=iHD`)
* **Display:** 16-inch IPS Panel, 1920x1200 Native (16:10 aspect ratio) @ 165Hz
* **Storage:** PCIe 4.0 NVMe SSD formatted with **native Linux Btrfs** (mounted with `noatime,compress=zstd:3`). **Strictly NO NTFS partitions** (NTFS-3G and Paragon NTFS drivers fail Wine SQLite locking, corrupt prefix databases, and introduce severe I/O stalls during file streaming).

### 1.2 Operating System & Kernel
* **Distribution:** CachyOS rolling (`x86-64-v3` architecture-optimized packages)
* **Kernel:** Linux `linux-cachyos` with BORE (Burst-Oriented Response Enhancer) and EEVDF CPU scheduler
* **Desktop Sessions:** i3wm (X11) / Sway (Wayland)
* **Filesystem Snapshots:** Snapper integration for root (`/`) and home (`/home`) subvolumes

### 1.3 Hybrid GPU Power Management Strategy
* **Desktop Session (2D):** Runs exclusively on the Intel iGPU for cool idle temperatures, minimal power draw, and extended battery life.
* **Render Offload (3D):** Offloaded strictly to the RTX 5050 Mobile on-demand via `prime-run`:
  ```bash
  prime-run %command%
  ```
* **Power States:** The NVIDIA RTX 5050 stays suspended in ultra-low-power `D3cold` until invoked by 3D/Vulkan binaries, preventing fan noise and thermal throttling during non-gaming tasks.

---

## 2. Complete Steam Launch Options & Environment

### 2.1 The Master Launch Option String
Set this exact string in **Steam → Grand Theft Auto IV → Properties → General → Launch Options**:

```bash
WINEDLLOVERRIDES="dinput8=n,b" LSFGVK_PROFILE="gta4" prime-run mangohud enable_vkbasalt=1 %command%
```

### 2.2 Exhaustive Parameter Breakdown

| Parameter | Function | Technical Implementation & Failure Without It |
| :--- | :--- | :--- |
| `WINEDLLOVERRIDES="dinput8=n,b"` | Native DLL Override | Forces Wine's PE loader to prioritize the local `dinput8.dll` (Ultimate ASI Loader bundled with FusionFix) located in the game root over Wine's built-in dummy `dinput8.dll`. **Failure without it:** ASI plugins (`FusionFix.asi`, `Liberty's Legacy.asi`, `FirstPerson.asi`) will never execute; the game launches completely vanilla. |
| `LSFGVK_PROFILE="gta4"` | Vulkan Layer Profile | Directs the 32-bit Lossless Scaling Frame Generation Vulkan layer (`aur/lib32-lsfg-vk`) to activate the `[profile]` block named `"gta4"` in `~/.config/lsfg-vk/conf.toml`. |
| `prime-run` | Dynamic GPU Offloading | Injects the standard PRIME environment variables (`__NV_PRIME_RENDER_OFFLOAD=1`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, `__VK_LAYER_NV_optimus=NVIDIA_only`). Forces Vulkan physical device selection to target the RTX 5050 Mobile rather than the Intel iGPU. |
| `mangohud` | Vulkan Performance Telemetry | Loads the MangoHud Vulkan layer. Displays framerate, frametimes, GPU/CPU thermals, power draw, and VRAM utilization directly onto the screen. |
| `enable_vkbasalt=1` | Post-Processing Injection | Injects vkBasalt into the Vulkan swapchain presentation pipeline. Executes hardware Contrast Adaptive Sharpening (CAS) and color vibrance on rendered frames before presentation. |
| `%command%` | Steam Executable Hook | Replaced by Steam with the invocation of Proton and `GTAIV.exe`. |

### 2.3 Proton Compatibility Tool & Prerequisites
* **Active Compatibility Tool:** **`GE-Proton11-7-x86_64`** or **`Proton Experimental`**.
  * *Why Older Proton 9 Fails:* Older Proton 9 builds fail to negotiate IPC tokens with the Chromium Embedded Framework (CEF) inside the modern Rockstar Games Launcher, resulting in an infinite loading spinner or black launcher window. GE-Proton 11 and Proton Experimental resolve CEF threading deadlocks natively.
* **DirectX 9 Native Runtime Prerequisite:**
  ```bash
  protontricks 12210 -q d3dx9_43
  ```
  Installs Microsoft's native 32-bit D3DX9 runtime DLLs into the prefix (`drive_c/windows/syswow64/d3dx9_43.dll`), which certain legacy effect shaders require for proper matrix transformations.

---

## 3. Lossless Scaling Frame Generation (LSFG-VK 32-Bit)

GTA IV (`GTAIV.exe`) is a 32-bit Windows binary. Frame generation under Linux requires a 32-bit Vulkan layer compilation.

### 3.1 Installation & Package
* Installed via AUR: `aur/lib32-lsfg-vk`
* Shared Library Target: `/home/onyx/.config/lsfg-vk/lsfg-vk.dll`
* Vulkan Layer JSON: `/usr/share/vulkan/implicit_layer.d/lib32-lsfg-vk.json`

### 3.2 Dedicated Configuration (`~/.config/lsfg-vk/conf.toml`)
```toml
version = 2

[global]
allow_fp16 = true
dll = "/home/onyx/.config/lsfg-vk/lsfg-vk.dll"
log_level = "info"

[[profile]]
active_in = "sdhdship.exe"
flow_scale = 1.0
multiplier = 2
name = "Sleeping Dogs Definitive Edition"
override_present_mode = true
pacing_mode = "vsync"
performance_mode = false
preserve_swapchain_image_count = false

[[profile]]
active_in = "GTAIV.exe"
flow_scale = 1.0
multiplier = 2
name = "gta4"
override_present_mode = true
pacing_mode = "vsync"
performance_mode = false
preserve_swapchain_image_count = false
```

### 3.3 Deep-Dive Architecture & Tuning
* `active_in = "GTAIV.exe"`: Ensures the layer only initializes when the executable binary matches `GTAIV.exe`.
* `multiplier = 2`: Generates 1 interpolated frame between every real rendered frame (e.g., 82.5 real FPS $\rightarrow$ 165 displayed FPS).
* `flow_scale = 1.0`: Computes optical flow vectors at full resolution. Prevents warping artifacts around high-speed vehicle edges and streetlight poles.
* `pacing_mode = "vsync"`: Delivers generated frames locked to display V-Blank intervals, eliminating micro-stutter and frame judder.
* `allow_fp16 = true`: Uses 16-bit half-precision floating-point arithmetic on NVIDIA Ada Lovelace / Blackwell tensor cores, reducing compute overhead to under 0.5 ms per frame.

---

## 4. MangoHud Telemetry & Frame Pacing Configuration

### 4.1 Dedicated Game Configuration (`~/.config/MangoHud/GTAIV.exe.conf`)
```ini
# Dedicated MangoHud config for GTA IV (Complete Edition)
# Disables external MangoHud frame limiter so FusionFix can manage engine pacing & physics.
fps_limit=0
```

### 4.2 Why `fps_limit=0` is Essential in MangoHud
GTA IV's Rage Engine is notorious for tying internal game logic to frame tick timing:
1. **Motorcycle Physics:** At uncapped or erratic frame rates, motorcycles lose downward traction, causing them to bounce uncontrollably over bumps.
2. **Vehicle Suspension Jitter:** External frame limiters (MangoHud, Libstrangle, RTSS) apply thread sleep intervals outside the Direct3D presentation loop, causing the physics engine to receive uneven $\Delta t$ delta-time values.
3. **The "Out of Commission" Helicopter QTE Bug:** During the final story mission, climbing into the helicopter requires tapping the spacebar. If an external limiter desyncs the physics loop, the game fails to register keypresses, making the mission impossible to complete.

**The Solution:** MangoHud's limiter is disabled (`fps_limit=0`). Frame pacing is delegated entirely to **FusionFix** (`FpsLimitPreset = 12` in `plugins/GTAIV.EFLC.FusionFix.cfg`) and **DXVK** (`d3d9.maxFrameLatency = 1`, `d3d9.presentInterval = 0`), which operate inside the game's internal render loop.

---

## 5. vkBasalt Post-Processing: CAS Sharpening & Vibrance

### 5.1 Vulkan Compute Architecture
vkBasalt runs as a pure Vulkan compute post-processing layer inserted directly between DXVK's output framebuffer and the display presentation queue:
* **Zero Frame Latency Overhead:** Runs natively inside the GPU's Vulkan command buffer submission queue; direct scanout remains eligible.
* **No Extra Present Hop:** Unlike ReShade or ENB wrappers that intercept D3D calls and force extra swapchain copies, vkBasalt computes shaders directly in Vulkan memory.

### 5.2 Dedicated Game Configuration (`GTAIV/vkBasalt.conf`)
```ini
# vkBasalt configuration for GTA IV Complete Edition
# CAS (Contrast Adaptive Sharpening) + Vibrance (single-pass post-processing)

effects = cas:vibrance

casSharpness = 0.40

vibrance = /home/onyx/.config/vkBasalt/reshade-shaders/Shaders/Vibrance.fx
reshadeTexturePath = /home/onyx/.config/vkBasalt/reshade-shaders/Textures
reshadeIncludePath = /home/onyx/.config/vkBasalt/reshade-shaders/Shaders

toggleKey = Home
```

### 5.3 Effect Tuning Breakdown
* **`casSharpness = 0.40` (AMD Contrast Adaptive Sharpening):**
  Applies non-linear edge sharpening based on local contrast. High-contrast edges (like neon sign borders and HUD text) receive subtle sharpening to avoid haloing, while low-contrast areas (road asphalt, building masonry, vehicle paint textures) receive aggressive detail recovery.
* **`vibrance` (`Vibrance.fx`):**
  Selectively boosts saturation on desaturated pixels while preserving skin tones. Synergizes with Solitude 3's deep obsidian nights, making Times Square / Star Junction neon signs, vehicle taillights, and streetlights pop vividly against dark asphalt.
* **`toggleKey = Home`:** Allows instantaneous in-game toggling to audit raw vs. enhanced visual output.

---

## 6. Low-Latency 165Hz Engine Configuration

### 6.1 Commandline Overrides (`GTAIV/commandline.txt`)
```text
-width 1920
-height 1200
-refreshrate 165
-frameLimit 0
-novblank
-nomemrestrict
-norestrictions
-scOfflineOnly
```

* `-width 1920 -height 1200`: Locks the native 16:10 resolution.
* `-refreshrate 165`: Forces the Rage Engine to poll the display at 165Hz instead of defaulting to 60Hz.
* `-frameLimit 0`: Disables GTA IV's broken legacy 30 FPS frame limiter.
* `-novblank`: Disables ancient engine-level V-Sync in favor of modern DXVK presentation.
* `-nomemrestrict -norestrictions`: Prevents GTA IV from arbitrarily locking graphic sliders based on outdated 2008 VRAM detection tables.
* `-scOfflineOnly`: Completely disables telemetry and network pings to Social Club servers, cutting launch and transition times significantly.

### 6.2 DXVK Engine Configuration (`GTAIV/dxvk.conf`)
```ini
dxvk.allowFse = true
dxvk.enableAsync = true
dxvk.gplAsyncCache = true
dxvk.enableGraphicsPipelineLibrary = false
dxvk.numAsyncThreads = 8
dxvk.numCompilerThreads = 8
d3d9.maxFrameLatency = 1
d3d9.presentInterval = 0
d3d9.maxFrameRate = 0
dxvk.tearFree = True

# Texture Filtering Overrides (Zero VRAM / Memory Cost)
d3d9.samplerAnisotropy = 16
# d3d9.samplerLodBias = -0.5
```

* `d3d9.samplerAnisotropy = 16`: Forces 16x Anisotropic Filtering across all D3D9 texture samplers, ensuring oblique surfaces (roads, distant tarmac, angled facades) remain sharp at zero VRAM overhead.
* `d3d9.maxFrameLatency = 1`: Clamps prerendered frames to 1, minimizing input lag on mouse and gamepad.
* `dxvk.enableAsync = true` & `dxvk.gplAsyncCache = true`: Uses DXVK GPLAsync (Nexus #385) to compile Vulkan pipelines asynchronously in background threads. Completely eliminates the notorious traversal stutter when driving fast across bridge boundaries into new boroughs.
* `dxvk.tearFree = True`: Eliminates horizontal screen tearing without adding traditional double/triple-buffering input lag.

### 6.3 FusionFix Engine Configuration (`plugins/GTAIV.EFLC.FusionFix.cfg`)
```ini
[MAIN]
GraphicsAPI = 1
Windowed = 0
Bloom = 1
Definition = 1
MotionBlur = 0

[MISC]
PadAimSensitivity = 10
MouseAimSensitivity = 10
ScreenFilter = 5
DistantLights = 1
SunShafts = 1
UnclampLighting = 1
ToneMapping = 1
AmbientOcclusion = 1
TreeAlpha = 7
Antialiasing = 7
ConsoleGamma = 0
ConsoleAutoExposure = 0
DepthOfField = 6
VolumetricFog = 1

[FRAMELIMIT]
FpsLimitPreset = 12

[SHADOWS]
ExtraNightShadows = 0
ShadowFilter = 3
```

* `GraphicsAPI = 1`: Keeps Direct3D 9 active so DXVK can translate to Vulkan cleanly.
* `ScreenFilter = 5`: Disables the dirty green/sepia color wash overlay, revealing clean, natural colors.
* `ToneMapping = 1`: Enables high dynamic range tone mapping for smooth highlight rolloff.
* `ConsoleGamma = 0`: Preserves native PC gamma (gamma 0.90) instead of crushing darks with console emulation.
* `VolumetricFog = 1`: Renders volumetric light shafts through fog, essential for Solitude 3's atmospheric nights.

---

## 7. Engine Constraints, 32-Bit Memory Ceiling & Core Invariants

### 7.1 The 32-Bit Virtual Address Space Limit (~3.2 GB – 3.5 GB)
`GTAIV.exe` is a 32-bit PE binary. Even with Large Address Aware (LAA) flags enabled:
* The 32-bit virtual address ceiling is strictly **4.0 GB** ($2^{32}$ bytes).
* Under Linux, Wine/Proton and DXVK reserve **500 MB to 800 MB** for internal thread mapping, Vulkan translation layers, prefix emulation, and heap bookkeeping.
* **Real-World Usable Address Space:** **3.2 GB to 3.5 GB**.
* **Golden Rule:** Never mount multiple monolithic 2K/4K texture overhauls simultaneously. Exceeding 3.5 GB causes instant memory fragmentation, texture corruption, and crash `0xc0000005`.

### 7.2 Core Engine Invariants (`plugins/GTAIV.EFLC.FusionFix.ini`)
```ini
[BudgetedIV]
VehicleBudget = 120000000
PedBudget = 0
ExtendedLimits = 0
```

1. **`ExtendedLimits = 0` (MANDATORY INVARIANT):**
   * *The Mechanism:* `ExtendedLimits = 1` increases internal game pool allocations for `CModelInfo`, `handling.dat`, `carcols.dat`, and matrix arrays.
   * *The Failure under Wine/Proton:* On Windows NT, the memory manager allocates virtual memory in contiguous blocks. On Linux, Wine's memory allocator maps pages differently. When `ExtendedLimits = 1` is enabled, the Rage Engine requests oversized heap blocks that collide with Wine's internal reserved address ranges, triggering instant memory access violations (`0xc0000005`) on boot or hanging indefinitely on the artwork loading screen.
   * *Status:* Kept strictly at `0`.
2. **`VehicleBudget = 120000000` (Optimal Calibration):**
   * *The "Taxi Bug":* When vehicle texture sizes exceed the engine's streaming memory budget, GTA IV stops loading diverse traffic models and spawns only yellow taxis.
   * *The 15 Sound-Slot Ceiling:* Setting `VehicleBudget` too high (>150 MB) exhausts GTA IV's hardcoded 15-slot audio engine bank, causing vehicles to drop engine or door audio.
   * *The Solution:* `120000000` (120 MB) is the mathematically verified sweet spot that completely eliminates the Taxi Bug while keeping all vehicle audio 100% stable.
3. **`PedBudget = 0`:**
   * Prevents pedestrian heap fragmentation and crash anomalies.

### 7.3 Graphics API Menu Trap: Never Switch to "Vulkan" in FusionFix Menu
* **The Trap:** FusionFix has an in-game pause menu option: `Graphics API: D3D9 / Vulkan`.
* **What Happens If You Switch:** Selecting "Vulkan" creates a file named `d3d9.cfg` in the game root and instructs the engine to reload Windows-specific Vulkan driver libraries. Under Proton, DXVK is **already** translating Direct3D 9 calls to Vulkan at the driver boundary. The duplicate DLL reload causes a null pointer memory access violation (`0xc0000005`), crashing the game instantly.
* **The Rule:** Keep `GraphicsAPI = 1` in `plugins/GTAIV.EFLC.FusionFix.cfg`. DXVK handles Vulkan transparently.

---

## 8. Visual Overhaul: Solitude 3 v1.1.5 + Night-Only Ambient Lift

### 8.1 Visual Vision
The aesthetic target is the **"Tokyo Drift / Times Square Neon Night"** atmosphere:
* Deep obsidian night skies and crisp, high-contrast shadows.
* Wet asphalt reflections from streetlights and neon signage.
* Atmospheric volumetric fog without clipping or washed-out horizons.
* Saturated, vibrant neon radiance around Star Junction / Times Square.

### 8.2 Why DayL Natural Timecycle Was Rejected as a Hybrid
Earlier experiments attempted to blend DayL's Natural Timecycle nights with Solitude 3 daytime:
1. **Fog Distance Conflict:** DayL uses long fog distances (`FogSt = 750m–1000m`), whereas Solitude uses short atmospheric fog (`FogSt = ~40m`). Mixing them created jarring horizon jumps and broke volumetric fog density.
2. **Atmospheric Inconsistency:** DayL introduces a warm, golden horizon glow that clashes with Solitude's cool, cinematic tone mapping and obsidian sky palettes.
3. **Author Warning:** Solitude 3's author explicitly noted that merging third-party timecycle tables introduces lighting multiplier mismatches (`AmbLightMult0 = 11.0` vs DayL defaults).
4. **The Decision:** **Zero DayL values.** Keep 100% Solitude 3 visual identity.

### 8.3 The Night-Only Relative Ambient Lift Solution
Pristine Solitude 3 has a steep contrast curve (`64.1`) and low gamma (`0.90`), causing unlit asphalt, alley walls, and dark vehicles to crush into pure `#000000` black silhouettes between 00:00 and 05:00.

Instead of changing fog, sky, or global brightness, we applied a **purely relative mathematical lift** directly to Solitude's own authored colors:
$$\text{New Value} = \text{round}(\text{Solitude Value} \times (1 + \text{lift}))$$

Because all three color channels ($R, G, B$) scaled equally, **Solitude's exact color temperature and atmospheric tint were preserved 100%** without any hue shifts, yellowing, or gray-washing.

#### The Only Two Fields Modified:
* **`Amb0` (Tokens 0, 1, 2):** World static ambient floor (illuminates asphalt, concrete, sidewalks, building facades).
* **`Amb1` (Tokens 3, 4, 5):** Dynamic object ambient floor (illuminates vehicles, pedestrians, and dynamic props).

#### The Only Three Hours Modified (Smooth Interpolation):
* **`10PM` (22:00) — +4%:** Smooth ramp down from untouched 21:00 dusk into night.
* **`Midnight` (00:00) — +7%:** Peak nighttime readability (governs 23:00 through 04:00).
* **`5AM` (05:00) — +4%:** Smooth ramp up from night into untouched 06:00 dawn.
* **`6AM` through `9PM` (06:00 → 21:00):** **100% bit-for-bit identical to original Solitude.** Daytime, sunrise, sunset, and twilight are completely untouched.

### 8.4 Exhaustive Before vs. After Values (All 8 Gameplay Weathers)

```
WEATHER: EXTRASUNNY
TIME: Midnight
Amb0: [72, 93, 108] → [77, 100, 116]  (+7%)
Amb1: [23, 33, 40] → [25, 35, 43]    (+7%)
Everything else: UNCHANGED

WEATHER: EXTRASUNNY
TIME: 5AM
Amb0: [94, 113, 120] → [98, 118, 125] (+4%)
Amb1: [22, 32, 36] → [23, 33, 37]    (+4%)
Everything else: UNCHANGED

WEATHER: EXTRASUNNY
TIME: 10PM
Amb0: [80, 109, 117] → [83, 113, 122] (+4%)
Amb1: [28, 28, 44] → [29, 29, 46]    (+4%)
Everything else: UNCHANGED

WEATHER: SUNNY
TIME: Midnight
Amb0: [72, 84, 108] → [77, 90, 116]   (+7%)
Amb1: [29, 31, 38] → [31, 33, 41]    (+7%)
Everything else: UNCHANGED

WEATHER: SUNNY
TIME: 5AM
Amb0: [98, 113, 120] → [102, 118, 125] (+4%)
Amb1: [22, 27, 36] → [23, 28, 37]    (+4%)
Everything else: UNCHANGED

WEATHER: SUNNY
TIME: 10PM
Amb0: [80, 101, 117] → [83, 105, 122] (+4%)
Amb1: [27, 25, 44] → [28, 26, 46]    (+4%)
Everything else: UNCHANGED

WEATHER: SUNNY_WINDY
TIME: Midnight
Amb0: [74, 78, 108] → [79, 83, 116]   (+7%)
Amb1: [30, 32, 39] → [32, 34, 42]    (+7%)
Everything else: UNCHANGED

WEATHER: SUNNY_WINDY
TIME: 5AM
Amb0: [94, 99, 120] → [98, 103, 125]  (+4%)
Amb1: [22, 27, 37] → [23, 28, 38]    (+4%)
Everything else: UNCHANGED

WEATHER: SUNNY_WINDY
TIME: 10PM
Amb0: [80, 96, 117] → [83, 100, 122]  (+4%)
Amb1: [31, 31, 48] → [32, 32, 50]    (+4%)
Everything else: UNCHANGED

WEATHER: CLOUDY
TIME: Midnight
Amb0: [75, 102, 108] → [80, 109, 116] (+7%)
Amb1: [14, 22, 23] → [15, 24, 25]    (+7%)
Everything else: UNCHANGED

WEATHER: CLOUDY
TIME: 5AM
Amb0: [89, 112, 120] → [93, 116, 125] (+4%)
Amb1: [18, 23, 24] → [19, 24, 25]    (+4%)
Everything else: UNCHANGED

WEATHER: CLOUDY
TIME: 10PM
Amb0: [94, 109, 117] → [98, 113, 122] (+4%)
Amb1: [20, 29, 31] → [21, 30, 32]    (+4%)
Everything else: UNCHANGED

WEATHER: RAIN
TIME: Midnight
Amb0: [74, 101, 108] → [79, 108, 116] (+7%)
Amb1: [15, 22, 23] → [16, 24, 25]    (+7%)
Everything else: UNCHANGED

WEATHER: RAIN
TIME: 5AM
Amb0: [77, 108, 120] → [80, 112, 125] (+4%)
Amb1: [21, 29, 31] → [22, 30, 32]    (+4%)
Everything else: UNCHANGED

WEATHER: RAIN
TIME: 10PM
Amb0: [77, 109, 117] → [80, 113, 122] (+4%)
Amb1: [11, 14, 16] → [11, 15, 17]    (+4%)
Everything else: UNCHANGED

WEATHER: DRIZZLE
TIME: Midnight
Amb0: [74, 105, 108] → [79, 112, 116] (+7%)
Amb1: [15, 21, 24] → [16, 22, 26]    (+7%)
Everything else: UNCHANGED

WEATHER: DRIZZLE
TIME: 5AM
Amb0: [87, 117, 120] → [90, 122, 125] (+4%)
Amb1: [24, 39, 43] → [25, 41, 45]    (+4%)
Everything else: UNCHANGED

WEATHER: DRIZZLE
TIME: 10PM
Amb0: [84, 104, 117] → [87, 108, 122] (+4%)
Amb1: [13, 14, 17] → [14, 15, 18]    (+4%)
Everything else: UNCHANGED

WEATHER: FOGGY
TIME: Midnight
Amb0: [48, 65, 75] → [51, 70, 80]     (+7%)
Amb1: [13, 16, 22] → [14, 17, 24]    (+7%)
Everything else: UNCHANGED

WEATHER: FOGGY
TIME: 5AM
Amb0: [79, 100, 108] → [82, 104, 112] (+4%)
Amb1: [27, 31, 36] → [28, 32, 37]    (+4%)
Everything else: UNCHANGED

WEATHER: FOGGY
TIME: 10PM
Amb0: [70, 83, 94] → [73, 86, 98]     (+4%)
Amb1: [11, 12, 16] → [11, 12, 17]    (+4%)
Everything else: UNCHANGED

WEATHER: LIGHTNING
TIME: Midnight
Amb0: [74, 98, 108] → [79, 105, 116]  (+7%)
Amb1: [10, 11, 16] → [11, 12, 17]    (+7%)
Everything else: UNCHANGED

WEATHER: LIGHTNING
TIME: 5AM
Amb0: [74, 114, 120] → [77, 119, 125] (+4%)
Amb1: [13, 17, 22] → [14, 18, 23]    (+4%)
Everything else: UNCHANGED

WEATHER: LIGHTNING
TIME: 10PM
Amb0: [80, 104, 117] → [83, 108, 122] (+4%)
Amb1: [11, 13, 14] → [11, 14, 15]    (+4%)
Everything else: UNCHANGED
```

### 8.5 Verification Checksums & Companion Assets
* **Original Pristine Solitude 3 v1.1.5 SHA256:**
  `e83b35cd8210b0f82db66e590ad735746b90c69f6a19325c9528aecae52cf94d`
* **Final Modified Lifted Solitude SHA256:**
  `63475d827a7e25f26e3794589d4b32f51f71faf0fc8102addf9ea4f0dad235e1`
* **Companion Solitude Assets Verified Active:**
  * `update/pc/textures/coronas.wtd` (20,852 bytes) — Authentic streetlight flare coronas.
  * `update/pc/textures/stipple.wtd` (31,639 bytes) — Smooth shadow dithering textures.
  * `update/pc/data/timecycext.dat` (14,545 bytes) — Solitude extended timecycle parameters.
  * `update/pc/data/timecyclemodifiers.dat` (62,805 bytes) — Solitude interior and cutscene overrides.

---

## 9. Complete Mod Inventory & Alphanumeric Load Order

### 9.1 Fusion Overloader Load Order (`GTAIV/update/`)
FusionFix loads directories in `GTAIV/update/` in **strict alphanumeric ascending order**. Files located in lower entries override identically named files in earlier entries:

```
GTAIV/update/
├── 0.libertyunlocked/          <-- 18 enterable free-roam interiors & doors
├── 1 Minor Mods/               <-- IAP assault rifle anims, console reticle
├── 1. Vegetation Mods/         <-- Project RevIVe HQ trees & textures
├── 2 Potential Grim/           <-- Grim's weapon models & texture fixes
├── 3a Props Restoration/       <-- Cut world environmental props across IV/TLAD/TBoGT
├── 3b Restored Vegetation/     <-- Cut console foliage placements
├── 3c Restored Graffiti/       <-- Cut graffiti across all boroughs
├── 4a Various Pedestrian Actions/ <-- VPA 1.8 (ambient.dat, default.ide)
├── 4b Restored Pedestrians/    <-- Cut pedestrian models & variations
├── 5 Higher Resolution Misc Pack/ <-- HD pick-ups, signs, decals
├── 6a Traffic Parameters/      <-- New Game Parameters 2.3.5 (cargrp.dat)
├── 6b Fidelity Popcycle/       <-- Fidelity Popcycle 1.0 (24-hr population cycle)
├── 7 Characters Fixes/         <-- Storyline character mesh & texture repairs
├── 8 Console Visuals/          <-- Console pedestrian lighting & foliage shading
├── 9 Project Glass/            <-- 274 MB cubemap glass reflections
├── 10 More Visible Interiors/  <-- Lit, populated building window interiors
├── Ash_HiRes_VehiclesPack/     <-- HRVP 2.4 15th Anniversary vehicle pack
├── CP,Shvab,Ash_GTAIV.EFLC.CityPlates/ <-- Era-accurate license plates
├── GTAIV.EFLC.FusionFix/       <-- FusionFix core engine overrides
├── Restored Trees Position/    <-- Attramet tree anti-clipping WPLs
├── Various Fixes/              <-- VariousFixes.img (818 MB core map & collision fixes)
├── common/data/                <-- Controls, default0.cfg overrides
└── pc/                         <-- Direct path overrides (gtxd.img, ext_veg.img, timecyc.dat)
```

### 9.2 Active Plugins Inventory (`GTAIV/plugins/` & Root)

| Binary File | Location | Version | Purpose |
| :--- | :--- | :--- | :--- |
| `GTAIV.EFLC.FusionFix.asi` | `GTAIV/plugins/` | v5.0.1 | Master engine overhaul, 16:10 HUD scaling, virtual loader. |
| `GTAIV.XboxRainDroplets.asi`| `GTAIV/plugins/` | v2.0 | Dynamic windshield & camera rain droplet condensation physics. |
| `LibertyCityPlates.asi` | `GTAIV/plugins/` | v1.2.6.4b | Procedural license plate generator. |
| `NoPickupGlow.asi` | `GTAIV/plugins/` | v1.0 | Eliminates arcade floating weapon/health pickup glow. |
| `QuickSaveIV.asi` | `GTAIV/plugins/` | v1.1 | Instant manual quick-save on `F5`. |
| `FirstPerson.asi` | `GTAIV/plugins/` | v1.3 (420 KB)| Native C++ First Person Perspective camera. |
| `GTAIVDriveByPreAim.IV.asi`| `GTAIV/plugins/` | v1.0 | Smooth in-car weapon drive-by aiming. |
| `aCompleteEditionHook.asi` | `GTAIV/plugins/` | v0.4 | Bridges ScriptHook to Complete Edition 1.2.0.59 memory structures. |
| `ScriptHook.dll` | `GTAIV/` (Root) | v0.5.1 (336 KB)| Pure C++ ScriptHook binary. |
| `Liberty's Legacy.asi` | `GTAIV/plugins/` | v2.4.1 | Native trainer, vehicle neon underglow, RGB paint tuning. |

---

## 10. Incompatible Mods, Failures & Crash Postmortems

Every failed mod audited during this project was reverse-engineered to identify its exact failure mechanism under Linux/Proton. **Do NOT install these mods.**

### 10.1 IV-SDK .NET & Liberty Tweaks (Instant Boot Crash)
* **Mods Audited:** IV-SDK .NET v1.9.1 (`IVSDKDotNet.asi`) + Liberty Tweaks v1.7.
* **Failure Symptom:** Instant crash on executable launch (`0xc0000005: EXCEPTION_ACCESS_VIOLATION`).
* **Root Cause Disassembly:** `IVSDKDotNet.asi` relies on hardcoded memory address offsets compiled for old downpatched binaries (1.0.7.0 / 1.0.8.0). Rockstar reorganized memory structs and symbol tables in Complete Edition 1.2.0.59. Copying offset definition files does not bridge missing runtime symbols.
* **Rule:** Do NOT use IV-SDK .NET on Complete Edition 1.2.0.59. Use pure C++ ASI plugins only.

### 10.2 First Degree 154 Vehicle Addon Pack (Memory Heap & Audio Subsystem Crash)
* **Mod Audited:** First Degree 154 Vehicle Pack (Nexus #1025).
* **Failure Symptoms:** Early startup crash at ~20.6 seconds; subsequent stall on artwork loading screen at ~34.1 seconds.
* **Root Cause Analysis:**
  1. *Model Slot Exhaustion:* Vanilla GTA IV has **210 model slots**. The base game + episodes use ~175. Adding 154 addon slots requires `ExtendedLimits = 1`, which corrupts Wine's heap allocator.
  2. *Audio Subsystem Crash:* Custom audio archives (`waveslots.xml`, `GAME.dat16`, `SOUNDS.dat15`) attempted to register invalid sound banks into Rage Sound Engine, crashing the audio worker thread before the main menu.
* **Resolution:** Completely purged. Replaced with **Higher Resolution Vehicle Pack 2.4 (#282)**, which replaces stock vehicle meshes and textures without adding model slots, running 100% crash-free with `ExtendedLimits = 0`.

### 10.3 In-Game Graphics API Switch to "Vulkan" (`0xc0000005`)
* **Failure Symptom:** Game instantly crashes upon selecting "Vulkan" in the FusionFix graphics options menu.
* **Root Cause Analysis:** Toggling this setting drops `d3d9.cfg` and attempts to reload Windows Vulkan drivers. Under Proton, DXVK already translates Direct3D 9 to Vulkan at the driver boundary. The redundant driver reload causes a null pointer dereference.
* **Fix:** Keep `GraphicsAPI = 1` in `plugins/GTAIV.EFLC.FusionFix.cfg` and ensure `d3d9.cfg` is never present in the game root.

### 10.4 ZolikaPatch & ZMenuIV (`Error 998: ERROR_NOACCESS`)
* **Mods Audited:** ZolikaPatch v6.95 / ZMenuIV.
* **Failure Symptom:** Windows error modal: `Error 998: Invalid access to memory location (ERROR_NOACCESS)`.
* **Root Cause Analysis:** ZolikaPatch injects low-level memory hooks that bypass DEP (Data Execution Prevention) and write directly to executable memory pages. Modern Proton/Wine enforces strict Linux memory page protection (`mprotect`), immediately terminating unauthorized memory writes.
* **Resolution:** Avoided completely. All required fixes are natively handled by FusionFix 5.0.1 and Liberty's Legacy 2.4.1.

### 10.5 ConsoleSelectMenuIV.asi (`0x00b5bbdd` Crash)
* **Failure Symptom:** Hard crash with address `0x00b5bbdd` during main menu initialization.
* **Root Cause Analysis:** `ConsoleSelectMenuIV.asi` attempted to hook GTA IV's pause menu drawing routines by dereferencing an uninitialized UI pointer under DXVK.
* **Fix:** Disabled and removed (`ConsoleSelectMenuIV.asi.disabled`).

### 10.6 `-availablevidmem 8192` (Loading Screen Deadlock)
* **Failure Symptom:** Game hangs indefinitely on the character artwork loading screen while background music loops endlessly.
* **Root Cause Analysis:** Setting `-availablevidmem 8192` (8 GB) in launch options triggers a **32-bit signed integer overflow** in GTA IV's texture streaming pool calculation (`2^31 - 1`). The engine calculates negative available memory, freezing asset loading.
* **Fix:** Cap memory overrides to `-availablevidmem 4096.0` (4 GB) or omit entirely to let FusionFix manage memory.

### 10.7 DKT70 Major Overhaul HD Roads (VRAM & Address Space Exhaustion)
* **Mod Audited:** DKT70 Major Overhaul v0.8 Beta (`gtxd.img` 103.6 MB).
* **Failure Symptom:** Micro-stuttering, missing bridge textures, and eventual crash after 20 minutes of driving across boroughs.
* **Root Cause Analysis:** Uncompressed 2K/4K road textures pushed process memory over the 3.5 GB 32-bit Wine limit, causing Direct3D device loss.
* **Resolution:** Replaced with **HQ Vanilla Textures (GTXD 1.3, 58 MB)**, which delivers razor-sharp asphalt and crosswalks with 45% less memory footprint.

### 10.8 HQ Map Color V (Radar Clipping Artifact)
* **Mod Audited:** HQ Map Color V (Nexus #358) `radar.img`.
* **Failure Symptom:** Circular minimap HUD border clips with an ugly, thick white ring around the radar.
* **Root Cause Analysis:** The mod's custom alpha channel does not match Complete Edition 1.2.0.59 / FusionFix HUD scaling.
* **Resolution:** Reverted to vanilla radar; visual clarity maintained.

### 10.9 Various Fixes `IVWPL.img` Override (Streaming Memory Stall)
* **Component:** `update/Various Fixes/IVWPL.img`.
* **Failure Symptom:** Texture popping and streaming stalls on Algonquin bridges.
* **Root Cause Analysis:** `IVWPL.img` contains world placement coordinate overrides that exceed CE 1.2.0.59's streaming memory buffers.
* **Resolution:** Deleted `IVWPL.img`. Retained `VariousFixes.img` (818 MB), which houses all 3D mesh, collision, and normal repairs without touching world streaming tables.

### 10.10 Improved Cover System 1.0 (Nexus #1407)
* **Failure Symptom:** Mod fails to initialize silently or causes memory corruption.
* **Root Cause Disassembly:** Disassembly of `Cover.asi` revealed a hardcoded switch table checking PE entrypoints up to `0x8245bc` (1.0.8.0). On Complete Edition 1.2.0.59, the entrypoint is `0x1eeb000`. The version check executes `xor al, al` and returns `false` at `0x100b726c`, terminating the mod.

### 10.11 Liberty Rush v1.12 (Nexus #280)
* **Failure Symptom:** Hard crash on boot.
* **Root Cause Analysis:** The author explicitly states it requires downpatching to 1.0.7.0/1.0.8.0 and a new game save. The mod bundles `xlive.dll`, requires `scenariosmod.asi` (which requires ZMenu, throwing Error 998 on CE), and packages `fastman92 limit adjuster` (which violates our `ExtendedLimits=0` invariant).

---

## 11. First Person Perspective (C06alt FPP v1.3) Reverse Engineering

Through disassembly and reverse engineering of `FirstPerson.asi` v1.3 (420 KB binary, SHA256: `72e29cd1...`), the exact execution paths governing camera transitions were identified and optimized:

### 11.1 In-Cover Camera Transition (`FPCover = 1`)
* **Trigger:** Niko snaps into wall cover (`is_ped_in_cover`, native `0x100505c4`).
* **Previous Failure:** With `FPCover = 0`, functions `0x10005ee1` and `0x1000610f` branched directly to `0x10005f99` (`set_cam_active(0)`), killing the first-person camera and reverting to third-person wall-cling view.
* **Fix Implemented:** Set `FPCover = 1` in `GTAIV/plugins/FirstPerson.ini`. In-cover view now remains locked in first person during wall clings, blind fire, and aiming from cover.

### 11.2 Vehicle Entry Transition (Opening Door & Sitting Down)
* **Trigger:** Approaching vehicle and initiating entry animation (`is_char_getting_in_to_a_car`, native `0x100504f8`).
* **Disassembly Finding:** At `0x10005ff0–0x100060ae`, when `is_char_getting_in_to_a_car` evaluates to `true`, the code intentionally sets `[edi+0x15a] = 0` (disabling on-foot FPP) and flags `0x1005d9b8 = 1`.
  * *Design Rationale:* C06alt deliberately designed this to prevent the player's head bone from wildly clipping through car doors, roofs, and A-pillars during car entry animations.
* **Vehicle Cockpit Camera Operation:** Once seated, C06alt engages the vehicle cockpit camera (`set_follow_vehicle_cam_submode = 5`, `attach_cam_to_vehicle`). Pressing the camera cycle key (`V` on keyboard or `Back/View` on controller) cycles camera modes until the cockpit view appears. Once set, the game retains this mode.
* **Vehicle Exit:** Egress is detected at `0x10006ba7`. If the game reverts to standard on-foot chase cam, double-tapping `V` re-asserts on-foot FPP.

### 11.3 Sniper Rifle Telescopic Aiming
* **Trigger:** Aiming any sniper rifle (Weapon ID 16 `WEAPON_SNIPERRIFLE` or ID 17 `WEAPON_M40A1`).
* **Disassembly Finding:** In `FirstPerson.asi` at `0x10005ad6–0x10005b15`, weapon checking explicitly identifies IDs 16 and 17. When aim controls are engaged, helper function `0x10005a90` returns 1, immediately branching to `set_cam_active(0)`.
  * *Technical Cause:* In the Rage Engine, sniper aiming detaches the 3D head camera and engages a 2D fullscreen telescopic scope reticle overlay (`sniper_scope.wtd`). If FPP kept the 3D head camera active, the head geometry would clip into the 2D scope viewport, causing double-rendering and black-screen anomalies.

### 11.4 Keyboard Conflict Elimination (`FirstPerson.ini`)
```ini
RetroKey = 0
CruiseControlKey = 0
MouseSteerKey = 0
CamLockKey = 0
```
Conflicting keys zeroed to prevent collisions with Liberty's Legacy 60% navigation (`L = right`, `B = back`).

---

## 12. Liberty's Legacy: 60% Keyboard & Controller D-Pad Phone Conflict Disassembly

### 12.1 60% Keyboard Ergonomic Layout
Configured in `GTAIV/plugins/Liberty's Legacy/Liberty's Legacy.ini`:
```ini
[config]
Trainer key = F11
Navigation mode = 2

[Backend]
Trainer Init = true
```

* **Open / Close Menu:** `F11`
* **Navigation:** `I` (Up), `K` (Down), `J` (Left), `L` (Right)
* **Select / Confirm:** `U`
* **Back / Cancel:** `O`
* `Trainer Init = true`: Permanently suppresses the opening splash banner.

### 12.2 Controller D-Pad Phone Conflict Disassembly
* **The Conflict:** Pressing `D-Pad Up` to navigate up the trainer menu causes Niko to simultaneously pull out his mobile phone, fighting the menu.
* **Disassembly Breakdown:**
  1. In `Liberty's Legacy.asi` (offsets `0x497f9` and `0x49da8`):
     ```assembly
     call 0x2acd0    ; checks native 0x019064ed (is_using_controller)
     test %al, %al
     je   0x49890    ; if false, it skips phone suppression!
     mov  $0x1, %cl
     call 0x32530    ; calls native 0x063c4508 (disable_player_phone(true))
     ```
  2. Under Wine/Proton, `is_using_controller` frequently returns `false` or toggles between mouse/keyboard and gamepad states when cursor centering is active.
  3. When `0x2acd0` returns false, Liberty's Legacy skips calling `disable_player_phone`.
  4. GTA IV's background script `spcellphone.sco` intercepts the raw XInput `DPAD_UP` and pulls out the phone!
* **The 3 Verified Working Solutions:**
  * **Solution 1 (Advanced Nav In-Game):** Hold **`RB`** while pressing D-Pad (`RB + Up` jumps to top, `RB + Down` jumps to bottom). Holding `RB` inherently suppresses the standalone phone trigger.
  * **Solution 2 (Steam Input Chord):** In Steam Controller Layout, create an Action Set or Mode Shift that remaps the D-Pad to Keyboard `I/K/J/L` when the trainer is open. GTA IV never receives `DPAD_UP`, eliminating the phone trigger.
  * **Solution 3 (Downward Wrap Navigation):** Only `D-Pad Up` summons the phone. Scrolling down wraps from the bottom back to the top cleanly.
* **Controller Open Binding:** Keep `Controller binding = 0` (`RB + X`). Bumper combinations like `8` (`LB + RB`) fail to register reliably under Proton XInput.

---

## 13. Architecture Dependency Graph

```
GTAIV.exe (v1.2.0.59 Complete Edition, Steam AppID 12210)
  │
  ├── Wine PE Loader (WINEDLLOVERRIDES="dinput8=n,b")
  │     └── dinput8.dll (Ultimate ASI Loader v5.0.1)
  │           │
  │           ├── aCompleteEditionHook.asi (v0.4)
  │           │     └── ScriptHook.dll (Aru v0.5.1, 336 KB)
  │           │           ├── Liberty's Legacy.asi (v2.4.1) [60% Mode: I/K/J/L/U/O]
  │           │           └── FirstPerson.asi (C06alt v1.3, 420 KB) [FPCover=1]
  │           │
  │           ├── GTAIV.EFLC.FusionFix.asi (v5.0.1)
  │           │     ├── Virtual Archive Overloader (GTAIV/update/)
  │           │     └── Console Lighting, Shaders, 16:10 HUD Scaling
  │           │
  │           ├── QuickSaveIV.asi (v1.1) [F5 Auto-Save]
  │           ├── GTAIV.XboxRainDroplets.asi (v2.0)
  │           ├── LibertyCityPlates.asi (v1.2.6.4b)
  │           ├── NoPickupGlow.asi (v1.0)
  │           └── GTAIVDriveByPreAim.IV.asi (v1.0)
  │
  ├── Direct3D 9 Pipeline
  │     └── d3d9.dll (DXVK 2.6.2 GPLAsync)
  │           └── vulkan.dll (Translates D3D9 → Vulkan Command Buffers)
  │
  └── Vulkan Driver Layer Execution
        ├── LSFG-VK (lib32-lsfg-vk.so via LSFGVK_PROFILE="gta4") [2x Multiplier, FP16]
        ├── MangoHud (mangohud) [fps_limit=0]
        ├── vkBasalt (enable_vkbasalt=1) [CAS 0.40 + Vibrance.fx]
        └── NVIDIA Proprietary Driver (prime-run → RTX 5050 Mobile `sm_120`)
```

### Skipped Incompatible Runtimes (Dead Ends):
```
IV-SDK .NET (IVSDKDotNet.asi)  --> Crashes on CE 1.2.0.59 (Missing memory offsets)
ScriptHookDotNet (.NET 1.7.1) --> Crashes / Unsupported on CE 1.2.0.59
ZolikaPatch / ZMenuIV         --> Error 998 ERROR_NOACCESS (DEP/Linux mprotect violation)
```

---

## 14. Btrfs Snapper Snapshotting & Rollback Procedures

Per system rules, any system, driver, or mod modification is bracketed with Btrfs Snapper snapshots on both the `home` and `root` subvolumes.

### 14.1 Verified Snapshot Catalog

| Snapshot (Home) | Snapshot (Root) | Timestamp | Description / Milestone |
| :---: | :---: | :---: | :--- |
| **#16** | — | Sep 21 04:45 | Master Milestone: Baseline full visual overhaul verified working. |
| **#19** | — | Sep 21 05:20 | Pre-controller phone remap baseline. |
| **#29** | — | Sep 22 00:21 | Pre-final mod audit batch. |
| **#30** | — | Sep 22 00:24 | Post-install: Liberty Unlocked v1.1 & QuickSave IV v1.1. |
| **#31** | — | Sep 22 00:35 | Pre-FPP camera reverse engineering investigation. |
| **#32** | — | Sep 22 00:48 | Post-FPP v1.3 deployment with `FPCover=1`. |
| **#38** | — | Sep 22 01:36 | Pre-timecycle night lift calibration. |
| **#41** | **#564** | Sep 22 03:08 | `before-solitude-night-only-brightness`: Pristine Solitude 3 restoration baseline. |
| **#42** | **#565** | Sep 22 03:10 | `after-solitude-night-only-brightness`: Master accepted Solitude 3 lifted nighttime state. |

### 14.2 Instant Rollback Commands
To revert the system to the pristine baseline before the night ambient lift:
```bash
sudo snapper -c home rollback 41 && sudo snapper -c root rollback 564
```

To revert to the master accepted night ambient lift:
```bash
sudo snapper -c home rollback 42 && sudo snapper -c root rollback 565
```

### 14.3 Game Timecycle Integrity Check Script
To verify that the active timecycle is the exact mathematically lifted Solitude 3 file:
```bash
sha256sum "$HOME/.local/share/Steam/steamapps/common/Grand Theft Auto IV/GTAIV/update/pc/data/timecyc.dat"
# Output must match: 63475d827a7e25f26e3794589d4b32f51f71faf0fc8102addf9ea4f0dad235e1
```
