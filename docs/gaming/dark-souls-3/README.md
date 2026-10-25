# Dark Souls III — CachyOS Modding & Execution Master Architecture

**Target System:** CachyOS rolling (x86-64-v3, BORE/EEVDF) · Sway (Wayland) / i3wm (X11) @ 1920x1200 165Hz  
**Hardware:** ASUS TUF Gaming F16 (Intel Core i5-13450HX + NVIDIA GeForce RTX 5050 Mobile 6GB GDDR6 Blackwell)  
**Game AppID:** `374320`  
**Physical Game Directory:** `/mnt/Games/NonSteamGames/Dark Souls III`  
**Steam Symlink:** `/home/onyx/.local/share/Steam/steamapps/common/DARK SOULS III/Game` -> `/mnt/Games/NonSteamGames/Dark Souls III`  
**Proton Prefix:** `/home/onyx/.local/share/Steam/steamapps/compatdata/374320/pfx`  

---

## 1. Quick In-Game Controls & Toggles

| Action | Hotkey | Details |
| :--- | :--- | :--- |
| **Open / Close ReShade Menu** | `Shift + F2` *(or `Fn + Shift + F2`)* | Opens the live shader overlay on the left side of the screen. |
| **Toggle All Effects (Before/After)** | `Shift + F3` *(or `Fn + Shift + F3`)* | Instantly toggles Eden CYCLES post-processing on and off. |
| **Disable Depth of Field (DOF)** | **Uncheck `ADOF [qUINT_dof.fx]`** | In the ReShade menu (`Shift + F2`), uncheck the box next to `ADOF [qUINT_dof.fx]`. This eliminates background/distance blur immediately while retaining bloom, reflections, and color grading. |

---

## 2. Active Mod Matrix & File Layout

### A. Disable Camera Auto Rotate and Target Lock Reset
* **Nexus Mods:** [Disable Camera Auto Rotate And Target Lock Reset (Mod 2397)](https://www.nexusmods.com/darksouls3/mods/2397)
* **File on Disk:** `/mnt/Games/NonSteamGames/Dark Souls III/dinput8.dll`
* **MD5:** `1f90f8281379e9d16d7731532b324c4a`
* **Hook Mechanism:** Hooked through `IDirectInput8W::CreateDevice` via `WINEDLLOVERRIDES="dinput8=n,b"`.
* **Functionality:** 
  1. Completely eliminates automatic camera rotation/centering when the character moves.
  2. Stops the game from breaking lock-on when target line-of-sight is temporarily obstructed.

---

### B. Eden CYCLES Graphics Overhaul (formerly Ludite)
* **Nexus Mods:** [Eden CYCLES (Mod 808)](https://www.nexusmods.com/darksouls3/mods/808)
* **Author:** Seifu
* **Upstream Shader Repositories Used:**
  * [Glamayre Fast Effects](https://github.com/rj200/Glamarye_Fast_Effects_for_ReShade)
  * [brussell1 Shaders](https://github.com/brussell1/Shaders)
  * [luluco250 FXShaders](https://github.com/luluco250/FXShaders)
  * [martymcmodding qUINT](https://github.com/martymcmodding/qUINT)
  * [SweetFX](https://github.com/CeeJayDK/SweetFX)
  * [prod80 ReShade Repository](https://github.com/prod80/prod80-ReShade-Repository)
* **Core Deployed Shaders:** Located in `/mnt/Games/NonSteamGames/Dark Souls III/reshade-shaders/Shaders/`:
  * `Detect_menus_and_videos_wrapper.fx` (bypasses shader effects over HUD/UI and cutscenes)
  * `Glamayre_Fast_Effects.fx` (fast ambient occlusion and fake global illumination)
  * `fastBlur.fx` & `warpsharp.fx`
  * `FilmGrain.fx`
  * `DepthSharpenStaticDof.fx`
  * `brussell/UIDetect.fxh`, `UIDetect.fx`, `EyeAdaption.fx`, `AreaCopy.fx`, `AreaDiscard.fx`
* **Presets Location:** `/mnt/Games/NonSteamGames/Dark Souls III/reshade-presets/eden CYCLES/`
* **Active Config:** `/mnt/Games/NonSteamGames/Dark Souls III/reshade-presets/eden CYCLES/eden CYCLES.ini`
* **Installer GUI Tool:** `~/.local/bin/cycles-installer-gui` (launched via `Alt + Space` -> `Eden CYCLES ReShade Installer`).
* **Root Cause Fix for Linux Installer Error:**
  * The installer binary (`SeifuLauncher2.exe`) executes an explicit check:
    ```cpp
    const QFileInfo brussellDir(exeDir + "/reshade-shaders/shaders/brussell");
    if (!brussellDir.exists()) {
        MessageBox(nullptr, TEXT("This usually happens due to an incorrect ReShade installation..."), ...);
    }
    ```
  * Linux filesystems are case-sensitive. While ReShade creates `reshade-shaders/Shaders` (capital `S`), the installer tests lowercase `shaders/brussell`.
  * **Solution Applied:** Physical folder `/mnt/Games/NonSteamGames/Dark Souls III/reshade-shaders/shaders/brussell` and `/mnt/Games/NonSteamGames/Dark Souls III/reshade-shaders/Shaders/brussell` both exist as real directories containing the `brussell1` shaders.

---

### C. ReShade (DirectX 11 Proxy) & LeShade
* **LeShade AppImage Repository:** [Ishidawg/LeShade](https://github.com/Ishidawg/LeShade)
* **Official ReShade:** [reshade.me](https://reshade.me/)
* **Files on Disk:**
  * Proxy DLL: `/mnt/Games/NonSteamGames/Dark Souls III/d3d11.dll` (64-bit ReShade binary)
  * Shader Compiler DLLs: `/mnt/Games/NonSteamGames/Dark Souls III/d3dcompiler_43.dll` and `d3dcompiler_47.dll`
  * Main Configuration: `/mnt/Games/NonSteamGames/Dark Souls III/ReShade.ini`
  * Global Shader Folders: `/mnt/Games/NonSteamGames/Dark Souls III/reshade-shaders/`
  * LeShade Manager Executable: `~/.local/bin/leshade` (desktop entry: `leshade.desktop`)
* **Key Configuration in `ReShade.ini`:**
  ```ini
  [GENERAL]
  EffectSearchPaths=.\reshade-shaders\Shaders,.\reshade-shaders\Shaders\qUINT,.\reshade-shaders\Shaders\PD80,.\reshade-shaders\Shaders\Depth3D,.\reshade-shaders\Shaders\AstrayFX,.\reshade-shaders\Shaders\OtisFX,.\reshade-shaders\Shaders\FGFX,.\reshade-shaders\Shaders\brussell,.\reshade-shaders\Shaders\Daodan,.\reshade-shaders\Shaders\Fubax,.\reshade-shaders\Shaders\Insane-Shaders,.\reshade-shaders\Shaders\luluco250,.\reshade-shaders\Shaders\RSRetroArch,.\reshade-shaders\Shaders\CorgiFX,.\reshade-shaders\Shaders\Radegast,.\reshade-shaders\Shaders\CobraFX,.\reshade-shaders\Shaders\VRToolkit
  TextureSearchPaths=.\reshade-shaders\Textures
  PresetPath=.\reshade-presets\eden CYCLES\eden CYCLES.ini
  PreprocessorDefinitions=RESHADE_DEPTH_INPUT_IS_REVERSED=0

  [INPUT]
  KeyOverlay=113,0,1,0    # Shift + F2
  KeyEffects=114,0,1,0    # Shift + F3
  ```

---

### D. DS3 Item and Enemy Randomizer
* **Nexus Mods:** [Dark Souls III Item and Enemy Randomizer (Mod 361)](https://www.nexusmods.com/darksouls3/mods/361)
* **Author / GitHub:** [thefifthmatt/DS3Randomizer](https://github.com/thefifthmatt/DS3Randomizer)
* **Files on Disk:**
  * GUI Tool: `/mnt/Games/NonSteamGames/Dark Souls III/randomizer/DS3Randomizer.exe`
  * Crash Fix DLL: `/mnt/Games/NonSteamGames/Dark Souls III/randomizer/dll/RandomizerCrashFix.dll`
  * Config: `/mnt/Games/NonSteamGames/Dark Souls III/config_ds3randomizer.toml`
  * Randomized Data: `/mnt/Games/NonSteamGames/Dark Souls III/Data0.bdt` (patched archive containing enemy/item parameter tables)
* **Launcher Wrapper:** `/home/onyx/.local/bin/ds3-randomizer-gui` (desktop entry: `ds3-randomizer.desktop`)
* **How Re-Randomizing Works:**
  1. Open `Alt + Space` -> **Dark Souls III Randomizer**.
  2. Select desired enemy / item / weapon rules.
  3. Click **Randomize items and enemies** to generate new tables.
  4. The launcher wrapper automatically syncs the resulting `Data0.bdt` and related `map/event/script` folders into the root game directory on window close.
  5. Start a new character or load a seeded save to play.

---

### E. True Minimalist HUD
* **Nexus Mods:** [True Minimalist HUD (Mod 818)](https://www.nexusmods.com/darksouls3/mods/818)
* **Author:** Joel LeVecque (Seriously Casual)
* **Files on Disk:**
  * Active Deployed Files:
    * `/mnt/Games/NonSteamGames/Dark Souls III/menu/01_000_fe.gfx`
    * `/mnt/Games/NonSteamGames/Dark Souls III/menu/01_001_fe_soul.gfx`
    * `/mnt/Games/NonSteamGames/Dark Souls III/menu/01_common.tpf.dcx`
  * Randomizer Sync Copies: Also mirrored into `/mnt/Games/NonSteamGames/Dark Souls III/randomizer/menu/` so re-randomizing seeds preserves the minimalist HUD.
  * Preserved Vanilla Backups:
    * `menu/01_000_fe.gfx.vanilla_bak`
    * `menu/01_001_fe_soul.gfx.vanilla_bak`
  * Complete Package Staging: `/mnt/Games/NonSteamGames/Dark Souls III/mods_archive/True_Minimalist_HUD/` containing both `Regular Version` and `Mage And Pyromancer Version` (which keeps the spell box visible for caster builds).
* **Functionality:** Strips away bulky health/FP/stamina gauge frames, souls counter, and weapon boxes for a distraction-free, ultra-clean interface.

---

## 3. Launcher & Runtime Orchestration

The game is launched via `/home/onyx/.local/bin/darksouls3-run` (desktop entry: `darksouls3.desktop`).

### Key Pipeline Components:

1. **Dual-DLL Chainloading:**
   ```bash
   export WINEDLLOVERRIDES="d3d11=n,b;dinput8=n,b;d3dcompiler_43=n,b;d3dcompiler_47=n;dxgi=n,b"
   ```
   * Wine loads `d3d11.dll` (ReShade proxy) natively $\rightarrow$ ReShade intercepts render passes and passes standard DX11 to DXVK.
   * Wine loads `dinput8.dll` (Camera auto-rotate fix) natively $\rightarrow$ hooks DirectInput8 controller/keyboard routines.
   * No collisions occur between the two mods.

2. **Hardware Offloading & DXVK Optimization:**
   ```bash
   export __NV_PRIME_RENDER_OFFLOAD=1
   export __GLX_VENDOR_LIBRARY_NAME=nvidia
   export __VK_LAYER_NV_optimus=NVIDIA_only
   export DXVK_ASYNC=1
   export DXVK_STATE_CACHE=1
   export PROTON_ENABLE_NVAPI=0
   ```

3. **Lossless Scaling Frame Generation (LSFG-VK) & MangoHud:**
   * **Dedicated Per-Game Config:** `/mnt/Games/NonSteamGames/Dark Souls III/MangoHud.conf` (loaded via `MANGOHUD_CONFIGFILE`, leaving the protected global `~/.config/MangoHud/MangoHud.conf` untouched). It mirrors the global/Elden Ring overlay exactly: minimal horizontal HUD — FPS/frametime → CPU → GPU → VRAM/RAM, top-left, compact, with `LSFG 120 (2x)` / `Base 60` status labels. Starts hidden — `Alt+3` toggles it; `Alt+4` cycles font presets (hidden 15 → 20 → 30), `Alt+5` steps HUD position, `Alt+6` resets FPS metrics, `Alt+7` toggles the (unset) frame cap, `Alt+8` reloads the config; logging is disabled.
   * **Hotkey cadence:** MangoHud debounces hotkeys ~0.4 s — press once, pause, press again; rapid taps count once. `Alt+5` steps one of 8 anchors per press; the full-width HUD renders the left/center/right anchors of a row in the same spot, so the visible change is the row (top / middle / bottom).
   * `LSFGVK_PROFILE="Dark Souls III"`: Intercepts Vulkan presentation to generate 2x interpolated frames (60 → 120, under the 165Hz panel).

4. **Workspace Management:**
   * Focuses Sway/i3 Workspace 4 automatically upon launch.
   * Does not alter or force laptop power profiles or CPU governors (`asusctl` and governor management remain under user control).

5. **Gamescope Encapsulation with Mangoapp:**
   * Runs inside Gamescope container with native `--mangoapp` integration:
     ```bash
     gamescope --mangoapp -W 1920 -H 1200 -w 1920 -h 1200 -f -r 165 -- <RUN_COMMAND>
     ```
   * `--mangoapp` guarantees that MangoHud renders cleanly on top of Gamescope's virtual swapchain without HUD suppression or flickering.

---

## 4. Application Launcher (`Alt + Space`) & Desktop Integration

All Dark Souls III binaries and modding tools are registered directly into the system's application launcher (`Alt + Space` / Fuzzel / Rofi) via XDG desktop specifications in `~/.local/share/applications/`:

| Menu Search Item | Desktop Entry | Wrapper Script Executed | Behavior & Window Management |
| :--- | :--- | :--- | :--- |
| **Dark Souls III** | `darksouls3.desktop` | `~/.local/bin/darksouls3-run` | Focuses **Workspace 4**, enables RTX 5050 dGPU offload, applies dual-DLL overrides, displays the same minimal MangoHud overlay as Elden Ring/global (hidden by default — `Alt+3` toggles), and runs under Gamescope @ 1920x1200 165Hz. |
| **Dark Souls III Randomizer** | `ds3-randomizer.desktop` | `~/.local/bin/ds3-randomizer-gui` | **Floats and centers** on your current workspace. Unsets Steam AppID to prevent Steam client hooks/black screens. Automatically syncs newly rolled `Data0.bdt` seed data to the game directory on exit. |
| **Eden CYCLES ReShade Installer** | `cycles-installer.desktop` | `~/.local/bin/cycles-installer-gui` | **Floats and centers** on current workspace. Runs the official Qt-based installer with software rasterization (`LIBGL_ALWAYS_SOFTWARE=1`) to prevent Wine OpenGL/Vulkan GUI stalls. |
| **LeShade ReShade Manager** | `leshade.desktop` | `~/.local/bin/leshade` | Runs the standalone Linux ReShade AppImage manager for updating or downloading fresh shader packages. |

### Technical Invariants for Launcher GUI Tools:
1. **Steam AppID Stripping (Black Screen Prevention):**
   Tools like `DS3Randomizer.exe` and `CYCLES - Installer.exe` crash or display an unresponsive black/white screen if they inherit the game's Steam AppID from the shell environment. Both launcher scripts explicitly enforce:
   ```bash
   unset SteamAppId
   unset SteamGameId
   ```
2. **GUI Software Fallback under Wine/Proton:**
   WPF/.NET/Qt Windows installer GUIs running under Proton can glitch when negotiating hardware Vulkan surfaces. The wrappers pass:
   ```bash
   export PROTON_USE_WINED3D=1
   export LIBGL_ALWAYS_SOFTWARE=1
   ```
3. **Window Rule Enforcement (Sway/i3):**
   Configured in `~/.config/sway/config.d/30-window-rules.conf`:
   ```ini
   # DS3 Modding Utilities — float, disable fullscreen, and open on current workspace
   for_window [title="(?i).*(randomizer|cycles|reshade).*"] fullscreen disable, floating enable, move to workspace current, move position center, focus
   ```

---

## 5. Verification Checklist for Future AI Agents

If diagnosing or updating this Dark Souls III installation:
1. **Never edit `~/.config/MangoHud/MangoHud.conf` directly** (managed by Chezmoi and protected).
2. **Check DLL Overrides:** Ensure `WINEDLLOVERRIDES` in `darksouls3-run` includes both `d3d11=n,b` and `dinput8=n,b`.
3. **Check Symlinks & Paths:** Verify `/mnt/Games/NonSteamGames/Dark Souls III/reshade-shaders/shaders/brussell` and `Shaders/brussell` are populated with `AreaCopy.fx`, `AreaDiscard.fx`, `EyeAdaption.fx`, `UIDetect.fx`, and `UIDetect.fxh`.
4. **Inspect Logs:**
   * ReShade log: `/mnt/Games/NonSteamGames/Dark Souls III/ReShade.log`
   * Randomizer log: `/mnt/Games/NonSteamGames/Dark Souls III/randomizer/log.txt`
