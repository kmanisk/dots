# Bloodborne (bbport Windows Port) on CachyOS / Sway

This document records the architecture, Proton integration, configuration, and launch protocol for Bloodborne (bbport Windows port by Supermedo) on this workstation.

## 1. Overview and Architecture

- **Port**: Supermedo's Bloodborne Windows port (`bloodborne_pc`), derived from `bbport` and `shadPS4`.
- **Location**: `/mnt/Games/NonSteamGames/New Folder/Bloodborne/bbport-windows` (symlinked as `/mnt/Games/NonSteamGames/Bloodborne`).
- **Runner**: `GE-Proton11-7-x86_64` (Proton Experimental fallback).
- **Proton Prefix**: `~/.local/share/Steam/steamapps/compatdata/bloodborne`.
- **Target Executables**:
  - `Play Bloodborne.exe`: Direct launch using saved settings (runs `run.py` -> `bin/bb-probe.exe`).
  - `Bloodborne.exe`: Graphical launcher for settings, patch toggles, and updates.

## 2. Configuration Contract

The launcher and runtime read configuration from two files:
1. `bbport.ini` (located in `bbport-windows/`):
   - `upscaler=dlss` (NVIDIA RTX 5050 Mobile hardware DLSS).
   - `output_res=1920x1080` (or `1920x1200` internal panel mode).
   - `preset=1` (Quality x1.5).
   - `quit_to_desktop=1`.
2. `settings.json` (located in Proton prefix `%APPDATA%\bbport-launcher\settings.json`):
   - Maps `game_dir` to `Z:\mnt\Games\NonSteamGames\New Folder\Bloodborne\game`.
   - Flags `setup_done=true`, `fullscreen=true`, `fps_mode="uncap"`.

## 3. Launch Scripts, MangoHud, and Alt+G Menu

- **Wrapper**: `~/.local/bin/bloodborne-run` (source of truth: `~/.local/share/chezmoi/dot_local/bin/executable_bloodborne-run`).
  - Switches automatically to Sway Workspace 4 (`swaymsg "workspace number 4"`).
  - Sets Asus performance profile (`asusctl profile set Performance`).
  - Applies NVIDIA Blackwell/dGPU environment rules.
  - MangoHud performance telemetry enabled via `export MANGOHUD=1` and `~/.config/MangoHud/bb-probe.exe.conf` (`Alt+3` toggles overlay, `Alt+4` cycles font presets).
  - Supports `--config` / `-c` to open `Bloodborne.exe` GUI instead of `Play Bloodborne.exe`.
- **Menu**: Bound to `Alt+G` via `~/.local/bin/rofi-games`:
  - `Bloodborne (bbport)` -> runs `bloodborne-run`.
  - `Bloodborne Settings (GUI)` -> runs `bloodborne-run --config`.

## 4. Generic Non-Steam Proton Automation (proton-add-game)

A reusable fish function and wrapper script `proton-add-game` is installed at:
- Fish function: `~/.config/fish/functions/proton-add-game.fish`
- Runner engine: `~/.local/bin/proton-add-game`
- Dynamic registry: `~/.config/rofi/custom-games.list`

Usage:
```fish
proton-add-game <path-to-folder-or-exe> [Optional Game Title]
```
The utility automatically:
1. Detects the primary game `.exe` (filtering installers, uninstalls, crash handlers, redists).
2. Generates an isolated Proton prefix under `~/.local/share/Steam/steamapps/compatdata/<slug>`.
3. Creates an optimized standalone runner in `~/.local/bin/<slug>-run` with NVIDIA dGPU offload, Asus Performance power profile, MangoHud telemetry, and Sway Workspace 4 auto-focus.
4. Registers the title dynamically in `~/.config/rofi/custom-games.list` so it immediately appears in the `Alt+G` menu without manual edits.

## 5. Game Dump Data Requirement

The game executable expects a decrypted PS4 Game of the Year dump (`CUSA03173`, v1.09) under `game/`. Complete assets require the full `dvdroot_ps4/` hierarchy:
- `action`, `chr`, `event`, `font`, `map`, `menu`, `msg`, `mtd`, `other`, `param`, `paramdef`, `parts`, `remo`, `script`, `sfx`, `shader`, `sound`, `system`.
Missing directories (e.g., if an archive extraction was interrupted) will cause `bb-probe.exe` to fail on asset load (`/app0/dvdroot_ps4/menu/...`).
