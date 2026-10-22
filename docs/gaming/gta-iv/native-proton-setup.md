# Grand Theft Auto IV: Complete Edition — Definitive Linux/Proton Guide
*A Gillian-style, verified modding guide tailored for CachyOS, Optimus Hybrid (Intel + RTX 5050 Mobile), and 16:10 165Hz Displays.*

**Target Hardware:** ASUS TUF Gaming F16 (Intel i5-13450HX + NVIDIA GeForce RTX 5050 Mobile 8GB GDDR7, `sm_120`)  
**OS / Desktop:** CachyOS rolling (`x86-64-v3`, BORE/EEVDF Kernel) · Sway (Wayland) / i3wm (X11)  
**Target Display:** 1920x1200 @ 165Hz Native (16:10 Aspect Ratio)  
**Game Version:** GTA IV Complete Edition v1.2.0.59 (Steam AppID `12210`)  
**Filesystem:** Native Linux Btrfs on NVMe (Strictly **NO NTFS**)

---

## 1. Prerequisites & Base System Setup

### Storage & Filesystem Invariant
The game library and Proton compatdata prefix must reside on a native Linux filesystem (`btrfs` or `ext4`). **Never run or mod GTA IV on an NTFS partition**—NTFS under Wine causes case-insensitivity file collisions, broken symlinks, and prefix lockups.

* **Game Root:** `~/.local/share/Steam/steamapps/common/Grand Theft Auto IV/GTAIV/`
* **Proton Prefix:** `~/.local/share/Steam/steamapps/compatdata/12210/pfx/`
* **Save Games:** `.../pfx/drive_c/users/steamuser/Documents/Rockstar Games/GTA IV/Profiles/`

### Step 1: Steam & Proton Compatibility
1. In Steam Game Properties $\rightarrow$ **Compatibility**, force:  
   **GE-Proton11-7** (or latest GE-Proton / Proton Experimental).  
   *Why: Bypasses the Rockstar Games Launcher Chromium CEF timeout crash present in older Wine builds.*
2. Launch the game once cleanly to allow Steam to generate the prefix and finish the Rockstar Launcher initialization.
3. Disable **Steam In-Game Overlay** (prevents Wayland/X11 CEF input deadlocks).

### Step 2: Steam Launch Options
Set the following launch options in Steam:
```bash
WINEDLLOVERRIDES="dinput8=n,b" LSFGVK_PROFILE="gta4" prime-run mangohud %command%
```
* `WINEDLLOVERRIDES="dinput8=n,b"`: Directs Wine to load the local Ultimate ASI Loader DLL instead of the dummy Wine library.
* `LSFGVK_PROFILE="gta4"`: Hooks 32-bit Vulkan Lossless Scaling frame generation (`aur/lib32-lsfg-vk`).
* `prime-run`: Offloads rendering strictly to the dedicated RTX 5050 Mobile GPU.
* `mangohud`: Real-time telemetry overlay.

### Step 3: DirectX 9 Runtime Prerequisite
Install the native 32-bit DirectX 9 runtime into the prefix:
```bash
protontricks 12210 -q d3dx9_43
```

---

## 2. Essential Foundation Mods (What Works)

Only native C++ and modern Complete Edition bridges are compatible. Every component in this foundation has been verified 100% stable on build 1.2.0.59:

| Mod | Version | Download Link | Purpose & Placement |
| :--- | :--- | :--- | :--- |
| **FusionFix** | **v5.0.1** | [GitHub Releases](https://github.com/ThirteenAG/GTAIV-FusionFix/releases) | **Core Engine Foundation.** Bundles Ultimate ASI Loader (`dinput8.dll`), DXVK Vulkan layer (`d3d9.dll`, `vulkan.dll`), console shaders, 16:10 HUD scale, and virtual archive loader. Extract directly into `GTAIV/`. |
| **Aru's ScriptHook** | **v0.5.1 (336 KB)** | [HazardX GitHub](https://github.com/HazardX/gta4_scripthookdotnet/releases/tag/v1.7.1.7b) | **Native Script Engine.** Pure C++ `ScriptHook.dll`. Copy *only* `ScriptHook.dll` into `GTAIV/`. *(Do not use the 1.0.8.0 modified build).* |
| **ScriptHook CE Patch** | **v0.4** | [LCPDFR Releases](https://www.lcpdfr.com/downloads/gta4mods/g17media/26726-compatibility-patch-for-gta-iv-complete-edition/) | **CE Compatibility Bridge.** Bridges Aru's ScriptHook to CE 1.2.0.59. Copy *only* `aCompleteEditionHook.asi` into `GTAIV/`. |
| **Liberty's Legacy Trainer** | **v2.4.1** | [Nexus Mods #100](https://www.nexusmods.com/gta4/mods/100) | **Native Mod Menu.** Copy `Liberty's Legacy.asi` and `Liberty's Legacy/` into `GTAIV/`. Full 60% keyboard layout support. |

### Liberty's Legacy Configuration (60% Keyboard & Controller)
In [`GTAIV/Liberty's Legacy/Liberty's Legacy.ini`](file:///home/onyx/.local/share/Steam/steamapps/common/Grand%20Theft%20Auto%20IV/GTAIV/Liberty's%20Legacy/Liberty's%20Legacy.ini):
```ini
[config]
Trainer key = F11
Navigation mode = 2    # Enables 60% keyboard layout (I/K/J/L/U/O)

[Settings]
Controller binding = 0 # 0 = RB + X (Default open combination)

[Backend]
Trainer Init = true    # Permanently bypasses introductory splash
```

#### Controls Reference:
* **Keyboard (60% Mode):**
  * Open / Close: `F11`
  * Navigation: `I` (Up), `K` (Down), `J` (Left), `L` (Right)
  * Accept / Select: `U`
  * Go Back: `O`
* **Controller (Default Mode):**
  * Open / Close: `RB + X` (Xbox) / `R1 + Square` (PlayStation)
  * Navigation: `D-Pad` (`Up`, `Down`, `Left`, `Right`)
  * Accept / Select: `A` (Xbox) / `Cross` (PlayStation)
  * Go Back / Exit: `B` (Xbox) / `Circle` (PlayStation)

---

### Controller D-Pad Up / Mobile Phone Conflict & Fixes

#### The Problem & Root Cause
In vanilla *Grand Theft Auto IV*, **D-Pad Up** is hardcoded at the engine level into the player character control routine (`CPlayerPed::ProcessInput`) to draw Niko's cell phone.

When running Liberty's Legacy on Linux/Proton with `aCompleteEditionHook.asi`, the script hook listens for gamepad input to navigate menu items. However, Wine/Proton's DirectInput/XInput layer simultaneously passes the raw `DPAD_UP` press to the native game engine.

**Symptom:** The moment you press `D-Pad Up` to navigate up in the mod menu, Niko draws his mobile phone in the bottom-right corner. The phone's interface captures button presses, making menu navigation difficult or triggering accidental phone calls and beeps.

#### Actionable Solutions

##### Solution 1: Advanced Navigation Modifier (`RB + D-Pad`) — Recommended In-Game
Liberty's Legacy includes built-in fast navigation that inherently suppresses the game's phone trigger:
* **Hold `RB` (or `R1`)** while using the D-Pad:
  * `RB + D-Pad Up`: Jumps immediately to the **very top** item of any submenu.
  * `RB + D-Pad Down`: Jumps immediately to the **very bottom** item.
  * `RB + D-Pad Left / Right`: Skips **10 items** forward or backward.
* *Why this fixes it:* Because `RB` is recognized by GTA IV as targeting/handbrake, the engine will NOT trigger the standalone cell phone action while `RB` is held down.

##### Solution 2: Steam Input Action Layer / Mode Shift — Permanent Hardware-Level Fix
If you want clean single-step D-Pad Up navigation without ever touching the phone, use Steam's native controller configurator to route navigation as keyboard commands:
1. In Steam, right-click **Grand Theft Auto IV** $\rightarrow$ **Manage** $\rightarrow$ **Controller Layout** $\rightarrow$ **Edit Layout**.
2. Go to **D-Pad** and create a **Mode Shift** (or Action Layer) activated while holding a grip button (e.g. `L4`/`R4`), `LB`, or `Select`:
   * Set D-Pad Up $\rightarrow$ **Keyboard `I`** (or Up Arrow)
   * Set D-Pad Down $\rightarrow$ **Keyboard `K`** (or Down Arrow)
   * Set D-Pad Left $\rightarrow$ **Keyboard `J`** (or Left Arrow)
   * Set D-Pad Right $\rightarrow$ **Keyboard `L`** (or Right Arrow)
   * Set `A` $\rightarrow$ **Keyboard `U`** (or Enter)
   * Set `B` $\rightarrow$ **Keyboard `O`** (or Backspace)
3. *Why this fixes it:* When activated, the game engine receives *keyboard navigation* which Liberty's Legacy processes natively, while GTA IV's controller loop receives zero `DPAD_UP` events, completely preventing the phone from ever appearing.

##### Solution 3: Downward Navigation Workflow
* In GTA IV, **only `D-Pad Up` pulls out the phone**; `D-Pad Down` does not pull out the phone (it only skips dialogue or lowers an active call).
* By entering any menu and pressing `D-Pad Down`, you can scroll cleanly through all options. The list wraps around from the bottom to the top automatically without triggering the phone.

##### Solution 4: Quick Dismiss (`B` / Circle)
* If the phone is pulled out accidentally, press **`B`** (Xbox) / **`Circle`** (PlayStation) once to put it down. If you are already inside a submenu, `B` will close the phone while keeping you in the menu.

##### Solution 5: Changing the Controller Menu Open Keybind
You can rebind the button combination used to toggle Liberty's Legacy open/close:
1. In `GTAIV/Liberty's Legacy/Liberty's Legacy.ini`, change line 136:
   ```ini
   Controller binding = 8    # Changes open key to LB + RB
   ```
2. **Supported Binding Indices:**
   * `0` = `RB + X` (**Active / Recommended for Linux/Proton**) — *Note: Setting `8` (`LB + RB`) fails to register reliably on Proton XInput gamepads because simultaneous bumper triggers are often consumed by camera/weapon cycles before ScriptHook polls them. Keep at `0` (`RB + X`).*
   * `1` = `RB + A`
   * `2` = `RB + Y`
   * `3` = `RB + D-Pad Down`
   * `4` = `LB + X`
   * `5` = `LB + A`
   * `6` = `LB + Y`
   * `7` = `LB + D-Pad Down`
   * `8` = `LB + RB`
3. Alternatively, rebind live in-game: open the trainer $\rightarrow$ **Settings** $\rightarrow$ **Controller Binding** $\rightarrow$ cycle with Left/Right $\rightarrow$ press `A` to save.

---

## 3. Visual & World Enhancements (Gillian's Modpack)

The following modules from Gillian's Modpack ([`1.2 archive.7z`](file:///home/onyx/Downloads/1.2%20archive.7z)) are installed non-destructively into [`GTAIV/update/`](file:///home/onyx/.local/share/Steam/steamapps/common/Grand%20Theft%20Auto%20IV/GTAIV/update/) via Fusion Overloader (totaling **1.9 GB**):

| Folder / Module | Uncompressed Size | Visual Improvements |
| :--- | :--- | :--- |
| **`update/1 Minor Mods`** | 39 MB | Restores Beta Bank of Liberty textures, minor clothing props, and outfit bug fixes. |
| **`update/2 Potential Grim`** | 43 MB | Restores gritty atmosphere, authentic color grading, and console weather balance. |
| **`update/3a Props Restoration`** | 9 MB | Restores console-exclusive newspaper stands, phone booths, and vending machines. |
| **`update/3b Restored Vegetation`** | 1.3 MB | Restores console foliage, bushes, and tree wind-sway animations. |
| **`update/3c Restored Graffiti`** | 220 MB | Restores console street decals and graffiti artwork across all boroughs. |
| **`update/4a Pedestrian Actions`** | 0.5 MB | Enhances civilian reactions, gestures, and interaction animations. |
| **`update/4b Restored Pedestrians`** | 133 MB | Restores unused pedestrian clothing variations and models. |
| **`update/5 High-Res Misc Pack`** | 383 MB | High-resolution textures for world signage, storefronts, and prop details. |
| **`update/7 Characters Fixes`** | 410 MB | Fixes character mesh seams, hands, hair clipping, and Niko's jacket/gloves. |
| **`update/8 Console Visuals`** | 132 MB | Restores console lighting, fence alpha textures, and pedestrian animation models. |
| **`update/9 Project Glass`** | 286 MB | Realistic glass reflections, specular highlights, and bus-stop glass shaders. |
| **`update/10 Visible Interiors`** | 153 MB | Cleans reflective glass so building/diner interiors render from the street. |
| **`update/Various Fixes/VariousFixes.img`** | 818 MB | Core map geometry, collision mesh repairs, and missing texture bug fixes. |
| **`update/pc/data/maps/jersey/`** | 2.4 GB | **HQ Vanilla Textures City Revitalization (Jersey Files v1.3).** AI-upscaled Alderney map geometry and road decals. |
| **`update/pc/models/cdimages/vehicles.img`** | 89.5 MB | **HQ Metallic Car Paint Tires and Details by The Wil.** Enhanced vehicle shaders, high-definition tire treads, and metallic flake reflections. |
| **Solitude 3 Timecycle & Volumetric Lights** | ~5.6 MB | **Solitude 3 by Chunk + Volumetric Lights v2.0 by RecklessGlue540.** Photorealistic atmosphere, volumetric fog shafts, custom tonemapping, and dynamic weather lighting. |

---

### Master Mod Installation & Crash Mitigation Guide (All Active Mods)

This reference defines exactly where each file belongs, required configuration parameters, and the targeted remedy if an issue or crash occurs.

#### 1. FusionFix v5.0.1 (Engine, Memory & Shaders)
* **Dependencies:**
  * Ultimate ASI Loader (`dinput8.dll`)
  * Vulkan layer (`d3d9.dll`, `vulkan.dll`)
  * Native DirectX 9 runtime in Wine prefix (`protontricks 12210 -q d3dx9_43`)
* **Files to put:**
  * Root `GTAIV/`: `dinput8.dll`, `d3d9.dll`
  * `GTAIV/plugins/`: `GTAIV.EFLC.FusionFix.asi`, `GTAIV.EFLC.FusionFix.ini`, `GTAIV.EFLC.FusionFix.cfg`
  * `GTAIV/update/`: Fusion virtual file hierarchy
* **Required settings:**
  * In Steam Launch Options: `WINEDLLOVERRIDES="dinput8=n,b"`
  * In `GTAIV/plugins/GTAIV.EFLC.FusionFix.ini`: `VehicleBudget = 144000000`, `ExtendedLimits = 0`
  * In `GTAIV/plugins/GTAIV.EFLC.FusionFix.cfg`: `FpsLimitPreset = 0`
* **If a crash occurs:**
  * *Symptom: Game fails to launch or closes with no error.* Verify Steam launch option includes `dinput8=n,b`.
  * *Symptom: Freeze on loading screen (e.g. Off Route mission).* In `FusionFix.ini`, set `LoadingFpsLimit = 30`.

#### 2. Aru's ScriptHook + aCompleteEditionHook.asi (Script Engine Bridge)
* **Dependencies:**
  * Ultimate ASI Loader (`dinput8.dll`)
  * C++ Runtime DLLs (built into Wine / GE-Proton)
  * GTA IV Complete Edition 1.2.0.59 runtime
* **Files to put:**
  * Root `GTAIV/`: `ScriptHook.dll` (v0.5.1, 336 KB — HazardX build)
  * Root `GTAIV/`: `aCompleteEditionHook.asi` (20 KB — LCPDFR build)
* **Required settings:**
  * Strictly **do NOT** install `AdvancedHook.dll` or `AdvancedHookInit.asi` (causes memory offset corruption on CE 1.2.0.59).
* **If a crash occurs:**
  * *Symptom: Instant CTD on boot.* Check `scripthook.log` in `GTAIV/`. If log reports memory signature failure, ensure `aCompleteEditionHook.asi` is placed in `GTAIV/` root so it loads before all other ASI scripts.

#### 3. Liberty's Legacy Trainer v2.4.1 (Mod Menu)
* **Dependencies:**
  * Aru's `ScriptHook.dll`
  * `aCompleteEditionHook.asi` (CE memory hook bridge)
  * `Liberty's Legacy/` configuration folder
* **Files to put:**
  * Root `GTAIV/`: `Liberty's Legacy.asi` (1.88 MB)
  * Folder `GTAIV/`: `Liberty's Legacy/` (contains `Liberty's Legacy.ini`, `Hotkeys.ini`, `Themes/`)
* **Required settings:**
  * In `Liberty's Legacy/Liberty's Legacy.ini`:
    * `Navigation mode = 2` (Enables 60% keyboard layout: `I`/`K`/`J`/`L`/`U`/`O`)
    * `Controller binding = 0` (Enables `RB + X` / `R1 + Square` activation)
    * `Trainer Init = true` (Bypasses introductory splash screen)
* **If an issue occurs:**
  * *Symptom: Mod menu does not open on controller.* Ensure `Controller binding = 0`. Simultaneous bumper bindings like `8` (`LB + RB`) are often eaten by Proton XInput before ScriptHook polls them. Revert to `0` or press `F11` on keyboard.
  * *Symptom: D-Pad Up draws phone.* Use `RB + D-Pad Up` (Advanced Navigation) to jump to top without triggering phone, or scroll down with `D-Pad Down`.

#### 4. DXVK 2.6.2 GPLAsync & Pre-Compiled Shader Cache (Vulkan Driver)
* **Dependencies:**
  * NVIDIA Vulkan 1.3 driver (`sm_120` RTX 5050 Mobile)
  * 32-bit Vulkan loader (`vulkan.dll`)
  * `dxvk.conf` in root `GTAIV/`
* **Files to put:**
  * Root `GTAIV/`: `vulkan.dll` (4.46 MB — Ph42oN/ValentynL GPLAsync build)
  * Root `GTAIV/`: `GTAIV.dxvk-cache` (99 KB — Pre-compiled Vulkan pipeline cache)
  * Root `GTAIV/`: `dxvk.conf`
* **Required settings:**
  * In `dxvk.conf`: `dxvk.enableAsync = true`, `dxvk.gplAsyncCache = true`, `dxvk.numAsyncThreads = 8`, `d3d9.presentInterval = 0`, `d3d9.maxFrameRate = 0`, `dxvk.tearFree = True`.
* **If a crash occurs:**
  * *Symptom: Vulkan device loss or crash on launch.* Restore stock DXVK: `cp vulkan.dll.stock vulkan.dll` and remove `GTAIV.dxvk-cache`.

#### 5. Gillian's Visual Modules (1.9 GB Asset Enhancements)
* **Dependencies:**
  * FusionFix v5.0.1 OverLoader (`update/` virtual file mounting system)
* **Files to put:**
  * In `GTAIV/update/`: Folders `1 Minor Mods`, `2 Potential Grim`, `3a Props`, `3b Veg`, `3c Graffiti`, `4a/b Peds`, `5 HiRes Misc`, `7 Characters`, `8 Console Visuals`, `9 Project Glass`, `10 Visible Interiors`, and `Various Fixes/VariousFixes.img`.
* **Required settings:**
  * Strictly exclude `IVWPL.img` and `6b Vehicle Mods`.
* **If a crash occurs:**
  * *Symptom: Infinite load or crash near certain city blocks.* Delete `GTAIV/update/Various Fixes/` or remove the offending subfolder in `update/`.

#### 6. HQ Vanilla Textures City Revitalization - Jersey Files v1.3 (2.4 GB)
* **Dependencies:**
  * FusionFix v5.0.1 OverLoader (`update/pc/data/maps/jersey/`)
  * Minimum 6 GB VRAM GPU (system has 8 GB GDDR7)
* **Files to put:**
  * In `GTAIV/update/pc/data/maps/jersey/`: 9 archives (`nj_01.img`, `nj_02.img`, `nj_03.img`, `nj_04e.img`, `nj_04w.img`, `nj_05.img`, `nj_docks.img`, `nj_liberty.img`, `nj_xref.img`).
* **Required settings:**
  * Handled 100% dynamically by Fusion OverLoader; no game files are overwritten.
* **If a crash occurs:**
  * *Symptom: Alderney map streaming stutter or out-of-memory crash.* Delete `GTAIV/update/pc/data/maps/jersey/` to immediately fall back to vanilla Jersey textures.

#### 7. HQ Metallic Car Paint Tires and Details by The Wil (89.5 MB)
* **Dependencies:**
  * FusionFix v5.0.1 OverLoader (`update/pc/models/cdimages/vehicles.img`)
  * `VehicleBudget = 144000000` (144 MB) in `GTAIV.EFLC.FusionFix.ini`
* **Files to put:**
  * In `GTAIV/update/pc/models/cdimages/`: `vehicles.img`
* **Required settings:**
  * Ensure `VehicleBudget = 144000000` is set in `GTAIV.EFLC.FusionFix.ini`.
* **If a crash occurs:**
  * *Symptom: Taxi bug (only taxis spawning) or model load freeze.* Delete `GTAIV/update/pc/models/cdimages/vehicles.img`.

#### 8. Natural Timecycle By DayL v1.1.9 (~65 MB)
* **Status:** **Installed & Active**
* **Source:** [Nexus Mods #396: Natural Timecycle By DayL](https://www.nexusmods.com/gta4/mods/396)
* **Dependencies:**
  * FusionFix v5.0.1 OverLoader
  * Native Tonemapper (`ToneMapping = 1`, `Bloom = 1`, `ScreenFilter = 5` in `GTAIV.EFLC.FusionFix.cfg`)
* **Files Location:**
  * `GTAIV/update/common/data/visualSettings.dat`
  * `GTAIV/update/pc/data/timecyc.dat`, `timecycext.dat`, `timecyclemodifiers*.dat`, `halloween*.dat`, `snow*.dat`
  * `GTAIV/update/pc/data/effects/` (`gtarainemitter.xml`, `gtaRainRender.xml`, `gtaStormEmitter.xml`, `gtaStormRender.xml`)
  * `GTAIV/update/pc/textures/` (`coronas.wtd`, `lights_occluders.wtd`, `skydome.wtd`, `stipple.wtd`)
  * `GTAIV/update/TBoGT/` and `GTAIV/update/TLAD/` episode timecycles
* **Required settings:**
  * In `GTAIV/plugins/GTAIV.EFLC.FusionFix.ini`: `SunShaftsDensity = 0.9`, `SunShaftsDecay = 0.95`
  * In `GTAIV/plugins/GTAIV.EFLC.FusionFix.cfg`: `Bloom = 1`, `ToneMapping = 1`, `VolumetricFog = 1`, `SunShafts = 1`, `ConsoleGamma = 0`
* **Features:**
  * Natural, vibrant, authentic New York lighting without the dark/grey gloom of vanilla or the overhead of ENB/ReShade.
  * Native Vulkan performance with zero microstutters on DXVK GPLAsync.
* **If a crash occurs:**
  * Delete `GTAIV/update/pc/data/timecyc.dat` to fall back to FusionFix stock timecycles.

#### 9. Improved Animations Pack (B Dawg / GTAForums #958625)
* **Status:** **Pre-Integrated & Active via Gillian's Modpack**
* **Source:** [GTAForums Topic #958625](https://gtaforums.com/topic/958625-improved-animations-pack/)
* **Files Location:**
  * `update/1 Minor Mods/IV/IAP.IV.img` (3.1 MB)
  * `update/1 Minor Mods/TBoGT/IAP.TBoGT.img` (2.8 MB)
  * `update/1 Minor Mods/TLAD/IAP.TLAD.img` (3.0 MB)
* **Features Included:**
  * Restores console animations for the Assault Rifle (no firing delay).
  * Equalized player & AI rate of fire (removes unfair AI fire rate advantage).
  * Faster drive-by rate of fire.
  * Proper reload animations for Assault Rifles & Street Sweeper.
  * Fixed SMG crouch reload missing sounds.
* **Installation Note:** No action needed. Gillian already optimized and packaged IAP into `update/1 Minor Mods/`. Adding external loose `.ifp` or overwriting `anim.img` will cause file corruption and is strictly unnecessary.

#### 10. Xbox Rain Droplets (Nexus #298 / ThirteenAG)
* **Status:** **VERIFIED WORKING & ACTIVE (Confirmed In-Game)**
* **Source:** [Nexus Mods #298: GTAIV.XboxRainDroplets](https://www.nexusmods.com/gta4/mods/298)
* **Files Location:**
  * `GTAIV/plugins/GTAIV.XboxRainDroplets.asi` (877 KB)
  * `GTAIV/plugins/GTAIV.XboxRainDroplets.ini`
* **Features Included:**
  * Restores Xbox 360-exclusive dynamic rain droplets condensing and streaking across vehicle windshields and third-person camera.
  * Fully reactive to vehicle velocity, gravity, and wiper sweeps.
* **Proton/Vulkan Verification:**
  * Hooks directly into the DXVK D3D9-to-Vulkan pipeline via FusionFix's ASI loader.
  * Confirmed 100% stable at 165Hz with zero rendering artifacts or memory leaks.
* **Configuration:**
  * Default parameters in `GTAIV.XboxRainDroplets.ini` (`MaxDrops = 3000`, `MaxMovingDrops = 6000`, `EnableGravity = 1`).
* **If an issue occurs:**
  * If Vulkan frametime dips occur during heavy thunderstorms, delete `GTAIV/plugins/GTAIV.XboxRainDroplets.asi`.

#### 11. LibertyCityPlates v1.2.6.4b (Nexus #875 / CP, Shvab, Ash)
* **Status:** **VERIFIED INSTALLED & ACTIVE**
* **Source:** [Nexus Mods #875: LibertyCityPlates](https://www.nexusmods.com/gta4/mods/875)
* **Dependencies:**
  * Ultimate ASI Loader (`dinput8.dll`)
  * FusionFix v5.0.1 (OverLoader virtual directory)
  * Complete Edition 1.2.0.59 runtime
* **Files to put:**
  * `GTAIV/plugins/LibertyCityPlates.asi` (124 KB)
  * `GTAIV/plugins/LibertyCityPlates.txt`
  * `GTAIV/update/CP,Shvab,Ash_GTAIV.EFLC.CityPlates/` (Plate texture archives: 70 MB IV, 23 MB TBOGT, 18 MB TLAD)
  * `GTAIV/update/common/shaders/win32_30/` (`gta_vehicle_licenseplate.fxc`, `gta_vehicle_licenseplate_normal.fxc`)
  * `GTAIV/update/common/data/` (`handling.dat`, `vehicles.ide` license plate vehicle configs)
* **Required settings:**
  * Placed inside `GTAIV/plugins/` and `GTAIV/update/` — loaded dynamically by FusionFix OverLoader without overwriting base game archives.
  * License plate distribution and styles configured via `GTAIV/plugins/LibertyCityPlates.txt`.
* **Features Included:**
  * Dynamic, randomized authentic state license plates across Liberty City, Alderney, and EFLC episodes.
  * Era-accurate fonts, colors, registration stickers, and lighting bump maps.
* **If a crash occurs:**
  * *Symptom: Purple textures on license plates or D3D9/Vulkan crash when vehicles spawn.* Delete custom shaders in `update/common/shaders/win32_30/` or remove `GTAIV/plugins/LibertyCityPlates.asi` and `GTAIV/update/CP,Shvab,Ash_GTAIV.EFLC.CityPlates/`.

#### 12. HQ Map Color V (Nexus #358)
* **Status:** **REMOVED (Minimap Ring Alpha Artifacts)**
* **Source:** [Nexus Mods #358: HQ Map Color V](https://www.nexusmods.com/gta4/mods/358)
* **Reason for Removal:**
  * Tested live on Complete Edition 1.2.0.59 + DXVK. The custom `radar.img` causes a corrupted white border and alpha-clipping artifacts around the circular HUD minimap on modern 16:10 resolutions.
  * Completely uninstalled by removing `update/HQ Map Color V/` and deleting `frontend*.wtd` from `update/` to restore clean vanilla HUD radar presentation.

#### 13. Various Pedestrian Actions v1.8 (Nexus #843)
* **Status:** **VERIFIED INSTALLED & ACTIVE**
* **Source:** [Nexus Mods #843: Various Pedestrian Actions](https://www.nexusmods.com/gta4/mods/843)
* **Dependencies:**
  * FusionFix v5.0.1 OverLoader
  * Aru's ScriptHook / native engine data loader
* **Files to put:**
  * `GTAIV/update/4a Various Pedestrian Actions/VPA.img` (330 KB animation archive)
  * `GTAIV/update/common/data/Ambient.dat` (Pedestrian ambient spawn behaviors)
  * `GTAIV/update/common/data/default.ide` (Pedestrian model animation assignment flags)
* **Required settings:**
  * Replaces Gillian's basic 4a pedestrian actions with official 1.8 build while keeping files strictly inside `GTAIV/update/` (preserving vanilla data untouched).
* **Features Included:**
  * Pedestrians exhibit much broader realistic behaviors: smoking, checking phones, sitting on curbs, leaning against walls, drinking, taking photos, conversing with reactive body language.
* **If a crash occurs:**
  * *Symptom: Crash when walking into busy civilian sidewalks (Star Junction, broker beach) or T-posing pedestrians.* Delete `GTAIV/update/4a Various Pedestrian Actions/VPA.img` and remove `Ambient.dat` and `default.ide` from `GTAIV/update/common/data/`.

#### 14. DriftIV v3.0 (AWD - Default V3)
* **Status:** **VERIFIED INSTALLED & ACTIVE**
* **Source:** [Nexus Mods #395: DriftIV](https://www.nexusmods.com/gta4/mods/395)
* **Dependencies:**
  * FusionFix v5.0.1 (OverLoader virtual directory)
* **Files Placed:**
  * `GTAIV/update/common/data/handling.dat` (AWD - Default V3 with merged LibertyCityPlates license plate flags)
  * `GTAIV/update/TBoGT/common/data/handling.dat`
  * `GTAIV/update/TLAD/common/data/handling.dat`
* **Features Included:**
  * Realistic drift physics with classic IV weight and suspension feedback.
  * AWD-Default preset: 50–55 degree steering angles, refined torque split, and progressive power delivery designed specifically for gamepad/controller driving.
  * Retains LibertyCityPlates commercial vehicle tags (`BENSON`, `BIFF`, `BUS`, `FLATBED`).
* **If an issue occurs:**
  * *Symptom: Vehicle handling feels too slippery or loose.* Delete `GTAIV/update/common/data/handling.dat` (and episode handling files) to instantly restore vanilla vehicle physics.

#### 15. The Assassination Mod v1.0 (TaazR / odiomoratti)
* **Status:** **INSTALLED & ACTIVE (Testing)**
* **Source:** [GTAGaming: Assassination Mod v1.0](https://www.gtagaming.com/assassination-mod-v1-0-f22942.html)
* **Dependencies:**
  * Pure C++ `ScriptHook.dll` (Aru)
  * `aCompleteEditionHook.asi` (CE compatibility bridge)
  * `ScriptHookDotNet.asi` (HazardX v1.7.1.7b CLR bridge)
  * `ScriptHookDotNet.dll` (HazardX managed wrapper)
* **Files Placed:**
  * `GTAIV/ScriptHookDotNet.asi` (649 KB root plugin)
  * `GTAIV/ScriptHookDotNet.dll` (Root and `scripts/` directory)
  * `GTAIV/scripts/Ass.net.dll` (43 KB managed contract script)
* **Controls & Features:**
  * **Trigger Hit:** Walk up to any payphone and press **`E`**, or visit the contact in Middle Park (near the public restrooms).
  * **Procedural Contracts:** Random target assignments across Liberty City with special weapon, outfit, and vehicle requirements. Standard payouts: $7,500 – $15,000.
  * **Assassin Gear:** Press **`K`** while inside any vehicle to toggle Niko's balaclava and fingerless gloves.
* **If a crash occurs:**
  * *Symptom: Boot crash or `EXCEPTION_ACCESS_VIOLATION` during initialization.* Delete `GTAIV/ScriptHookDotNet.asi` and remove the `GTAIV/scripts/` folder.

---

## 4. Performance & 165Hz Framerate Uncap

To run GTA IV at a fluid 165Hz / 165 FPS on native Linux without the common 75Hz / 150 FPS ceiling:

### File 1: `commandline.txt`
Create [`GTAIV/commandline.txt`](file:///home/onyx/.local/share/Steam/steamapps/common/Grand%20Theft%20Auto%20IV/GTAIV/commandline.txt):
```text
-width 1920
-height 1200
-refreshrate 165
-frameLimit 0
-novblank
-nomemrestrict
-norestrictions
-noprecache
```

### File 2: DXVK 2.6.2 GPLAsync & Pre-Compiled Shader Cache
To eliminate Vulkan shader compilation microstutters and remove the 75Hz presentation clamping, install the custom GPLAsync runtime from [Nexus Mods #385](https://www.nexusmods.com/gta4/mods/385):
* **`vulkan.dll`:** Drop into `GTAIV/` (replaces stock DXVK DLL).
* **`GTAIV.dxvk-cache`:** Drop into `GTAIV/` (contains 99 KB of pre-compiled Vulkan pipeline states for FusionFix 5.0).

Configure [`GTAIV/dxvk.conf`](file:///home/onyx/.local/share/Steam/steamapps/common/Grand%20Theft%20Auto%20IV/GTAIV/dxvk.conf):
```ini
# DXVK 2.6.2 GPLAsync & Uncap Configuration for GTA IV Complete Edition
# Author: ValentynL / Ph42oN GPLAsync build + Custom 165Hz uncap

# Asynchronous Shader Pipeline
dxvk.allowFse = true
dxvk.enableAsync = true
dxvk.gplAsyncCache = true
dxvk.enableGraphicsPipelineLibrary = false

# Thread Allocation (Intel i5-13450HX 16 threads / 2 = 8)
dxvk.numAsyncThreads = 8
dxvk.numCompilerThreads = 8

# Latency & Refresh Rate Uncap (165Hz Low-Latency)
d3d9.maxFrameLatency = 1
d3d9.presentInterval = 0
d3d9.maxFrameRate = 0
dxvk.tearFree = True
```

#### Why These Parameters Matter:
* `dxvk.enableAsync = true`: Enables asynchronous pipeline compilation on worker threads so rendering never waits on shader compiling.
* `dxvk.gplAsyncCache = true`: Caches Graphics Pipeline Library states to disk (`GTAIV.dxvk-cache`), making subsequent boots instantaneous without stutter.
* `dxvk.numAsyncThreads = 8`: Dedicates 8 worker threads on the 16-thread i5-13450HX specifically to background shader compilation.
* `d3d9.presentInterval = 0`: Completely ignores the game's internal Direct3D9 VSync requests, unlocking base framerate up to 165 FPS.
* `d3d9.maxFrameLatency = 1`: Enforces single-frame queue depth for minimal mouse/controller input latency.


### File 3: FusionFix Config
In [`GTAIV/plugins/GTAIV.EFLC.FusionFix.cfg`](file:///home/onyx/.local/share/Steam/steamapps/common/Grand%20Theft%20Auto%20IV/GTAIV/plugins/GTAIV.EFLC.FusionFix.cfg):
```ini
[FRAMELIMIT]
FpsLimitPreset = 0    # Set to 0 (Off) to disable FusionFix's internal half-refresh limiter
```

### File 4: In-Game Video Settings
In GTA IV **Options $\rightarrow$ Display**:
* **Resolution:** Cycle the slider until it reads `1920x1200 (165Hz)`.
* **VSync:** `Off`.
* **Windowed Borderless:** `On`.
* **Pause on Focus Loss:** `Off`.

---

## 5. Incompatible Mods & Crash Pitfalls (What NOT to Do)

Through rigorous live debugging on Complete Edition 1.2.0.59 + Wine/Proton, the following mods were verified as **unstable or game-breaking**:

| Component | Status | Technical Root Cause |
| :--- | :--- | :--- |
| **IV-SDK .NET / Liberty Tweaks** | **CRASH** | `IVSDKDotNet.asi` requires hardcoded memory offsets and C++ internal structs that only exist in downpatched 1.0.7.0 / 1.0.8.0. Complete Edition 1.2.0.59 changed the executable layout; injecting `IVSDKDotNet.asi` triggers an instant access violation and CTD on boot. |
| **ZolikaPatch / ZMenuIV** | **CRASH** | Incompatible with CE 1.2.0.59 memory layouts (throws `Error 998` `ERROR_NOACCESS`). Only works on downpatched 1.0.8.0/1.0.7.0. |
| **`ConsoleSelectMenuIV.asi`** | **CRASH** | Intercepts title screen memory hooks that collide with `aCompleteEditionHook.asi` on 1.2.0.59, causing an immediate CTD on boot. |
| **`update/6b Vehicle Mods` / Car Packs** | **CRASH** | Overwrites vehicle indexes and handling tables, triggering `GTA IV FATAL ERROR: Invalid resource detected`. |
| **`IVWPL.img` (Various Fixes)** | **CRASH** | World placement coordinate tables exceed CE 1.2.0.59 streaming limits. Only `VariousFixes.img` is safe. |
| **`ExtendedLimits = 1`** | **CRASH** | Table reallocation patches conflict with Wine/Proton's virtual memory heap, causing random crashes during boot or mission cutscenes. Keep `ExtendedLimits = 0`. |
| **iCEnhancer 4.0 / Legacy ENBs** | **CRASH** | Hardcoded to patch 1.0.4.0 DirectX 9 binaries; immediately breaks the Vulkan/DXVK pipeline. |
| **HQ Map Color V (Nexus #358)** | **VISUAL ARTIFACT** | Custom `radar.img` causes a thick white border ring and alpha mask corruption around the circular HUD minimap on CE 1.2.0.59 / DXVK. Omitted to preserve clean vanilla HUD. |
| **First Degree 154 Vehicle Addon Pack (Nexus #1025)** | **CRASH** | Requires `ExtendedLimits = 1` and extensive `fdvap_*.dat` memory tables, triggering a memory heap allocation crash on Complete Edition 1.2.0.59 + Wine/Proton. Reverted. |
| **DKT70 HD Road Overhaul (Nexus #643)** | **CRASH / UNSTABLE** | Global `gtxd.img` replacement causes crash / instability under DXVK when layered over existing visual OverLoader mods. Reverted. |

---

## 6. Trade-Off Analysis: What You Lose vs What You Gain

| Item | What is Omitted | Impact | What You Keep / Gain |
| :--- | :--- | :--- | :--- |
| **Liberty Tweaks (.NET)** | Dynamic camera sway, personal car ownership blips, Pay 'n Spray color picker. | **Moderate gameplay features.** | **100% stable game launch.** Zero memory injection crashes, zero mission breakages. |
| **WPL Overrides (`IVWPL.img`)** | Coordinate adjustments for a few dozen street props. | **Negligible.** Slightly misaligned benches/lights remain at stock placement. | **All 3D geometry fixes, collision meshes, missing textures, and floor-hole repairs** in `VariousFixes.img` (~95% of the mod). |
| **`ExtendedLimits = 0`** | Expansion of vehicle model tables beyond 120 slots. | **Zero** (unless installing 100+ separate add-on car packs). | **Complete Wine memory heap stability.** `VehicleBudget = 144000000` prevents texture popping on vanilla cars without crashes. |
| **Secondary ASIs** | Console select menu. | **Zero.** Menu selection is handled by Rockstar Launcher. | **Zero plugin conflicts, zero memory leaks.** |

---

## 7. Recommended Future Add-Ons

Current status of tested and verified add-on enhancements:

| Add-On Mod | Status | Architecture & Notes |
| :--- | :--- | :--- |
| **[Nexus #385: DXVK 2.6.2 GPLAsync & Cache](https://www.nexusmods.com/gta4/mods/385)** | **Installed & Active** | Asynchronous shader compilation eliminates pipeline hitching while maintaining 165Hz uncap. |
| **[Nexus #503: HQ Metallic Car Paint & Tires](https://www.nexusmods.com/gta4/mods/503)** | **Installed & Active** | `vehicles.img` placed non-destructively in `update/pc/models/cdimages/`. Enhanced metallic flake shaders and tire treads. |
| **[Nexus #781: HQ Vanilla Textures (Jersey)](https://www.nexusmods.com/gta4/mods/781)** | **Installed & Active** | 9 high-res map archives (2.4 GB) in `update/pc/data/maps/jersey/`. Revitalizes Alderney world textures. |
| **[Nexus #396: Natural Timecycle By DayL](https://www.nexusmods.com/gta4/mods/396)** | **Installed & Active** | Natural, vibrant New York lighting. Native Tonemapper with zero Vulkan stutter. |
| **[Nexus #298: Xbox Rain Droplets](https://www.nexusmods.com/gta4/mods/298)** | **VERIFIED WORKING & ACTIVE** | `GTAIV.XboxRainDroplets.asi` in `plugins/`. Restores Xbox 360 windshield and camera water droplet effects. |
| **[GTAForums #958625: Improved Animations Pack](https://gtaforums.com/topic/958625-improved-animations-pack/)** | **Pre-Integrated & Active** | Packaged in Gillian's `update/1 Minor Mods/` (`IAP.IV.img`, `IAP.TBoGT.img`, `IAP.TLAD.img`). Restores console assault rifle animations and fire rates. |
| **[Nexus #358: HQ Map Color V](https://www.nexusmods.com/gta4/mods/358?tab=files)** | **REMOVED (Visual Artifacts)** | Causes circular minimap HUD border alpha clipping and thick white ring artifacts on CE/DXVK. Removed to restore clean vanilla radar. |
| **[Nexus #875: LibertyCityPlates](https://www.nexusmods.com/gta4/mods/875)** | **Installed & Active** | `LibertyCityPlates.asi` + `update/CP,Shvab,Ash_GTAIV.EFLC.CityPlates/`. Randomized state license plates & custom shaders. |
| **[Nexus #843: Various Pedestrian Actions](https://www.nexusmods.com/gta4/mods/843)** | **Installed & Active** | Official v1.8 build in `update/4a Various Pedestrian Actions/VPA.img` + `Ambient.dat` & `default.ide`. Expands civilian animations. |
| **[Nexus #1025: First Degree 154 Vehicle Addon Pack](https://www.nexusmods.com/gta4/mods/1025)** | **REVERTED (Crash on CE/Proton)** | `ExtendedLimits = 1` and massive vehicle data tables conflict with Proton/Wine memory heap, triggering crash on boot. |
| **[Nexus #643: DKT70 HD Road Overhaul](https://www.nexusmods.com/gta4/mods/643)** | **REVERTED (Crash / Instability)** | `gtxd.img` replacement triggers DXVK device loss / crash when combined with active OverLoader textures. Reverted. |
| **[Nexus #395: DriftIV v3.0](https://www.nexusmods.com/gta4/mods/395)** | **Installed & Active** | AWD-Default V3 drifting physics deployed to `update/` with merged LibertyCityPlates flags. |
| **[The Assassination Mod V1.0](https://www.gtagaming.com/assassination-mod-v1-0-f22942.html)** | **Installed & Active (Testing)** | Procedural hitman contracts (`scripts/Ass.net.dll` + `ScriptHookDotNet.asi` v1.7.1.7b). Payphone `E`, assassin gear `K`. |
| **[Nexus #282: Complete Edition Vehicle Pack](https://www.nexusmods.com/gta4/mods/282)** | **Compatible (Requires Clean Archive)** | Compatible with FusionFix 1.52+ via `update/Ash_HiRes_VehiclesPack/`. Requires tuned `VehicleBudget`. See Section 8.1. |
| **[Liberty Vehicle Services CE](https://www.nexusmods.com/gta4/mods/1125)** | **Compatible Candidate** | Native C++ script for dealerships, fuel, repair, and registration. See Section 8.4. |
| **[Liberty Tweaks v1.7 + IV-SDK .NET](https://github.com/catsmackaroo/LibertyTweaks)** | **INCOMPATIBLE (Requires 1.0.8.0)** | Crashes on CE 1.2.0.59. Only functional if downpatching to 1.0.8.0. |

---

## 8. Deep Dives, Technical Autopsies & Advanced Roadmaps

### 8.1 Higher Resolution Vehicle Pack #282 Architecture & Sound Limitation
* **Mod:** [Higher Resolution Vehicle Pack 2.4 — 15th Anniversary Edition (Nexus #282)](https://www.nexusmods.com/gta4/mods/282)
* **Compatibility Status:** **Compatible with GTA IV Complete Edition** when using its dedicated Complete Edition package with FusionFix 1.52+.
* **Technical Architecture:**
  * Higher Resolution Vehicle Pack #282 does **not** suffer from "model index table corruption." It is purely a texture/material overhaul packaged into virtual archives (`update/Ash_HiRes_VehiclesPack/IV_Vehicle_Pack.img`).
  * When `vehicles.img` becomes much larger than vanilla, the game struggles to keep expected vehicle varieties in its streaming memory pool. The classic symptom is the **Taxi Bug** (only yellow cabs spawning).
  * FusionFix exposes `VehicleBudget` in `plugins/GTAIV.EFLC.FusionFix.ini` to resolve this (author recommends minimum `VehicleBudget = 78000000`, scaling up to `120000000` or `144000000`).
* **The 15 Engine-Sound Slot Limitation:**
  * Increasing `VehicleBudget` too high exposes an engine limitation discovered in 2025: GTA IV only has **15 engine-sound banks/slots** in memory. If high traffic variety forces more than 15 unique vehicle types to spawn simultaneously, cars will temporarily lose engine or door sounds.
  * **The Clean Balance:** Keep `VehicleBudget = 120000000` to prevent taxi bugs while staying within the audio bank ceiling.
* **LibertyCityPlates Optimization:** Version 2.4 provides an optional **Complete Edition Vehicle Pack (LibertyCityPlates)** (77.7 MB) optimized specifically to reduce the vehicle budget requirements.
* **Archive Warning:** Verify downloaded archives with `7z t` before extracting. Corrupted incomplete transfers trigger bad CRC data errors and crash on boot.

### 8.2 First-Person Options for Complete Edition 1.2.0.59

#### Option A: C06alt First Person v1.3 (Community CE Workaround / Experimental)
* **Status:** **Community CE Workaround / Experimental** (Not Officially Supported)
* **Source & Research:** [GTAForums Topic #953517: C06alt First Person Mod](https://gtaforums.com/topic/953517-reliv-gta-iv-first-person-mod-by-c06alt-legacy-v11-v122-v13-vr/)
* **Original Compatibility:**
  * Originally designed strictly for GTA IV 1.0.7.0 / 1.0.8.0.
  * Required older C++ ScriptHook + ASI Loader + HazardX .NET ScriptHook (`ScriptHookDotNet`).
  * The original release page does *not* claim native Complete Edition support.
* **Complete Edition Workaround (August 30, 2025 Report):**
  * Community reports demonstrate running v1.3 on **GTA IV Complete Edition 1.2.0.59 without downgrading** using the combined bridge stack:
    ```text
    FusionFix v5.0.1
    +
    GTA IV .NET ScriptHook v1.7.1.7b (HazardX)
    +
    Complete Edition ScriptHook compatibility patch (aCompleteEditionHook.asi)
    +
    C06alt First Person v1.3
    ```
  * *Original workaround placement:* Placed files into `GTAIV/scripts/`.
* **Community-Reported Newer FusionFix Layout (September 2025):**
  * With recent FusionFix versions, community users reported placing the First Person files directly into:
    ```text
    FirstPerson.asi
    FirstPerson.ini
        → GTAIV/plugins/
    ```
  * In this layout, the `GTAIV/scripts/` directory was removed entirely.
  * **Proton / Linux Verification:** A subsequent user verified this layout working on **Steam Deck**, providing crucial empirical evidence for Linux/Wine/Proton compatibility.
* **Technical Caveats & Dependency Nuances:**
  * While FusionFix + ASI loading is already 100% active in this setup, the potential complication is the **legacy .NET ScriptHook dependency**.
  * The Complete Edition compatibility patch provides updated `ScriptHookDotNet.asi` and `aCompleteEditionHook.asi`, but its documented update target was CE **1.2.0.43**, not 1.2.0.59.
  * Therefore, while the 2025 community workaround confirms viability on 1.2.0.59, it must be treated as a **community CE workaround** rather than officially certified.

#### Option B: Modern RTX FusionFix First Person Fork (Nexus #1237)
* **Compatibility:** Specifically written for CE 1.2.0.59, but requires the **RTX Remix Compatibility Mod** and its custom **RTX-compatible FusionFix fork**.
* **Drawbacks:**
  * Directly replaces the main FusionFix ASI binary.
  * Conflicts with other camera and script mods.
  * Has known user-reported bugs where bullets do not align with the reticle and camera flips on steep terrain.
* **Verdict:** Treat as a separate, experimental mod stack; do not inject into standard Proton FusionFix 5.0.1 installations.

### 8.3 Technical Autopsy: Why Liberty Tweaks & IV-SDK .NET Crashed
1. **Hardcoded Memory Offsets:** `IVSDKDotNet.asi` does not read dynamically hooked CE pointers like `aCompleteEditionHook.asi` does. Instead, it reads static memory address lookup tables (e.g., `IVSDK/1080.ini`).
2. **Binary Struct Shift:** Rockstar Games updated internal game binaries in patch 1.2.0.43 and 1.2.0.59, altering memory alignment, offsets, and struct layouts of player classes, vehicle pools, and engine subroutines.
3. **Access Violation:** Even when providing cloned offset configuration files named `12059.ini`, underlying native hook function pointers in `IVSDKDotNet.asi` point to invalid memory addresses when invoked against `GTAIV.exe` 1.2.0.59, causing an immediate `EXCEPTION_ACCESS_VIOLATION` crash to desktop.
4. **Conclusion:** Liberty Tweaks and IV-SDK .NET **strictly require downpatching GTA IV to 1.0.8.0 or 1.0.7.0**. On official Steam Complete Edition 1.2.0.59, native C++ ASI mods are the only stable scripting ecosystem.

### 8.4 Combining Custom Vehicle Addon Packs + Liberty Vehicle Services CE (LVS) + DKT70 HD Roads

#### Architectural Feasibility: YES (100% Compatible with Proper Sequencing)
Combining custom vehicle addon packs (such as First Degree 154 Vehicle Addon Pack), Liberty Vehicle Services CE (LVS v0.96 Beta), and DKT70 HD Roads is **technically viable** on GTA IV Complete Edition 1.2.0.59 + Proton because each component operates on completely separate, isolated subsystems of the engine:

1. **DKT70 HD Roads (FusionFix Edition / IV-LANE):**
   * **Subsystem:** Map World Textures (`.img` / `.wtd` archives).
   * **Interaction:** Pure asset replacement affecting asphalt, curbs, lines, and sidewalks.
   * **Scripting Conflict:** **Zero.** Does not touch handling, IDE, ASI plugins, or vehicle definitions.
   * **Critical Caveat:** You must use modern FusionFix-compatible repackages (e.g. IV-LANE Edition or downscaled 512x512/1024x1024 textures) rather than the raw 2011 2048x2048 DKT70 release. Raw uncompressed 2K textures exhaust DirectX 9 address space on 32-bit `GTAIV.exe`, causing bridge pop-in when crossing between Broker and Alderney.

2. **Liberty Vehicle Services CE (LVS v0.96 Beta, Nexus #1125):**
   * **Subsystem:** Native C++ ASI Script (`LibertyVehicleServices.asi`).
   * **Interaction:** Injects dealership mechanics, fuel gauges, vehicle maintenance, vehicle purchasing/ownership, and registration plates.
   * **Addon Vehicle Support:** Specifically designed for Complete Edition. In version 0.96, the author implemented experimental automatic parsing of addon vehicle definition files:
     ```ini
     [Compatibility]
     LoadAddonVehicleDataFiles=true
     UseNativeVehicleDefinitionFallback=false

     [Fuel]
     FuelAffectsUnknownVehicles=false
     ```
   * **Safety Guard:** Setting `FuelAffectsUnknownVehicles=false` ensures that if an addon car has non-standard tank geometry or missing handling flags, the script does not crash the engine or leave the car stranded with 0% fuel.

3. **Custom Vehicle Addon Packs (e.g., First Degree 154 Addon Pack):**
   * **Subsystem:** Game Memory Pools & Streaming Archives (`vehicles.img`, `vehicles.ide`, `handling.dat`).
   * **Interaction:** Adds new car models without replacing vanilla vehicles.
   * **Engine Limits & Risks:**
     * **Streaming Budget:** Requires calibrating `VehicleBudget` in `GTAIV.EFLC.FusionFix.ini`. For 100+ addon vehicles, `VehicleBudget = 144000000` (144 MB) is mandatory to eliminate the Taxi Bug.
     * **The 15 Sound-Bank Ceiling:** GTA IV has a strict hardcoded limit of 15 simultaneous vehicle audio sound banks. Adding dozens of exotic supercars with unique sound IDs can exceed this ceiling during dense traffic, causing engine sounds to drop out intermittently.
     * **ExtendedLimits Invariant:** `ExtendedLimits` in `GTAIV.EFLC.FusionFix.ini` must remain `0`. Enabling `ExtendedLimits = 1` causes heap corruption under Wine/Proton.

#### Recommended Step-by-Step Implementation Sequence:
To guarantee zero-crash stability, never drop all three systems in simultaneously:
* **Step 1: Install & Test Liberty Vehicle Services CE first.** Verify dealerships and fuel mechanics work cleanly with stock vehicles.
* **Step 2: Add Custom Vehicle Addon Pack & Calibrate Memory.** Tune `VehicleBudget = 144000000`, verify addon cars spawn via Liberty's Legacy trainer, and check that engine sounds remain intact.
* **Step 3: Enable LVS Addon Compatibility.** Enable `LoadAddonVehicleDataFiles=true` in `LibertyVehicleServices.ini` to let LVS catalog the new cars.
* **Step 4: Deploy DKT70 HD Roads via Fusion OverLoader.** Drop road archives into `update/` and verify seamless streaming when driving at high speed across borough bridges.

### 8.5 DriftIV 3.0 (Parked in Standby)
* **Status:** Parked in standby at `GTAIV/standby_mods/DriftIV_3.0_AWD_Default/`.
* **Quick Re-enable Command:**
  ```bash
  GAME_DIR="$HOME/.local/share/Steam/steamapps/common/Grand Theft Auto IV/GTAIV"
  cp -r "$GAME_DIR/standby_mods/DriftIV_3.0_AWD_Default/"* "$GAME_DIR/update/"
  ```
* **Hex Flag Injection:** Pre-patched with LibertyCityPlates model hex flags (`20040048`, `20224008`, `20000008`, `20004048`), ensuring commercial trucks, emergency vehicles, and taxis retain authentic regional plates whenever active.

### 8.6 DKT70 HD Roads (Active via Fusion OverLoader)
* **Mod:** DKT70 Road Texture Overhaul v0.8 Beta (Nexus Mods #643).
* **Architecture:** Deployed non-destructively as `update/pc/data/cdimages/gtxd.img` (103.6 MB). Overrides global asphalt, highway, lane marking, and sidewalk textures across Liberty City while preserving vanilla base archives.
* **Compatibility Invariant:** Runs stably under Wine/Proton with `ExtendedLimits = 0`. Does not touch vehicle memory pools or handling scripts.
* **Quick Removal Command:**
  ```bash
  rm -rf "$HOME/.local/share/Steam/steamapps/common/Grand Theft Auto IV/GTAIV/update/pc/data/cdimages"
  ```

### 8.7 The Assassination Mod v1.0 (.NET Script on CE 1.2.0.59)
* **Mod:** The Assassination Mod v1.0 by JulioNIB (`Ass.net.dll`).
* **Architecture:** Uses HazardX `ScriptHookDotNet.asi` (v1.7.1.7b) bridging into `aCompleteEditionHook.asi`.
* **Placement:**
  - `GTAIV/ScriptHookDotNet.asi`
  - `GTAIV/ScriptHookDotNet.dll`
  - `GTAIV/scripts/Ass.net.dll`
  - `GTAIV/scripts/ScriptHookDotNet.dll`
* **Triggering Missions:**
  - Answer ringing public payphones by pressing `E` (or Controller LB).
  - Walk into Middle Park public restrooms.
  - Press `K` inside vehicles to toggle assassin weaponry and gear.
* **Emergency Rollback:** If Wine crashes due to .NET runtime issues:
  ```bash
  rm -f "$HOME/.local/share/Steam/steamapps/common/Grand Theft Auto IV/GTAIV/ScriptHookDotNet.asi" \
        "$HOME/.local/share/Steam/steamapps/common/Grand Theft Auto IV/GTAIV/ScriptHookDotNet.dll"
  rm -rf "$HOME/.local/share/Steam/steamapps/common/Grand Theft Auto IV/GTAIV/scripts"
  ```

---


## 9. Clean Removal Commands

To wipe all mods and restore the game to pure vanilla:
```bash
GAME_DIR="$HOME/.local/share/Steam/steamapps/common/Grand Theft Auto IV/GTAIV"
# Remove ScriptHook and trainer
rm -rf "$GAME_DIR/Liberty's Legacy" "$GAME_DIR/Liberty's Legacy.asi" "$GAME_DIR/ScriptHook.dll" "$GAME_DIR/aCompleteEditionHook.asi" "$GAME_DIR/scripthook.log"
# Remove custom overrides
rm -rf "$GAME_DIR/commandline.txt" "$GAME_DIR/dxvk.conf"
# Restore clean update/ and plugins/ from backup
rm -rf "$GAME_DIR/plugins" "$GAME_DIR/update"
cp -r "$GAME_DIR/backup_pre_4.9g_pack/plugins" "$GAME_DIR/"
cp -r "$GAME_DIR/backup_pre_4.9g_pack/update" "$GAME_DIR/"
```
