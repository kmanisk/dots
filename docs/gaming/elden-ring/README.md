# Elden Ring — Linux Setup, Mod Architecture & Experience Log

**Platform:** Windows 64-bit binary running via Proton  
**Target Hardware:** ASUS TUF Gaming F16 (Intel i5-13450HX + NVIDIA GeForce RTX 5050 Mobile Blackwell `sm_120`, 8GB GDDR7 @ 1920x1200 165Hz)  
**Operating System:** CachyOS rolling (BORE/EEVDF kernel) · Sway (Wayland) / i3wm (X11)  
**Compatdata Prefix:** `~/.local/share/Steam/steamapps/compatdata/2703476723` (symlinked from AppID `1245620`)  
**Save Backup Location:** `~/.local/share/EldenRing_Save_Backup/EldenRing/76561197960271872/ER0000.sl2`  

---

## 1. Quick Status Overview

| Component | Status | Implementation Details |
|---|---|---|
| **DirectX 12 / VKD3D** | **WORKING** | `VKD3D_CONFIG="no_upload_hvv,force_host_cached"` and `PROTON_ENABLE_NVAPI=0` for Blackwell RTX 5050 stability. |
| **GPU Offloading** | **WORKING** | Direct PRIME offload (`__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only`). |
| **LSFG-VK 2.0 (Frame Gen)** | **WORKING** | 2x multiplier via `LSFGVK_PROFILE="Elden Ring"` (`multiplier = 2` in `~/.config/lsfg-vk/conf.toml`, managed as chezmoi template): 60 FPS base → 120 generated FPS (held at or under the 165Hz panel per §9), `pacing_mode = "vsync"`, `override_present_mode = true`. |
| **MangoHud Hardware Monitor** | **WORKING** | Custom per-game config in `Game/MangoHud.conf`: top-left compact HUD (CPU/GPU thermals + wattage, VRAM/RAM, `LSFG 120 (2x)` / `Base 60` status; hidden by default — `Alt+3` toggles; `Alt+4` font presets, `Alt+5` position — see `docs/gaming/README.md` §5). Passed to Wine via `user_settings.py` in the prefix (NOT exported in outer bash — outer export makes Proton's Python runtime hook MangoHud and SIGABRT on startup). |
| **DLL Mod Loader** | **WORKING** | EldenModLoader (`dinput8.dll`) hooks on boot with `WINEDLLOVERRIDES="dinput8=n,b"`. |
| **Camera Fix Mod** | **WORKING** | `CameraFix.dll` disables auto-rotation and target lock camera snaps. |
| **ModEngine 2 & Randomizer** | **WORKING** | ModEngine 2 loads randomized assets dynamically from `randomizer/`. .NET 8.0 Desktop Runtime installed in prefix for Randomizer GUI. |
| **Rofi Game Menu (`Alt + g`)** | **WORKING** | Single unified entry `ELDEN RING + LSFG (120 FPS)` and dedicated GUI entry `ER Randomizer Config (GUI)`. |

---

## 2. Mod Inventory & Directory Structure

### Mod Roster
1. **[Elden Mod Loader v3.2](https://www.nexusmods.com/eldenring/mods/117)**
   - **Path:** `/mnt/Games/NonSteamGames/ELDEN RING/Game/dinput8.dll`
   - **Config:** `/mnt/Games/NonSteamGames/ELDEN RING/Game/mod_loader_config.ini`
   - **Purpose:** Automatically loads DLL mods inside `Game/mods/` upon game start.
2. **[Fix The Camera v3.0](https://www.nexusmods.com/eldenring/mods/118)**
   - **Path:** `/mnt/Games/NonSteamGames/ELDEN RING/Game/mods/CameraFix.dll`
   - **Config:** `/mnt/Games/NonSteamGames/ELDEN RING/Game/mods/CameraFix/config.ini`
   - **Settings:** `disable_camera_auto_rotate = 1`, `disable_camera_reset = 1`. Eliminates unwanted automatic camera centering and target lock resets.
3. **[Mod Engine 2.1.0.0](https://github.com/soulsmods/ModEngine2/releases)**
   - **Path:** `/mnt/Games/NonSteamGames/ELDEN RING/ModEngine2/ModEngine-2.1.0.0-win64/`
   - **Config:** `/mnt/Games/NonSteamGames/ELDEN RING/ModEngine2/ModEngine-2.1.0.0-win64/config_eldenring.toml`
   - **Configuration:** Linked to load `randomizer` assets dynamically without modifying original base game `.bdt` archives.
4. **[Elden Ring Item and Enemy Randomizer v0.12.2](https://www.nexusmods.com/eldenring/mods/428)**
   - **Path:** `/mnt/Games/NonSteamGames/ELDEN RING/randomizer/EldenRingRandomizer.exe`
   - **Launcher:** `~/.local/bin/eldenring-randomizer-gui`
   - **Runtimes Required:** Microsoft .NET 8.0 Windows Desktop Runtime (`windowsdesktop-runtime-8.0-win-x64.exe`) and .NET 6.0 Desktop Runtime installed into prefix `2703476723`.
5. **[RemoveChromaticAberration v3.0 / RemoveVignette v3.0 / SkipTheIntro v4.0](https://www.nexusmods.com/eldenring/mods/179)**
   - **Type:** EldenModLoader DLLs in `Game/mods/` (`RemoveChromaticAberration.dll`, `RemoveVignette.dll`, `SkipTheIntro.dll` + `SkipTheIntro/config.ini`), registered in `Game/mod_loader_config.ini` `[loadorder]` (CameraFix=1, SkipTheIntro=2, Chromatic=3, Vignette=4). Note: RandomizerCrashFix already fast-boots past the logos; SkipTheIntro additionally hides the white screen.
7. **[ERFPS — First Person Souls v1.2.2](https://www.nexusmods.com/eldenring/mods/3266)** — PARKED (boot caused black screen under Proton, see §9-era notes)
   - **Files:** `Game/mods/erfps.dll` + `erfps_settings.ini` on disk but **removed from `[loadorder]`**. Hold-lock-on first-person stays available by re-adding `erfps.dll = 5`.
   - **Caveat:** 2023 build; author states Linux unsupported. It hooks the DirectX present path, which also suppresses the MangoHud overlay — prime suspect for the black-screen stretch alongside the 2022 HUD gfx.
8. **Minimal HUD v1.2.3 (translucent) + My HUD Tweaks 1.08.1**
   - **Deploy:** ModEngine2 `hud/menu/*.gfx` (OPTION 2 Translucent base, tweak's `01_000_fe.gfx` over it). Wired via hand-managed `config_custom.toml` (randomizer + hud). To switch to Normal backgrounds, swap in OPTION 1's `menu/` folder.
9. **[IMCO — Improved Melee Combat Overhaul SOTE v4.01](https://www.nexusmods.com/eldenring/mods/2177)** — PARKED (2026-10-16)
   - Files staged (not loaded) in `ModEngine2/.../imco/` (`regulation.bin`, `chr/*.anibnd.dcx`, `param/systemparam/systemparam.parambnd.dcx`).
   - Merge attempted via the randomizer's built-in "Merge other mod": crashed with `NullReferenceException` in `CharacterWriter.getStat` — IMCO's Oct-2024 regulation lacks rows the current randomizer expects (version desync), exactly the flagged risk.
   - Fallback active per plan: `config_imco.toml` renamed to `config_imco.toml.disabled`, launcher falls back to `config_eldenringrandomizer.toml` (randomizer-only, boot-verified). To retry IMCO solo later, re-enable the file (IMCO wins, randomizer placement dormant).
5. **[Lossless Scaling LSFG-VK 2.0](https://github.com/Kars45/lsfg-vk)**
   - **Config:** `~/.config/lsfg-vk/conf.toml` (`[[profile]] name = "Elden Ring"`, `active_in = "eldenring.exe"`, `multiplier = 4`, `pacing_mode = "vsync"`; chezmoi template).

---

## 3. Launcher Architecture & Orchestration

### Main Game Launcher (`~/.local/bin/eldenring-lsfg` → `eldenring-launch-inner`)
- **No gamescope, no CPU pinning:** Proton (`proton-cachyos-slr`, ntsync) runs ModEngine2 directly on Sway Workspace 4. Do NOT add `taskset -c 0-11` — see §5, it kills the launch.
- **Inner supervision:** `eldenring-launch-inner` runs `modengine2_launcher.exe` in the foreground, then `wineserver -w`, so the supervisor lives for the whole session and `asusctl` restores Balanced only after exit.
- **SIGHUP-proof:** `trap '' HUP` in both scripts + `nohup` in `rofi-games`, so closing the Alt+g menu can't kill the game.
- **Workspace Navigation:** Automatically activates **Workspace 4** upon launch.
- **MangoHud delivery:** written to `$STEAM_COMPAT_DATA_PATH/user_settings.py` by the inner script:
  ```python
  user_settings = {
      "MANGOHUD": "1",
      "MANGOHUD_CONFIGFILE": "/mnt/Games/NonSteamGames/ELDEN RING/Game/MangoHud.conf",
  }
  ```
- **MangoHud keys:** `Alt+3` HUD on/off | `Alt+4` font presets (hidden 15 / 20 / 30) | `Alt+5` position cycle (one anchor per press; visible as top/middle/bottom row changes) | `Alt+6` reset FPS metrics | `Alt+7` frame-cap toggle (no cap defined — no-op) | `Alt+8` reload config. Hotkeys debounce ~0.4 s: pause between presses — rapid taps count once.
- **Power Policy:** `asusctl profile set Performance` on launch, restored to Balanced on exit via `EXIT/INT/TERM` trap.
- **Audio:** follows the system default output (whatever `Alt+Shift+o` / `toggle-audio-sink` selected). The launcher deliberately does NOT force `sink.peace_gaming` — forced routing bypassed the selected device and went silent when the gaming chain sat idle-suspended. `Alt+Shift+o` moves live game streams on switch. Alt+g logs to `/tmp/eldenring-lsfg.log` for diagnosis.

### Randomizer GUI Launcher (`~/.local/bin/eldenring-randomizer-gui`)
- Unsets `SteamAppId` and `SteamGameId` to prevent black screen Steam client attachments.
- Runs `EldenRingRandomizer.exe` inside the calibrated prefix with .NET 8.0 support.
- Automatically focuses the Randomizer window upon spawn.

---

## 4. How to Rerandomize Items and Enemies

1. Press `Alt + g` and select **`ER Randomizer Config (GUI)`** (or run `eldenring-randomizer-gui` in terminal).
2. Ensure the game directory points to `Z:\mnt\Games\NonSteamGames\ELDEN RING\Game\eldenring.exe`.
3. Choose your desired item and enemy settings or randomize seeds.
4. Click **"Randomize items and enemies"**.
5. Close the GUI and launch the game via `Alt + g` -> **`ELDEN RING + LSFG (120 FPS)`**. ModEngine 2 automatically injects the newly generated files.

---

## 5. Fix Log — 2026-10-16 Alt+g Launch Failure

**Symptom:** Alt+g menu selection started `eldenring.exe` (visible in `pgrep` ~2s) but it died before any window appeared (gone by ~20s, log stopped at `Hooked new Vulkan device creation`).

**Bisected (all with randomizer config + LSFG + MangoHud unless noted):**

| Test | Result |
|---|---|
| Vanilla `eldenring.exe`, no ModEngine | Survives (timeout kill = still running) |
| ModEngine `config_eldenring.toml` (no randomizer) | Survives |
| ModEngine `config_eldenringrandomizer.toml`, no LSFG | Survives, reaches Vulkan present |
| Randomizer + LSFG, no `taskset` | Survives, `Initializing lsfg-vk instance` |
| Randomizer + LSFG + `taskset -c 0-11` | **Dies early, EXIT 0, no window** |
| Randomizer + LSFG + `taskset -c 0-15` | Survives |

**Root cause:** `taskset -c 0-11` ("P-core priority") in `eldenring-lsfg`. It starves Proton/wineserver helper threads during Vulkan device creation. CachyOS BORE/EEVDF + Intel HFI already prefers P-cores, so pinning bought nothing and broke the launch.

**Fix (chezmoi commit `edfe702`, local only):** run the inner launcher unpinned via `exec`; route Alt+g Elden Ring output to `/tmp/eldenring-lsfg.log` instead of `/dev/null`.

## 6. Audio Note — Default Output Policy (2026-10-16)

The launcher follows the system default output (whatever `Alt+Shift+o` selected) by leaving `PIPEWIRE_NODE`/`PULSE_SINK` unset. Forcing `sink.peace_gaming` bypassed the selected device and went silent whenever the gaming chain sat idle-suspended — manual Proton runs (no forced routing) had audio for exactly this reason.

If game audio is ever silent while other apps are fine, check `pactl get-default-sink` matches the intended device and re-select it with `Alt+Shift+o`, which moves live game streams to the new sink.

**Exception:** `cs2-launch` keeps forced `sink.peace_gaming` on purpose — competitive footsteps EQ. Do not "unify" it.

---

## 7. Randomizer GUI Crash Fix (2026-10-16)

**Symptom:** `ER Randomizer Config (GUI)` never opened; log ended with `free(): corrupted unsorted chunks` (SIGABRT) after MangoHud Vulkan lines.

**Root cause:** the game's `MANGOHUD=1` in the shared prefix `user_settings.py` leaked into the .NET Avalonia GUI and killed it — the same MangoHud-injection crash class as the game startup fix.

**Fix (chezmoi `7f253b4`):** `eldenring-randomizer-gui` backs up `user_settings.py` to `user_settings.py.gui-bak`, writes a neutral `{}`, runs the GUI, and restores on exit via trap. The game launcher regenerates the file on next boot anyway, so a missed restore self-heals.

## 8. IMCO Merge Attempt — Failed, Parked (2026-10-16)

IMCO SOTE v4.01 ships its own `regulation.bin` (Oct 2024); the randomizer ships its own. ModEngine2 loads exactly one (last mod entry wins) — verified no "ModEngine 3" with regulation merging exists (upstream repo archived 2024 at v2.1.0).

**Attempt:** randomizer's built-in "Merge other mod" pointed at ModEngine2 `imco/`. It crashed mid-roll: `NullReferenceException` in `CharacterWriter.getStat` — IMCO's older regulation lacks rows the current randomizer expects. Working `regulation.bin` was untouched (crash hit before output write); pre-merge backup kept at `randomizer/regulation.bin.pre-imco-merge`.

**Fallback (active):** `config_imco.toml` → `config_imco.toml.disabled`; launcher uses randomizer-only. IMCO files stay staged for a future solo run (re-enable the file = IMCO wins, randomizer dormant).

## 9. LSFG Multiplier Saga — 2x Verified, Stay ≤ Panel Rate (2026-10-16)

- 2x (60→120) is the verified-good setting (Church of Elleh era + tonight's clean boots).
- 4x was tried for the 165Hz panel; the attempts coincided with a black-screen stretch, but the stretch was confounded (2022 HUD gfx + erfps DirectX hook were also in play, since removed). 4x briefly rendered fine later.
- **Rule of thumb adopted:** keep generated fps ≤ panel refresh (165Hz). 3x (180) and 4x (240) overshoot into vsync-pacing chaos; 2x (120) divides cleanly. Back on 2x.
- **LSFG hot-reloads live:** editing `conf.toml` (or the lsfg-vk-ui) applies to a running game within seconds (`Configuration file has changed, reloading...`). BUT rapid successive edits once landed the layer in a `(Disabled)` state mid-game — change once, wait 10s, judge. And never toggle the UI mid-fight.
- **Config drift warning:** lsfg-vk-ui writes the live `conf.toml` directly, which then disagrees with the chezmoi template. After settling a multiplier, sync the template (`dot_config/lsfg-vk/conf.toml.tmpl`) and commit, or the next `chezmoi apply` silently reverts you. Live + template are both 2x as of `5650025`/`e7df29f`/`72bfc10`.

## 10. Double-Pick Bug — Alt+g Needed Two Tries (2026-10-16)

**Symptom:** first Alt+g pick showed only the "Launching" notification, no game; second pick worked.

**Root cause:** the notification fires before the game starts, so any repeat pick (key-repeat double-fire, or a tap while the previous session's wineserver was still shutting down) spawned a second copy that lost the prefix-lock race and died silently.

**Fix (chezmoi `9bf2c80`):**
- Single-instance guard at the top of `eldenring-lsfg`: game already up → just flip to Workspace 4 with "Already running", no second copy.
- Stale-wineserver reap before launch: a SIGKILLed session's lingering server (no game behind it) made fresh boots attach to a dead server and exit early.
- Alt+g launch log now appends timestamped entries (`/tmp/eldenring-lsfg.log`) instead of overwriting, so a failed first attempt leaves evidence.

## 11. Current Clean Baseline (2026-10-16) — Do Not Drift Without Reason

- **Launcher:** `eldenring-lsfg` → `eldenring-launch-inner`, unpinned (`exec`, no taskset), `trap '' HUP` + `nohup`, asusctl Performance→Balanced, WS4 focus, single-instance guard, stale-server reap.
- **Config:** `config_eldenringrandomizer.toml` (randomizer-only). Parked: `config_custom.toml.disabled` (hud), `config_imco.toml.disabled` (IMCO).
- **DLLs:** CameraFix only (`mod_loader_config.ini`). Out: erfps (2023 build hooks present path → black screen + kills MangoHud overlay under Proton), SkipTheIntro/Chromatic/Vignette (parked with the bad stretch, reintroduce one-by-one if wanted).
- **Graphics:** LSFG 2x + vsync pacing, MangoHud `LSFG 120 (2x)` via `user_settings.py`, audio on system default.
- **Menu:** `ELDEN RING + LSFG (120 FPS)` in Alt+g, per-launch logs appended.
