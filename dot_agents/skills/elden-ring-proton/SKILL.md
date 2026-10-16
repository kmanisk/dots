---
name: elden-ring-proton
description: Launch configuration, Proton prefix handling, and troubleshooting guidelines for Elden Ring on CachyOS with KDE Plasma 6 Wayland and RTX 5050 Mobile.
---

# Elden Ring Proton & Wayland Runtime Guide

## Context & Machine Architecture
- **Host:** ASUS TUF Gaming F16 (i5-13450HX + RTX 5050 Mobile Blackwell `sm_120`)
- **Session:** KDE Plasma 6 (Wayland) + KWin (`kwin_wayland`)
- **Storage:** `/mnt/Games/Games/ELDEN RING/Game/`
- **Prefix:** `/home/manisk/.local/share/Steam/steamapps/compatdata/4121912863` (symlinked from `1245620`)

## Invariants & Critical Rules
1. **Never run `eldenring.exe` through system Wine:**
   - Double-clicking the `.exe` in file managers triggers vanilla Wine, which lacks VKD3D-Proton (DirectX 12 translation) and EAC bypass, resulting in `page fault on read access to 0x0000000000000000`.
   - Always run through Steam, `eldenring-run`, or `eldenring.desktop`.
2. **Binary Executable Permissions:**
   - Linux Steam container runtime (`pressure-vessel` / `pv-adverb`) requires `+x` on `eldenring.exe` and `start_protected_game.exe`. If missing, Steam fails with `Permission denied`.
3. **Blackwell (RTX 50-series) VKD3D Variables:**
   - Must set `VKD3D_CONFIG="no_upload_hvv,force_host_cached"`
   - Must set `PROTON_ENABLE_NVAPI=0` to prevent memory alignment panics on Blackwell mobile silicon.
4. **NVIDIA Offload:**
   - `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only`
5. **Lossless Scaling (LSFG-VK / 2x Frame Gen) — [WORKING]:**
   - Profile `Elden Ring` configured in `~/.config/lsfg-vk/conf.toml` with `multiplier = 2`, `pacing_mode = "vsync"`.
   - Generates smooth 120 FPS target from 60 FPS base engine.
   - Run via `eldenring-lsfg` inside `gamescope --mangoapp -W 1920 -H 1200 -w 1920 -h 1200 -f -r 165`.
6. **Modding Architecture:**
   - EldenModLoader (`dinput8.dll`) hooks via `WINEDLLOVERRIDES="dinput8=b"` to load `Game/mods/CameraFix.dll`, `erfps.dll`, etc.
   - ModEngine 2 (`ModEngine2/ModEngine-2.1.0.0-win64`) dynamically injects modded game files.
   - .NET 8.0 Desktop Runtime installed in prefix `2703476723` enables `EldenRingRandomizer.exe` and `FogMod.exe`.

## 7. Randomizer Integration Workflows

### A. Item & Enemy Randomizer + Fog Gate Randomizer
Both randomizers are developed by thefifthmatt and are designed to work together.
- **Directories:**
  - Item & Enemy Randomizer: `/mnt/Games/NonSteamGames/ELDEN RING/randomizer/`
  - Fog Gate Randomizer: `/mnt/Games/NonSteamGames/ELDEN RING/fog/`
- **Launchers:**
  - `eldenring-randomizer-gui` (Item & Enemy Randomizer GUI)
  - `eldenring-fog-gui` (Fog Gate Randomizer GUI)
  - Both accessible directly in `rofi-games` (`Alt + g`).
- **Integration Sequence (Strict Order):**
  1. Open **Item & Enemy Randomizer** (`eldenring-randomizer-gui`).
  2. Under **Misc Options**, check **"Unrestricted item placement for Fog Gate Randomizer"**. (If planning Dungeon Crawl mode, also check "Dungeon Crawl mode in Fog Gate Randomizer").
  3. Ensure **"Merge other mod"** is completely blank in Item Randomizer.
  4. Click **"Randomize items and enemies"**.
  5. Open **Fog Gate Randomizer** (`eldenring-fog-gui`).
  6. Click **"Select game exe"** and select `Z:\mnt\Games\NonSteamGames\ELDEN RING\Game\eldenring.exe`.
  7. In Fog Gate Randomizer, click **"Merge other mod"** -> **"Select toml file"** -> choose `config_eldenringrandomizer.toml` from the randomizer folder.
  8. Select your Fog Gate options (World Shuffle or Dungeon Crawl) and click **"Randomize!"**.
  9. Fog Gate Randomizer outputs `config_eldenringfogrando.toml`, which ModEngine2 (`eldenring-launch-inner`) automatically detects and prioritizes to load `fog` first, `randomizer` second, and base game third.

### B. Summon Randomizer (Future Roadmap)
- **Archive:** `~/Downloads/Elden Ring Summon Randomizer v1.0.8-982-1-0-8-1731873377.zip`
- **Target Runtime:** .NET 8.0 Desktop Runtime (already present in prefix `2703476723`).
- **Function:** Replaces Spirit Ash summons (`BuddyParam`, `NpcParam`) with arbitrary boss and enemy entities.
- **Param Conflict Invariant:**
  Because Summon Randomizer modifies `BuddyParam` and `EquipParamGoods` directly in `regulation.bin`, combining it with Item/Enemy Randomizer requires either:
  1. Merging the modified `regulation.bin` params using SoulsFormats / DSMapStudio param CSV export/import, OR
  2. Running Summon Randomizer on the already randomized `regulation.bin` output so both enemy/item tables and summon tables coexist without param overwrite.
