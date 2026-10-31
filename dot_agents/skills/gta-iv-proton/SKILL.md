---
name: gta-iv-proton
description: Launch configuration, Proton prefix handling, DXVK/FusionFix modding, and troubleshooting guidelines for Grand Theft Auto IV (Complete Edition) on CachyOS with RTX 5050 Mobile. Reference from Gillian's Guide.
---

## Authority and freshness

This skill is procedural guidance, not a current machine-state authority. Before using any machine-specific path, device name, GPU mode, desktop/session, filesystem, version, or service-state claim below, read `~/.local/share/chezmoi/AGENTS.md`, `~/.local/share/chezmoi/docs/system/SYSTEM_CONTEXT.md`, `~/.local/share/chezmoi/docs/system/SUBSYSTEM_MAP.md`, the owning subsystem documentation, and current repo source; verify live state when available. Higher-authority evidence overrides this skill. Treat dated verification blocks as historical evidence unless re-verified.

# Grand Theft Auto IV (Complete Edition) Proton & Modding Guide

**Target Hardware:** ASUS TUF Gaming F16 (Intel i5-13450HX + NVIDIA GeForce RTX 5050 Mobile `sm_120`)  
**OS/Desktop:** CachyOS rolling, Sway (Wayland) / i3wm (X11) @ 1920x1200 165Hz (16:10)  
**Game Root:** `~/.local/share/Steam/steamapps/common/Grand Theft Auto IV/GTAIV` (Native NVMe Btrfs partition, strictly NO NTFS)  
**Steam AppID / Prefix:** `12210` (`~/.local/share/Steam/steamapps/compatdata/12210/pfx`)  
**Save Games Path:** `~/.local/share/Steam/steamapps/compatdata/12210/pfx/drive_c/users/steamuser/Documents/Rockstar Games/GTA IV/Profiles/`

---

## 1. Verified Working Baseline Parameters

### Proton Compatibility Tool:
- **GE-Proton11-7-x86_64** / **Proton Experimental** (Essential: avoids the Rockstar Games Launcher Chromium CEF timeout crash present in older Proton 9 builds).

### Steam Launch Options:
```bash
WINEDLLOVERRIDES="dinput8=n,b" ENABLE_VKBASALT=1 prime-run mangohud %command%
```
- `WINEDLLOVERRIDES="dinput8=n,b"`: Loads the Ultimate ASI Loader DLL.
- `ENABLE_VKBASALT=1`: Activates post-processing vibrance shaders.
- `prime-run`: Offloads rendering to the RTX 5050 Mobile dGPU.
- `mangohud`: Displays minimal HUD and frametime graph.
- Note on LSFG-VK: Adding `LSFGVK_PROFILE="gta4"` on top of native 85-90 FPS loads the GPU heavily with optical flow passes and drops base framerate to ~48 FPS. For lowest input latency and flat 11ms frametime pacing, native rendering is recommended.

---

## 2. Verified Mod Stack (Only What Worked on Complete Edition 1.2.0.59)

| Mod | Version | Link | Purpose / Notes |
|---|---|---|---|
| **FusionFix** | **v5.0.1** | [GitHub Releases](https://github.com/ThirteenAG/GTAIV-FusionFix/releases) | Bundles Ultimate ASI Loader (`dinput8.dll`), DXVK/Vulkan (`d3d9.dll`, `vulkan.dll`), console lighting, 16:10 HUD scale. |
| **Aru's ScriptHook** | **v0.5.1 (336 KB)** | [HazardX Release](https://github.com/HazardX/gta4_scripthookdotnet/releases/tag/v1.7.1.7b) | Pure native C++ ScriptHook (`ScriptHook.dll`). Do NOT use the 1.0.8.0 modified build. |
| **ScriptHook CE Patch** | **v0.4** | [LCPDFR](https://www.lcpdfr.com/downloads/gta4mods/g17media/26726-compatibility-patch-for-gta-iv-complete-edition/) | Bridges ScriptHook to Complete Edition (`aCompleteEditionHook.asi`). |
| **Liberty's Legacy Trainer** | **v2.4.1** | [Nexus Mods #100](https://www.nexusmods.com/gta4/mods/100) | Full mod menu (`Liberty's Legacy.asi` + `Liberty's Legacy/`). Native 60% keyboard support. |
| **LSFG-VK (32-Bit)** | **Latest** | AUR: `aur/lib32-lsfg-vk` | 32-bit Vulkan frame generation layer for `GTAIV.exe`. |
| **DXVK 2.6.2 GPLAsync** | **v2.6.2** | [Nexus Mods #385](https://www.nexusmods.com/gta4/mods/385) | Custom `vulkan.dll` + `GTAIV.dxvk-cache` (99 KB). Asynchronous shader compilation eliminates pipeline hitching. |
| **HQ Metallic Car Paint** | **v1.01** | [Nexus Mods #503](https://www.nexusmods.com/gta4/mods/503) | `update/pc/models/cdimages/vehicles.img` (89.5 MB). High-definition tire treads and metallic flake reflections. |
| **HQ Vanilla Textures (Jersey)** | **v1.3** | [Nexus Mods #781](https://www.nexusmods.com/gta4/mods/781) | `update/pc/data/maps/jersey/` (2.4 GB). Revitalizes Alderney world map textures. |
| **Natural Timecycle By DayL** | **v1.1.9** | [Nexus Mods #396](https://www.nexusmods.com/gta4/mods/396) | Authentic, vibrant New York lighting. Native Tonemapper, zero Vulkan overhead. |
| **Xbox Rain Droplets** | **v2.0** | [Nexus Mods #298](https://www.nexusmods.com/gta4/mods/298) | **VERIFIED WORKING & ACTIVE.** `GTAIV.XboxRainDroplets.asi` in `plugins/`. Restores Xbox 360 windshield/camera water droplet condensation. |
| **Improved Animations Pack** | **B Dawg Build** | [GTAForums #958625](https://gtaforums.com/topic/958625-improved-animations-pack/) | Pre-packaged in Gillian's `update/1 Minor Mods/` (`IAP.IV.img`, etc.). Restores console assault rifle animations and fire rates. |
| **LibertyCityPlates** | **v1.2.6.4b** | [Nexus Mods #875](https://www.nexusmods.com/gta4/mods/875) | **VERIFIED INSTALLED & ACTIVE.** `plugins/LibertyCityPlates.asi` + `update/CP,Shvab,Ash_GTAIV.EFLC.CityPlates/`. Era-accurate randomized state plates. |
| **Various Pedestrian Actions** | **v1.8** | [Nexus Mods #843](https://www.nexusmods.com/gta4/mods/843) | **VERIFIED INSTALLED & ACTIVE.** `update/4a Various Pedestrian Actions/VPA.img` + `Ambient.dat` & `default.ide`. Varied civilian behaviors. |
| **Euphoria Action Ragdolls** | **v1.1** | [Nexus Mods #364](https://www.nexusmods.com/gta4/mods/364) | **VERIFIED INSTALLED & ACTIVE.** Standalone Overloader conversion (`update/4c Euphoria Action Ragdolls/pc/data/game.rpf` & `update/pc/data/game.rpf`). 16-round AES-ECB encrypted RPF2 packfile virtualizing modded `taskparams.txt`. Original `pc/data/game.rpf` 100% untouched. |
| **CoPPoT (Correction of Transport Parameters)** | **v2.0.1** | [Nexus Mods #714](https://www.nexusmods.com/gta4/mods/714) | **VERIFIED INSTALLED & ACTIVE.** `update/6c CoPPoT/*/common/data/handling.dat`. Vanilla-consistent physics adjustments: stiffer suspension, corrected drivetrains, ABS, bus braking. Zero model slot impact. |
| **Ockky's Better Blood Pack** | **v0.5** | [Nexus Mods #785](https://www.nexusmods.com/gta4/mods/785) | **VERIFIED INSTALLED & ACTIVE.** `update/Ockky Blood/pc/textures/` (`fxprojtex.wtd`, `peddamage.wtd`, `bloodFx.dat`). High-definition wound decals and pooling; camera blood drops disabled via `BloodDrops=0` in `GTAIV.XboxRainDroplets.ini`. |
| **GTA IV Trilogy HD Upscaled Protagonists** | **v1.0** | [Nexus Mods #258](https://www.nexusmods.com/gta4/mods/258) | **VERIFIED INSTALLED & ACTIVE.** LURP Niko removed. Clean replacement in `GTAIV/pc/models/cdimages/playerped.rpf` (147 MB); Johnny & Luis virtualized in `update/TLAD/` (24 MB) and `update/TBoGT/` (35 MB). |

| **IV Lane Vanilla Friendly** | **Latest** | [GTAInside](https://www.gtainside.com/en/gta4/mods/186727-vanilla-friendly-hd-roads/) / DayL | **VERIFIED INSTALLED & ACTIVE.** `update/VanillaFriendly.IVLane/` (`VanillaFriendly.IVLane.img` 1.31 GB + TLAD/TBoGT) + `gtxd.img` (58.8 MB). Faithful high-res vanilla tarmac replacing DKT70 baseline. |

| **Project Lights** | **Early Access (Modloader)** | DayL Discord / ChunkLeChuck | **VERIFIED INSTALLED & ACTIVE.** `update/1.ProjectLights/` (`Project.Lights.img` 173 MB + IV/TLAD/TBoGT sub-archives) + 2DFX `.ide` prop definitions in `update/pc/data/maps/props/`. Emissive lighting across 500+ map models. |
| **Gillian's Visual Pack** | **2026 Build** | `1.2 archive.7z` | Safe modules in `update/`: `1 Minor Mods`, `2 Potential Grim`, `3a Props`, `3b Veg`, `3c Graffiti`, `4a/b Peds`, `5 HiRes Misc`, `7 Characters`, `8 Console Visuals`, `9 Project Glass`, `10 Visible Interiors`, `Various Fixes/VariousFixes.img`. |





### Incompatible / Problematic Mods (Do NOT Use):
- **PRGS 3.1 (Project Realistic Gun Sounds, Nexus #437):** Fatal boot crash (`Exit code 0xc0000409` `STATUS_STACK_BUFFER_OVERRUN`). In Complete Edition 1.2.0.59, Rage Sound Engine allocates static internal memory descriptors for resident sound banks. PRGS sound banks (`EP2_RESIDENT` 3.3MB vs vanilla 520KB) overflow the internal bank descriptor arrays during pre-main-menu initialization, triggering `free(): corrupted unsorted chunks` in Wine/glibc. Reverted.
- **Winter Pedestrians v1.0 (Nexus #856) & Restored Pedestrians v2.0 (Nexus #911):** Crash on boot (`0xc0000409` and heap corruption). Mounting `Winter Pedestrians.img` (360 MB) + `RestoredPeds.img` (115.5 MB) on top of HRVP 2.4, Jersey 1.3, and VariousFixes pushes GTA IV beyond the 3.5 GB 32-bit Direct3D address space ceiling with `ExtendedLimits = 0`. Additionally, Restored Pedestrians v2.0 introduces cut pedestrian voice tags into `peds.ide` that trigger unhandled memory exceptions in CE 1.2.0.59. Reverted to stable Gillian 4b baseline.
- **First Degree 154 Vehicle Addon Pack (Nexus #1025):** Crash on boot. Requires `ExtendedLimits = 1` and massive vehicle data tables, which trigger memory heap exhaustion / corruption under Wine/Proton. Reverted.
- **DKT70 HD Road Overhaul (Nexus #643):** Crash / instability under DXVK when `gtxd.img` is replaced over an existing OverLoader texture stack. Reverted.
- **HQ Map Color V (Nexus #358):** Visual artifacting. Custom `radar.img` causes circular minimap HUD border alpha clipping and a thick white ring on CE 1.2.0.59 / DXVK. Omit.
- **IV-SDK .NET / Liberty Tweaks:** Incompatible with Complete Edition 1.2.0.59 memory layouts. Triggers instant `EXCEPTION_ACCESS_VIOLATION` on boot. Only works on downpatched 1.0.8.0/1.0.7.0.
- **Corrupted Vehicle Pack Download (Nexus #282):** User's downloaded zip has CRC errors on `IV_Vehicle_Pack.img`. If installing Mod #282, must re-download cleanly from Nexus first.
- **ZMenuIV / ZolikaPatch:** Incompatible with Complete Edition 1.2.0.59 (throws `Error 998` `ERROR_NOACCESS`).
- **iCEnhancer 4.0 / Legacy ENBs:** Hardcoded to 2009 patch 1.0.4.0; crashes on modern CE.
- **Realistic Visual 20.0:** Forces DX9 ReShade, breaking FusionFix's native Vulkan/DXVK pipeline.
- **ConsoleSelectMenuIV.asi:** Crashes menu hooks on CE 1.2.0.59.
- **Vehicle Packs / 6b Vehicle Mods:** Corrupts CE 1.2.0.59 vehicle tables (`Invalid resource detected`).
- **Various Fixes WPL Overrides (`IVWPL.img`):** Exceeds world streaming tables on CE 1.2.0.59; use only `VariousFixes.img`.
- **DLSS-IV (Nexus #1430, v1.0.4/1.0.5):** Fatal freeze & crash on entering in-engine 3D world (`dlssiv-helper.exe` dumped core with `Signal 6 (ABRT)`). In Proton/Wine, cross-process Vulkan ↔ D3D12 shared texture descriptor imports fail (`ROUND TRIP FAILED: GetRenderTargetData failed`, `bone texture vertex-texture test failed`), dropping the connection and triggering device-loss assertion aborts even with `threaded=0`. Reverted to proven DXVK 2.6.2 GPLAsync + FusionFix AA.
- **ScriptHookDotNet (HazardX / Tomasak v1.7.1.8) on Modern Proton:** Fatal hang/crash before loading 3D world (`[INFO] [ScriptHookDotNet] Thread started` followed by Direct3D freeze). Mixed-mode C++/CLI assembly cannot properly host the .NET AppDomain/CLR under Wine Mono. Native `dotnet472` via protontricks fails on modern Wine 10/11 WoW64 (`FDICopy failed` on `netfx_core.mzz` error 1603). Pure C++ ASI mods remain the only stable modding stack on Linux.
- **b-bridge (v0.1.2, Out-of-Process D3D9 Transport Layer):** Severe performance regression under heavily modded configurations (~29 FPS @ 34.6 ms vs 60–100+ FPS native). While functionally operational with PRIME offloading to RTX 5050 Mobile and providing +96.32 MB contiguous address headroom, GTA IV's heavy mod stack (FusionFix console lighting + DayL/Solitude tonemapper + IV-LANE) dispatches ~15,058 D3D9 calls per frame (~436,000 cmds/sec). Synchronous cross-process occlusion/event queries (`Direct3DQuery9_LSS::GetData()`) across the 32-bit $\leftrightarrow$ 64-bit Wine shared-memory boundary stall the CPU render thread for ~22.6 ms per frame. Reverted to in-process DXVK 2.6.2 GPLAsync.
- **`ExtendedLimits = 1`:** Triggers heap crash on Wine/Proton; keep strictly at `0`.

---

## 3. Liberty's Legacy: 60% Keyboard, Controller & Phone Conflict Fixes

In `Liberty's Legacy/Liberty's Legacy.ini`:
```ini
[config]
Trainer key = F11
Navigation mode = 2    # 60% keyboard layout (I/K/J/L/U/O)

[Settings]
Controller binding = 0 # 0 = RB + X (Default open combination; 8 = LB + RB)

[Backend]
Trainer Init = true    # Permanently bypasses the introductory splash
```

### Controls (60% Mode):
- **Open/Close:** `F11`
- **Navigation:** `I` (Up), `K` (Down), `J` (Left / Decrease value), `L` (Right / Increase value)
- **Select / Confirm:** `Enter` (`Return` key — binary patched in `Liberty's Legacy.asi` at offset `0x43768` replacing hardcoded `U`)
- **Back:** `O`

### Controller / Gamepad Navigation & D-Pad Phone Conflict:
- **Root Cause & Binary Fix:** In `Liberty's Legacy.asi`, `call 0x2acd0` (`is_using_controller`) returned `0` (`false`) under Proton/Wine, taking the jump `je 0x49890` and skipping `DISABLE_PLAYER_PHONE(true)`. NOPing this 6-byte jump (`90 90 90 90 90 90` at offset `0x49800`) forces the trainer to call `disable_player_phone(true)` whenever the menu is open. D-Pad Up navigates up without pulling out the phone! When the menu is closed, the phone functions normally.
- **Xbox Rain Droplets Blood Sprites Fix:** In `plugins/GTAIV.XboxRainDroplets.ini`, set `BloodDrops = 0` to disable red blood droplet sprites on the camera lens while keeping all in-game exaggerated ped wounds, blood decals, and pools intact.
- **Controller Open Key:** Keep `Controller binding = 0` (`RB + X`). Simultaneous bumper bindings like `8` (`LB + RB`) fail to register reliably on Proton XInput gamepads.

---

## 4. Full Setup Guide for a New Linux/Proton Installation

1. **Prerequisites:** Steam library on native Linux Btrfs/Ext4 (never NTFS).
2. **Proton:** Force **GE-Proton11-7-x86_64** in Steam Play properties.
3. **Launch Options:** Set `WINEDLLOVERRIDES="dinput8=n,b" prime-run mangohud %command%`.
4. **DirectX 9 Native Runtime & Shader Compiler:** Run `protontricks 12210 -q d3dcompiler_43 d3dx9`. (Mandatory: prevents error `E5033: Unknown target profile '__fx_2_0__'` caused by Wine's builtin HLSL compiler failing on fx_2_0 shader targets).
5. **Install FusionFix v5.0.1:** Extract `GTAIV.EFLC.FusionFix.zip` into `.../GTAIV/`.
6. **Install ScriptHook CE Bridge:**
   - Copy only `ScriptHook.dll` (v0.5.1, 336 KB) from HazardX into `.../GTAIV/`.
   - Copy only `aCompleteEditionHook.asi` from LCPDFR into `.../GTAIV/`.
7. **Install Liberty's Legacy v2.4.1:** Extract `Liberty's Legacy.asi` and `Liberty's Legacy/` into `.../GTAIV/`. Set `Navigation mode = 2` and `Trainer Init = true` in `Liberty's Legacy.ini`.
8. **In-Game Settings:** Set Windowed Borderless `On`, Pause on Focus Loss `Off`.

---

## 5. Verified Milestone: 165Hz Uncap & Safe "Various Fixes"

* **165Hz Uncap Configuration:**
  - `commandline.txt` in `GTAIV/`: `-width 1920 -height 1200 -refreshrate 165 -frameLimit 0 -novblank -nomemrestrict -norestrictions`
  - `dxvk.conf` in `GTAIV/`: `d3d9.presentInterval = 0`, `d3d9.maxFrameRate = 0`, `dxvk.tearFree = True`
  - `GTAIV.EFLC.FusionFix.cfg`: `FpsLimitPreset = 0`
* **Safe Various Fixes Architecture:**
  - Active: `update/Various Fixes/VariousFixes.img` (818 MB core fixes).
  - Excluded: `IVWPL.img` (coordinate overrides), `ExtendedLimits = 1` (Wine heap crash).
  - **Trade-off Analysis:** Excluded WPLs only adjust coordinates of a few minor street props. All 3D model fixes, missing collision meshes (preventing floor clipping), repaired normals, and shadow boxes are 100% retained.

* **Detailed Reference:** Full Gillian-style Linux walkthrough is maintained in [`~/docs/gaming/gta-iv/native-proton-setup.md`](file:///home/manisk/docs/gaming/gta-iv/native-proton-setup.md).

## 6. Higher Resolution Vehicle Pack #282 & First-Person Roadmaps

### Vehicle Pack #282 Reality:
- **Architecture:** Compatible with CE when using dedicated Complete Edition package with FusionFix 1.52+ (`update/Ash_HiRes_VehiclesPack/`).
- **Memory vs Taxi Bug:** Requires increased `VehicleBudget` (recommended: `78000000` to `120000000`) in `GTAIV.EFLC.FusionFix.ini`.
- **The 15 Sound-Slot Limit:** Setting `VehicleBudget` too high exposes the engine's 15-slot sound bank ceiling, causing vehicles to drop engine/door audio. `VehicleBudget = 120000000` is the optimal balance. Version 2.4 also offers a `LibertyCityPlates` optimized pack to reduce memory load.
- **Local Download Status:** Check zip with `7z t` before installing; recent transfer failed CRC and must be re-downloaded cleanly.

### First-Person Options on Complete Edition 1.2.0.59:
- **C06alt First Person v1.3 (Community CE Workaround / Experimental):**
  - *Original compatibility:* Designed for 1.0.7.0/1.0.8.0 with old C++ ScriptHook + ASI loader + HazardX .NET ScriptHook.
  * *CE 1.2.0.59 Workaround (August 2025 report):* Can run on Complete Edition without downpatching via `FusionFix + ScriptHookDotNet 1.7.1.7b + aCompleteEditionHook.asi + C06alt First Person v1.3`.
  * *Modern FusionFix layout (September 2025 report):* Place `FirstPerson.asi` and `FirstPerson.ini` directly in `GTAIV/plugins/` (and remove `scripts/`). Verified functioning on **Steam Deck** (Linux/Proton).
  * *Status:* Treat as an experimental community workaround rather than official CE support due to legacy .NET dependency (target was CE 1.2.0.43).
- **Modern RTX FusionFix First Person Fork (Nexus #1237):** Requires replacing the main FusionFix ASI with the RTX Remix fork; conflicts with normal FusionFix 5.0.1 and has aiming misalignment quirks. Not recommended for standard Linux/Proton stacks.

---

## 7. Liberty Tweaks & IV-SDK .NET Incompatibility Autopsy

- **Mod:** Liberty Tweaks v1.7 (`LibertyTweaks1.7.zip`) + IV-SDK .NET v1.9.1 (`IV-SDK.NET.v1.9.1.zip`).
- **Observed Result:** **Instant crash on boot (`EXCEPTION_ACCESS_VIOLATION`).**
- **Root Cause:** `IVSDKDotNet.asi` requires hardcoded memory address offsets that match 1.0.7.0/1.0.8.0 binary compilation structures. Official Steam Complete Edition 1.2.0.59 rearranged memory structs; cloning offset files does not overcome missing memory symbols.
- **Rule for Future Reference:** Do NOT attempt to run IV-SDK .NET on Complete Edition 1.2.0.59 without a full memory offset rewrite or downpatching the game to 1.0.8.0. Pure C++ ASI mods (`aCompleteEditionHook.asi`, `Liberty's Legacy.asi`, `FusionFix.asi`) remain the only 100% stable modding stack.

---

## 8. Custom Vehicle Addons + Liberty Vehicle Services CE + DKT70 Roads Architecture

- **Verdict:** Fully compatible when deployed sequentially.
- **DKT70 HD Roads (FusionFix Edition):** Pure texture replacement (`.img`/`.wtd`) for streets/sidewalks. Zero conflict with scripts or handling. Must use modern downscaled FusionFix versions (512x512/1024x1024) to avoid DirectX 9 32-bit address space exhaustion and bridge streaming pop-in.
- **Liberty Vehicle Services CE (v0.96 Beta, Nexus #1125):** Native C++ script for Complete Edition. Supports addon vehicles via experimental flags (`LoadAddonVehicleDataFiles=true`, `FuelAffectsUnknownVehicles=false` in `LibertyVehicleServices.ini`).
- **Vehicle Addon Packs:** Must keep `ExtendedLimits = 0` (Wine heap stability) and calibrate `VehicleBudget = 144000000` (prevents taxi bugs while respecting GTA IV's hardcoded 15-slot audio engine ceiling).
- **Safe Rollout Order:** LVS CE $\rightarrow$ Test vanilla cars $\rightarrow$ Addon Vehicle Pack $\rightarrow$ Test traffic/audio $\rightarrow$ DKT70 FusionFix HD Roads.

---

## 9. DriftIV 3.0 & LibertyCityPlates Integration

- **Mod:** DriftIV v3.0 (AWD - Default V3 recommended variant).
- **Current Status:** **Parked in Standby** at `GTAIV/standby_mods/DriftIV_3.0_AWD_Default/`. Game runs on vanilla handling curves.
- **Quick Re-enable:** `cp -r "$GAME_DIR/standby_mods/DriftIV_3.0_AWD_Default/"* "$GAME_DIR/update/"`.
- **LibertyCityPlates Hex Flag Rule:** Pre-patched with custom plate hex flags (`20040048`, `20224008`, `20000008`, `20004048`) directly into DriftIV's handling lines to preserve commercial vehicle plate assignments.

---

## 10. IV-LANE Road Revamp & Global Texture Dictionary (gtxd.img)

- **Mod:** IV-LANE (Base & EFLC releases by UncleDisco & DKTronics70).
- **Architecture & Packaging:** 475 discrete `.wdr` road meshes and `.wtd` texture dictionaries compiled into a single unencrypted RAGE IMG3 archive: `update/1 IV-LANE/ivlane.img` (1.15 GB).
- **Global Texture Dictionary (`gtxd.img`):** Full 166 MB high-definition global road texture dictionary deployed at `update/1 IV-LANE/gtxd.img` and `update/pc/data/cdimages/gtxd.img`, superseding the legacy DKT70 baseline.
- **Load Order Invariant:** `1 IV-LANE` precedes numbered mod folders (`2 Potential Grim`, `3a Props`, `8 Console Visuals`), preventing conflicting texture overrides and streaming glitches.
- **Stability Invariant:** Operates smoothly with `ExtendedLimits = 0`. Maintains ~2.5 GB memory footprint under Wine/Proton, leaving generous headroom below the 3.5 GB 32-bit direct address ceiling.

---

## 11. The Assassination Mod v1.0 (.NET Stack on CE 1.2.0.59)

- **Mod:** The Assassination Mod v1.0 (`Ass.net.dll`).
- **Dependency Stack:** Requires `ScriptHookDotNet.asi` (HazardX v1.7.1.7b) + `ScriptHookDotNet.dll` loaded alongside `aCompleteEditionHook.asi` and `ScriptHook.dll`.
- **Placement:**
  - `GTAIV/ScriptHookDotNet.asi` & `GTAIV/ScriptHookDotNet.dll`
  - `GTAIV/scripts/Ass.net.dll` & `GTAIV/scripts/ScriptHookDotNet.dll`
- **Gameplay Trigger:**
  - Payphones ring across Liberty City; approach and press action button (`E` / Controller LB).
  - Middle Park public restrooms trigger assassination contracts.
  - Press `K` while inside a vehicle to access assassin equipment.
- **Fast Rollback Command:** If .NET CLR initialization causes Wine crashes:
  ```bash
  rm -f "$HOME/.local/share/Steam/steamapps/common/Grand Theft Auto IV/GTAIV/ScriptHookDotNet.asi" \
        "$HOME/.local/share/Steam/steamapps/common/Grand Theft Auto IV/GTAIV/ScriptHookDotNet.dll"
  rm -rf "$HOME/.local/share/Steam/steamapps/common/Grand Theft Auto IV/GTAIV/scripts"
  ```

---

## 13. Master Guide & Solitude 3 Lifted Night Reference

- **Definitive Single Source of Truth:** The comprehensive, all-in-one technical manual covering launch options (LSFG-VK, MangoHud, vkBasalt), complete engine invariants (`ExtendedLimits=0`, `VehicleBudget=120000000`), crash postmortems, and mod compatibility is maintained at [`~/docs/gaming/gta-iv/MASTER_GUIDE.md`](file:///home/manisk/docs/gaming/gta-iv/MASTER_GUIDE.md).
- **Active Timecycle Configuration:** Solitude 3 v1.1.5 with relative mathematical ambient lift (+4% at `10PM`, +7% at `Midnight`, +4% at `5AM` on `Amb0` & `Amb1`) across all 8 gameplay weathers. SHA256: `63475d827a7e25f26e3794589d4b32f51f71faf0fc8102addf9ea4f0dad235e1`. Zero DayL values; 100% untouched daytime (06:00–21:00).

---

## 14. System & Storage Cleanup Log (Downloads & GTAIV Root Audit)

**Execution Date:** 2026-09-22 22:18 IST  
**Snapper Baseline:** Snapshot `#58` (`before-clean-gta4-and-downloads`)

### 14.1 Purged Staging Files & Archives (`~/Downloads` — Freed 14.61 GB)
Removed 62 staging archives and unpacked extraction caches; preserved all personal documents, resumes, and markdown notes:

* **Large Visual & Map Packages:**
  * `EAST FILES-781-1-31-1780890791.rar` (2.78 GB)
  * `Liberty IV REDUX pack-933-v0-08-1772037088.zip` (2.89 GB)
  * `Installation through Fusion Overloader 824 2.3 2026-09-14T13-36Z AOHlJDek.zip` (1.97 GB)
  * `Unconfirmed 910143.crdownload` (2.60 GB — incomplete browser download)
  * `IVLANE/` (1.73 GB — staging extraction folder; compiled IMG already active in `update/1 IV-LANE/`)
  * `GTAIV Trilogy Characters Fixes (Steam Version & FusionFix).rar` (791.29 MB)
  * `GTA4-DKT70 major overhaul v0.8 beta-643-0-8-1745046791.zip` (319.41 MB)
  * `GTA IV Trilogy HD Protagonists-258-1-0-1676403788.7z` (198.74 MB)
  * `playerped.rpf-394-1-5-1705943627.zip` (213.35 MB)
* **Vehicle & Character Addons:**
  * `Complete Edition Vehicle Pack-282-2-4-1776557186.zip` (139.46 MB)
  * `First Degree Grand Theft Auto Addon Pack (CE) 1025 1.2.6.7 2026-08-02T17-14Z VI32vY6V.7z` (176.67 MB)
  * `Lamborghini Huracan Libertywalk-156-1-1645763428.zip` (29.12 MB)
  * `ZR450-862-1-1766674958.zip` (1.74 MB)
* **Incompatible / Reverted Mod Archives:**
  * `Winter Pedestrians - Fusion Overloader-856-1-0-1764601157.zip` (340.50 MB)
  * `Installation through Fusion Overloader-911-2-0-1776348402.zip` (111.61 MB)
  * `PRGS 3.1 (The Reload Ricochets Update)-437-3-1-1735488201.rar` (31.93 MB)
  * `Bodyguards By MYHVN 1367 1 2026-09-05T17-32Z OESKhQyI.rar` (7.1 KB)
* **Scripts, Plugins & Overloaders (Already Deployed):**
  * `GTXD FILES-781-1-3-1780012224.rar` (57.55 MB)
  * `Liberty Rush v1.12-280-v1-12-1685890849.zip` (46.07 MB)
  * `Props Restoration-834-1-3-1779383411.zip` (36.56 MB)
  * `2k Trees and Vegetation Textures-165-E-g-1-0-1648850589.rar` (29.44 MB)
  * `Grand Theft Auto IV Silence Mod v1.2-91-v1-2-1603391849.zip` (27.17 MB)
  * `Ockky's Better Blood Pack-785-v0-5-1762037173.zip` (21.05 MB)
  * `Animated Weapons 3.0 (Fusion Overloader)-641-3-0-1753570211.7z` (18.62 MB)
  * `Animated Weapons 3.0-641-3-0-1753570259.7z` (16.93 MB)
  * `Mini Game by Jitsuin aka Cheyron-968-1-0-1773617038.zip` (14.29 MB)
  * `[FusionOverloader] Improved Animations Pack.zip` (11.93 MB)
  * `Complete Edition HD Weapons Pack-967-1-0-0-1773581258.7z` (10.34 MB)
  * `Natural Timecycle By DayL 396 1.1.9 2026-07-10T00-01Z AOHlJik8.rar` (62.68 MB)
  * `Project RevIVe.zip` (119.94 MB)
  * `Liberty Unlocked By Scott1 1358 2 2026-09-07T14-29Z vUPgLVlE.zip` (150.74 MB)
  * `Solitude 3-417-1-1-5-1777738809.rar` (4.16 MB)
  * `ProjectThunder.v2.2.1.zip` (5.44 MB)
  * `1415985091_1415911009_liberty2.rar` (2.69 MB)
  * `Various Pedestrian Actions 843 1.8 2026-06-30T12-18Z JhI5BQ15.zip` (1.11 MB)
  * `More NPCs Variety v1.0.4-819-1-0-4-1661507388.zip` & unpacked folder (1.99 MB)
  * `New Game Parameters For Transport And Traffic 616 2.3.5 2026-09-17T15-41Z Mo1Blw0Y.zip` (0.93 MB)
  * `Beaten & Bruised.zip` (0.77 MB)
  * `Correction Of Physical Parameters Of Transport 714 2.0.1 2026-09-15T17-23Z eyZNrcX4.zip` (0.75 MB)
  * `Grass And Procedural Prop Fixes 1.2 1230 1.2 2026-09-05T12-02Z UWAC0IKk.zip` (0.66 MB)
  * `Drive-By Pre-Aim V1.2 1362 1 2026-09-12T23-27Z Nshq8W2J.zip` (0.54 MB)
  * `Improved Cover System 1407 1.0 2026-09-13T21-45Z K7emdosj.zip` (0.52 MB)
  * `NoPickupGlow 1386 1.0 2026-09-08T03-05Z C9lRF6m9.zip` (0.52 MB)
  * `GTAIV_Complete_Edition_Fix_0_4.zip` (0.33 MB)
  * `1275674702GTAIVScriptHook_0_5_1_Redist.zip` (0.19 MB)
  * `FirstPersonV1.3.zip` (0.19 MB)
  * `QuickSaveIV 1.1-1119-1-1-1780254048.zip` (0.14 MB)
  * `Blood 1245 1.2 2026-08-05T00-00Z sJViaDQS.7z` (0.10 MB)
  * `SimpleDotIV.zip` (0.09 MB)
  * `DriftIV - V3-395-3-0-1735237645.rar` (0.08 MB)
  * `IVLongerLoadingScreen 1394 1 2026-09-10T11-34Z sJViaP6o.rar` (0.07 MB)
  * `ChaosIV.zip` (0.02 MB)
  * `Fidelity Popcycle - by Chunk-405-1-0-1707891511.7z` (0.02 MB)
  * `AVP-853-1-2-0-1765100126.rar` (0.01 MB)
  * `1373930578_assassination_mod.zip` (0.01 MB)
  * `14240242_LibertyCityCustomsV1.2-22-1-2.rar` (0.01 MB)
  * `1436392826_Weapon Flashlight for GTA IV.rar` (4.2 KB)
  * `Bank Robbery By MYHVN 1129 1 2026-09-07T21-37Z L0sSTv53.rar` (4.2 KB)
  * `Euphoria Action Ragdolls-364-1-1-1699632885.zip` (4.5 KB)
  * `Personal Vehicle-717-1-0-1753139691.zip` (2.8 KB)
  * `GTA V High Vehicle Camera For GTA IV V1.0 1223 1 2026-07-27T10-59Z 8aXDtPQv.zip` (1.8 KB)

### 14.2 Purged Redundant Backups in Game Directory (`GTAIV/` — Freed 2.87 GB)
* `GTAIV/backup_pre_mods_update/` (2,699.94 MB — redundant intermediate snapshot of the `update/` virtual folder)
* `GTAIV/backup_pre_4.9g_pack/` (216.24 MB — legacy intermediate folder)
* `GTAIV/backup_pre_mods_plugins/` (15.29 MB — duplicate copy of plugins)
* `GTAIV/vulkan.dll.stock` (4.25 MB — stock DXVK backup file)
* `GTAIV/Liberty's Legacy.asi.orig` (1.80 MB — unpatched original binary)

### 14.3 Btrfs Snapper Maintenance
* Pruned 48 transient trial snapshots (`#10-15`, `#17-19`, `#21-29`, `#31-48`, `#50-51`, `#54-57`).
* Retained core milestone baselines: `#8`, `#9`, `#16`, `#20`, `#30`, `#49`, `#52`, `#53`, and `#58`.

---

## 15. Btrfs NOCOW (+C) In-Place Rewrite & NVMe Optimization

**Execution Date:** 2026-09-22 23:16 IST  
**Snapper Baseline:** Snapshot `#60` (`stable-baseline-after-nocow-migration`)

### 15.1 Architecture & Problem Definition
Under default Btrfs behavior, small random writes into large pre-allocated files (e.g. GTA IV's multi-gigabyte RPF archives, `ivlane.img`, DXVK state caches, and Proton Wine registry hives `system.reg` / `user.reg`) trigger Copy-on-Write (CoW). Over time, this leads to heavy extent fragmentation (tens of thousands of scattered file fragments), write amplification, and micro-stutter during streaming across world cell boundaries.

### 15.2 In-Place Rewrite Execution
Because the `+C` attribute in Linux only applies to data blocks allocated **after** the flag is set, a true in-place rewrite using `cp -a --reflink=never` was executed:

1. **`compatdata/` (8.0 GB Proton Prefixes):**
   - Created `compatdata_nocow` with `chattr +C`.
   - Copied all prefixes via `cp -a --reflink=never`.
   - Verified zero byte difference on `12210` prefix (`diff -rq`).
   - Replaced old `compatdata/` with the NOCOW copy.
2. **`Grand Theft Auto IV/` (30 GB Game Root & Mod Stack):**
   - Created `Grand Theft Auto IV_nocow` with `chattr +C`.
   - Copied all game files, virtualized `update/` directories, and ASI plugins with `cp -a --reflink=never`.
   - Verified timecycle SHA256 integrity (`63475d827a...`).
   - Verified binary match on `plugins/` and `Liberty's Legacy/`.
   - Swapped directories and removed old CoW copy.
3. **Verified Active Attributes:**
   ```text
   lsattr -d:
   ---------------C------ ~/.local/share/Steam/steamapps/common
   ---------------C------ ~/.local/share/Steam/steamapps/compatdata
   ---------------C------ ~/.local/share/Steam/steamapps/common/Grand Theft Auto IV
   ---------------C------ ~/.local/share/Steam/steamapps/common/Grand Theft Auto IV/GTAIV/GTAIV.exe
   ---------------C------ ~/.local/share/Steam/steamapps/compatdata/12210/pfx/system.reg
   ```
4. **Storage Result:** All game files and Wine registry hives are now strictly non-fragmenting, direct overwrite-in-place. Reclaimed ~70 GB free space on `/home`.

---

## 16. Dual-Profile Architecture: Story Campaign vs. TACE.lite DLC

**Execution Date:** 2026-09-27 21:15 IST  
**Snapper Safety Baseline:** Snapshot `before-tace-lite-profile-install`  
**Save Backup Location:** `~/backups/gta4_campaign_saves_20260927/`

### 16.1 Profile 1: Current Story Campaign (Active Live Game)
- **Save Integrity:** Preserves the in-progress vanilla story campaign (`SGTA400`–`SGTA403`, `SGTA412`).
- **Vehicle Invariant:** Original `vehicles.ide` and `handling.dat` remain untouched to eliminate any risk of save corruption or mission script failures.
- **Interior Lighting Fix (Solitude 3):**
  - `update/pc/data/timecyclemodifiers.dat`:
    - `vlads`: `AmbMult0` = `8.0`, `AmbMult1` = `8.0`, `AmbDownMult` = `0.85` (restored natural illumination across bar booths and wood flooring).
    - `Internaldim`: `AmbDownMult` = `0.50`
    - `generic`: `AmbMult0/1` = `3.0`, `AmbDownMult` = `0.50`
    - `korbar`: `AmbDownMult` = `0.65`
- **vkBasalt Post-Processing:** `Vibrance` reduced to `0.20` in `Vibrance.fx` (preventing double oversaturation alongside hardware display vibrance). Hardware vibrance calibrated via `nvibrant-ctl set 55%` (or hotkeys `CapsLock + z` / `CapsLock + x`).
- **Overridden Files Mirror:** Staged at `~/gta4_mod_profiles/profile_current_story/update_overrides/`.

### 16.2 Profile 2: TACE.lite DLC (Staged in `~/gta4_mod_profiles/profile_tace_dlc/`)
- **Prerequisites & Architecture:**
  - **Radio Restoration Mod:** Fully unpacked from `Radio.Restoration.Mod.23-05-2025.rar` (`data1.dat` + `opALL.dat` audio stream archives + `RADIO_RESTORATION.rpf`).
  - **TACE Audio Configurations:** Merged `GAME.DAT16` (290,926 bytes) and `SOUNDS.DAT15` (2,114,812 bytes) from `FILES FOR RR_SETTINGS_01`.
  - **TACE Core Overloader Assets:** Deployed `9X.TACE.Lite/` (121 MB) with unified episodic vehicles (`A.Vehicles.img`), weapons (`B.Weapons.img`), and maps (`D.Map.img`).
  - **LibertyCityPlates Integration:** Deployed `2A.LibertyCityPlates/` (97 MB) specifically compiled for TACE.Lite with custom plate shaders.
  - **Vehicle Definitions:** `vehicles.ide` and `handling.dat` populated with all DLC cars (`buffalo`, `bullet`, `hexer`, `avan`, `caddy`, etc.).
  - **Save Invariant:** Requires starting a **New Game** or loading a TACE CE 1.2.0.59 starter save. Never load an existing vanilla campaign save with Profile 2 active.

---

## 17. Frametime Pacing & Micro-Stutter (Jitter) Elimination

**Execution Date:** 2026-10-24 05:15 IST  
**Verified In-Game Metric:** Flat 11.3ms frametime line at 85-90 FPS in live 3D gameplay (driving Dukes in Alderney City).

### 17.1 Root Causes of Frametime Jitter
1. **Synchronous Disk I/O Trace (`PROTON_LOG=1`):** Tracing wine debug messages, exception handling, and thread scheduling directly to disk generated 36 MB of log data in minutes, stalling the CPU render thread during asset streaming.
2. **Disabled Vulkan GPL (`dxvk.enableGraphicsPipelineLibrary = false`):** Setting this to false in `dxvk.conf` prevented DXVK from using fast Vulkan Graphics Pipeline Library compilation, forcing synchronous monolithic shader compilation stutters when new models or shaders were encountered.
3. **LSFG-VK Swapchain & Pacing Conflict:** `preserve_swapchain_image_count = false` caused swapchain recreation loops (`VK_SUBOPTIMAL_KHR` / `Device reset`). Furthermore, running neural frame generation on an already saturated GPU (84W TGP) dropped base framerate to ~48 FPS, and forcing `pacing_mode = "vsync"` against a 165Hz screen produced severe pacing judder.
4. **FusionFix Frame Limit Preset:** `FpsLimitPreset = 9` in `GTAIV.EFLC.FusionFix.cfg` conflicted with DXVK presentation settings.

### 17.2 Permanent Fixes
1. **Purged `PROTON_LOG=1` and Added MangoHud Xwayland Invariant (`read_cfg`):**
   - In MangoHud's global configuration, `vsync=0` requests Adaptive VSync (`VK_PRESENT_MODE_FIFO_RELAXED_KHR`), which is unsupported on NVIDIA Xwayland under Sway (`Present mode is not supported: VK_PRESENT_MODE_FIFO_RELAXED_KHR`). Combined with uncapped presentation (`d3d9.presentInterval = 0`), this triggered DXVK device loss (`D3DERR_DEVICELOST`) and a spinlock hang on launch.
   - Setting `MANGOHUD_CONFIG="read_cfg,no_display=0,vsync=3,fps_limit=165"` ensures MangoHud loads `~/.config/MangoHud/MangoHud.conf` (compact horizontal layout, colors, temperatures, wattage, RAM/VRAM, and `pci_dev=0000:01:00.0`) while enforcing Immediate present mode (`VK_PRESENT_MODE_IMMEDIATE_KHR`), displaying on launch, and capping render rate at 165 FPS.
   - Steam AppID 12210 `LaunchOptions`: `DISABLE_LSFGVK=1 MANGOHUD_CONFIG="read_cfg,no_display=0,vsync=3,fps_limit=165" WINEDLLOVERRIDES="dinput8=n,b" ENABLE_VKBASALT=1 prime-run mangohud %command%`.
   - Dedicated fallback config also staged at `~/.config/MangoHud/GTAIV.exe.conf` and `wine-GTAIV.conf`.
2. **Re-enabled Vulkan Graphics Pipeline Library in `GTAIV/dxvk.conf`:**
   - `dxvk.enableGraphicsPipelineLibrary = true`
   - `dxvk.numCompilerThreads = 8`
   - `d3d9.maxFrameLatency = 1`
   - `d3d9.presentInterval = 0`
   - `d3d9.maxFrameRate = 0`
3. **Restored FusionFix Uncapped Preset:**
   - `FpsLimitPreset = 0` in `plugins/GTAIV.EFLC.FusionFix.cfg`.
4. **LSFG-VK Invariant (If Enabled):**
   - In `~/.config/lsfg-vk/conf.toml`, `preserve_swapchain_image_count = true` must be set for the `GTAIV.exe` profile to prevent swapchain recreation loops.
   - For optimal frametime delivery and lowest input latency, native rendering at 85-90 FPS without frame generation is strongly recommended over 2x interpolation.
