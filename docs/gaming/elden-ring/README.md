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
| **LSFG-VK 2.0 (Frame Gen)** | **EXPERIMENTAL OPT-IN** | The unchanged 4x profile (`flow_scale=0.8`, Performance Mode, vsync pacing) rendered in November 3/5 tests but produced a persistent fully black frame on November 6. In a same-session controlled A/B test, `ENABLE_LSFG=0` rendered changing frames with identical randomizer/QoL DLLs. Normal launches therefore disable LSFG; use `ENABLE_LSFG=1 eldenring-lsfg` only to re-test 4x. |
| **MangoHud Hardware Monitor** | **PARKED BY DEFAULT** | 2026-11-03 A/B testing proved MangoHud injection freezes Elden Ring on the startup presentation surface under the current Proton/VKD3D stack; logs report unsupported `VK_PRESENT_MODE_FIFO_RELAXED_KHR`. Normal launches write an empty `user_settings.py`. Diagnostic-only opt-in: `ELDENRING_MANGOHUD=1 eldenring-run`. |
| **DLL Mod Loader** | **WORKING** | EldenModLoader (`dinput8.dll`) hooks on boot with `WINEDLLOVERRIDES="dinput8=b"`. |
| **Camera Fix Mod** | **WORKING** | `CameraFix.dll` disables auto-rotation and target lock camera snaps. |
| **ModEngine 2 & Randomizer** | **WORKING** | ModEngine 2 loads randomized assets dynamically from `randomizer/`. .NET 8.0 Desktop Runtime installed in prefix for Randomizer GUI. |
| **Randomizer QoL DLL stack** | **WORKING** | Managed `config_randomizer_stack.toml`: RandomizerCrashFix + Map for Goblins v2.1.6 directly through ModEngine, with CameraFix + PauseTheGame loaded after 7 seconds by `DelayedModLoader`. Faster Revival v1.0.0 is parked because it reproducibly causes the persistent black startup surface. |
| **Rofi Game Menu (`Alt + g`)** | **WORKING** | `ELDEN RING (Stable / no LSFG)` is the default; `ELDEN RING + LSFG 4x (experimental)` remains optional, with existing randomizer GUI entries retained. |

---

## 2. Mod Inventory & Directory Structure

### Mod Roster

1. **Mod Engine 2.1.0.0 + Item/Enemy Randomizer v0.12.2 — ACTIVE**
   - ModEngine: `/mnt/Games/NonSteamGames/ELDEN RING/ModEngine2/ModEngine-2.1.0.0-win64/`
   - Randomizer output: `/mnt/Games/NonSteamGames/ELDEN RING/randomizer/`
   - The Randomizer GUI owns `randomizer/config_eldenringrandomizer.toml`; the stable Linux launcher instead selects the managed `~/.config/eldenring/config_randomizer_stack.toml`, which points at the same randomized output directory and layers runtime-only DLLs around it.
   - `RandomizerCrashFix.dll` remains the first external DLL. The current `randomizer/regulation.bin` and generated event/map files remain the randomized gameplay source.

2. **Map for Goblins DLL v2.1.6 — ACTIVE**
   - Canonical DLL/config: `ModEngine2/.../natives/MapForGoblins/MapForGoblins.dll` and `MapForGoblins.ini`.
   - Official vanilla release from `VirusAlex/ERR-MapForGoblins-DLL`; DLL SHA-256 `ea287c547a5431aac332dce8ed6cb636d2397ad6d1b5dce01351ffdff3b3f8ca`.
   - Randomizer integration is enabled (`live_loot_flags`, `live_loot_labels`, `live_loot_icons`). `anonymous_loot = true` keeps randomized item identity spoiler-free while retaining useful `?` map locations. `menu_render_mode = native` avoids a separate DX/ImGui overlay on the LSFG presentation path.
   - Live verification on game v2.7.0.0 registered the map integration and mapped 7,376 randomized markers.

3. **Faster Revival v1.0.0 — PARKED**
   - Canonical DLL/config remain on disk at `ModEngine2/.../natives/FasterRevival/FasterRevival.dll` and `FasterRevival.ini`; they are no longer referenced by the managed launch profile.
   - Built from the public `ALR2310/EldenRingMods` source with the required `x86_64-pc-windows-msvc` ABI; DLL SHA-256 `8910431b347b15d8c6cf3995c173e151b0e1a8b1f5c713b22cce3f443788378b`.
   - 2026-11-03 controlled A/B testing isolated this DLL as the current black-screen trigger: the full stack remained black even with LSFG disabled, while the identical stack without FasterRevival rendered. Keep it parked until a rebuilt/newer version is separately revalidated.

4. **Fix The Camera v3.0 — ACTIVE**
   - `Game/mods/CameraFix.dll`, with `disable_camera_auto_rotate = 1` and `disable_camera_reset = 1`.
   - Loaded by the managed `DelayedModLoader` after 7 seconds rather than by EldenModLoader during early process startup.

5. **PauseTheGame — ACTIVE**
   - `Game/mods/PauseTheGame.dll`.
   - Loaded alongside CameraFix by `DelayedModLoader` after startup; verified mapped in the live non-Steam randomizer session.

6. **Elden Mod Loader v3.2 — BOOTSTRAP ONLY**
   - `Game/dinput8.dll` remains enabled through `WINEDLLOVERRIDES="dinput8=b"`.
   - `Game/mod_loader_config.ini` intentionally has an empty `[loadorder]`; its source of truth is `~/.config/eldenring/mod_loader_config.ini`, synchronized by `eldenring-launch-inner` when bytes differ. This prevents duplicate DLL injection because the managed ModEngine stack owns all active runtime DLLs.

7. **DelayedModLoader — ACTIVE HELPER**
   - Source: `~/.local/share/chezmoi/dot_local/lib/eldenring/delayed_mod_loader.c`.
   - Live DLL: `ModEngine2/.../natives/DelayedModLoader/DelayedModLoader.dll`.
   - ModEngine loads this helper at process initialization; it waits 7 seconds, then loads CameraFix and PauseTheGame after Elden Ring has completed enough startup for their scans/hooks.

8. **LSFG-VK 2.0 — INSTALLED, OPT-IN**
   - `~/.config/lsfg-vk/conf.toml`: the historical 4x profile remains intact (`multiplier=4`, `flow_scale=0.8`, Performance Mode, vsync pacing) for optional re-testing, but LSFG is **disabled by default** after the 2026-11-06 black-screen regression. Previous November 3/5 launches rendered with 4x; that does not establish reliability on the current session.

### Parked / not in the active profile

- RemoveChromaticAberration, RemoveVignette and SkipTheIntro remain on disk but are not loaded.
- ERFPS / First Person Souls remains parked because its present-path hook previously black-screened under Proton.
- Minimal HUD / My HUD Tweaks remain in the disabled custom ModEngine profile.
- IMCO remains disabled because its old `regulation.bin` could not be merged safely with the current randomizer.

### Candidate QoL mods not installed

- **Transmogrify Armor 2.4.14:** official source was evaluated, but its pinned Windows-oriented `elden-x` dependency does not cross-build cleanly with the Linux clang-cl/MSVC compatibility toolchain (`std::span` over forward-declared game-state types). Do not patch those game-memory structures merely to force a Linux build; install the official Windows/Nexus binary when available locally.
- **Adaptive Bar Scaling compatibility port:** the current 1.17 / exe 2.7.0.0 build is distributed through Nexus, but no corresponding public source was found in the author's repositories and Nexus file delivery requires authenticated binary access. No mirror was substituted.
- **Glorious Merchant:** intentionally not installed.

---

## 3. Launcher Architecture & Orchestration

### Main Game Launcher (`~/.local/bin/eldenring-lsfg` → `eldenring-launch-inner`)
- **No gamescope, no CPU pinning:** Proton (`proton-cachyos-slr`, ntsync) runs ModEngine2 directly on Sway Workspace 4. Do NOT add `taskset -c 0-11` — see §5, it kills the launch.
- **Inner supervision:** `eldenring-launch-inner` runs `modengine2_launcher.exe` in the foreground, then `wineserver -w`, so the supervisor lives for the whole session and `asusctl` restores Balanced only after exit.
- **SIGHUP-proof:** `trap '' HUP` in both scripts + `nohup` in `rofi-games`, so closing the Alt+g menu can't kill the game.
- **Workspace Navigation:** Automatically activates **Workspace 4** upon launch.
- **Non-Steam launch:** the game is launched directly through the dedicated Proton prefix and ModEngine 2. `SteamAppId`/`SteamGameId` plus `STEAM_COMPAT_*` remain compatibility metadata only; the launcher does not start, wait for, or depend on the native Steam desktop client.
- **Managed randomizer/QoL profile:** `~/.config/eldenring/config_randomizer_stack.toml` is copied into ModEngine2 only when changed. It keeps the randomizer-generated directory intact while loading RandomizerCrashFix, DelayedModLoader and Map for Goblins exactly once. FasterRevival remains installed but is intentionally omitted after the 2026-11-03 black-screen A/B.
- **DLL ownership:** `~/.config/eldenring/mod_loader_config.ini` deliberately leaves EldenModLoader's `[loadorder]` empty. CameraFix/Pause are loaded only by DelayedModLoader; Map for Goblins is loaded only as a ModEngine external DLL. FasterRevival is parked. This avoids both duplicate injection and the verified black-screen regression.
- **MangoHud default:** disabled. `eldenring-launch-inner` writes `user_settings = {}` because MangoHud is the verified 2026-11-03 startup-freeze trigger. For diagnostics only, `ELDENRING_MANGOHUD=1 eldenring-run` restores the per-game `Game/MangoHud.conf` injection; do not make that the default until the present-mode regression is re-tested.
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
5. Close the GUI and launch via `Alt + g` -> **`ELDEN RING (Stable / no LSFG)`**. ModEngine 2 loads the newly generated files and the existing QoL DLLs. The separate LSFG 4x entry is experimental.

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

## 9. LSFG 4x Verified Profile for 165 Hz (corrected 2026-11-03)

- The active profile is 4x with `flow_scale = 0.8`, `performance_mode = true`, `pacing_mode = "vsync"`, `override_present_mode = true`, and `preserve_swapchain_image_count = false`.
- The black-screen diagnosis was initially confounded by captures taken while the Elden Ring workspace was not visible. The corrected test explicitly switched Sway to workspace 4, focused the `ELDEN RING™` node, and verified `visible=true` / `focused=true` before each capture.
- With FasterRevival omitted, the original BORDERLESS graphics mode plus LSFG 4x progressed from a 99.99% black startup frame to two distinct rendered frames. lsfg-vk reported multiplier 4, flow scale 0.80, Performance Mode enabled, and successful half-precision initialization.
- Controlled no-LSFG testing separately showed that the full stack containing FasterRevival can remain black, while the same randomizer + DelayedModLoader + MapForGoblins stack without FasterRevival renders. The DLL is therefore the actual current regression and is parked.
- `preserve_swapchain_image_count = true` remains a compatibility quirk rather than a performance optimization; keep it off unless a future regression proves it necessary.
- An NVIDIA-only `VK_DRIVER_FILES` test and a Vulkan-loader driver filter did not provide a useful fix and are not persisted. The installed stable `lsfg-vk 2.0.0-1` also has no supported per-profile `gpu` key.
- The chezmoi template is authoritative. If `lsfg-vk-ui` changes the live file, synchronize only a verified profile back into `dot_config/lsfg-vk/conf.toml.tmpl` before a later `chezmoi apply` can revert it.

### 2026-11-05 runtime source/live drift repair

The local chezmoi working tree already contained the corrected (currently untracked) `dot_config/eldenring/config_randomizer_stack.toml` without FasterRevival, but `~/.config/eldenring/config_randomizer_stack.toml` and its copy inside ModEngine still contained `natives/FasterRevival/FasterRevival.dll`. The running launcher re-copied the **stale live profile** into ModEngine, reintroducing the known black-screen regression. Re-synchronized the source to both live Elden Ring files (`config_randomizer_stack.toml`, `mod_loader_config.ini`); the next normal launcher invocation copied the corrected profile into ModEngine automatically. The active external DLL list is now exactly RandomizerCrashFix, DelayedModLoader and MapForGoblins. FasterRevival binaries remain installed but are not injected.

Validation: the normal `eldenring-lsfg` / Proton / ModEngine launch started `eldenring.exe`, initialized LSFG-VK 2.0.0 at 4x with `flow_scale=0.8` and Performance Mode, and on **visible/focused workspace 4** successive compositor captures changed from nearly black to non-black rendered frames with distinct hashes. The game process was still alive after 128 seconds. Synced the older live 2x labels in `eldenring-lsfg` and `rofi-games` from their already-correct source versions (only text/comments changed). No native Steam client, randomizer content, game saves or unrelated mods were modified. Chezmoi's targeted apply was blocked by an unrelated `nvim.desktop` source/template collision, so only the confirmed source-to-live Elden Ring files were installed directly after a diff and with `/tmp` backups; reconcile that collision separately before relying on a future broad `chezmoi apply`.

### November 6, 2026 — Intermittent LSFG black presentation reproduced and isolated

On the live RTX 5050 / Sway session, the current `eldenring.exe` stayed in a fullscreen, visible, focused black window for more than two minutes despite using the **correct** managed 3-DLL randomizer stack; `FasterRevival` was absent, and MangoHud's Proton `user_settings.py` was empty. Two compositor captures separated by four seconds were each 99.98% black, and the game ignored a normal WM close. Its mapped modules contained LSFG-VK, RandomizerCrashFix, DelayedModLoader, MapForGoblins, CameraFix, and PauseTheGame. ModEngine logs were normal and matched the earlier successful launch.

After targeted termination of only the hung game (no saves or randomizer files changed), `swaymsg exec env ENABLE_LSFG=0 ~/.local/bin/eldenring-lsfg` restarted the **same** ModEngine profile. The environment explicitly contained `DISABLE_LSFGVK=1`, LSFG was absent from the process's mapped libraries, and the focused workspace-4 image rendered; two captures seven seconds apart were about 23% black with substantially different actual frames (average channel difference 3.187). This isolates LSFG-enabled presentation as the current session-specific trigger but does **not** prove which LSFG-VK setting or driver interaction is responsible. No global LSFG profile, NVIDIA driver, randomizer assets, prefixes, or saves were altered.

Mitigation: default `${ENABLE_LSFG:-0}` in `eldenring-lsfg`; the menu now exposes separate stable no-LSFG and experimental 4x choices. Launch command `ENABLE_LSFG=1 eldenring-lsfg` retains the old configuration on demand. Preserve the earlier verified 4x evidence as historical, not current reliability. Re-test experimental 4x separately before restoring it as the default; do not disturb a working game just to reproduce the intermittent bug.

## 10. Double-Pick Bug — Alt+g Needed Two Tries (2026-10-16)

**Symptom:** first Alt+g pick showed only the "Launching" notification, no game; second pick worked.

**Root cause:** the notification fires before the game starts, so any repeat pick (key-repeat double-fire, or a tap while the previous session's wineserver was still shutting down) spawned a second copy that lost the prefix-lock race and died silently.

**Fix (chezmoi `9bf2c80`):**
- Single-instance guard at the top of `eldenring-lsfg`: game already up → just flip to Workspace 4 with "Already running", no second copy.
- Stale-wineserver reap before launch: a SIGKILLed session's lingering server (no game behind it) made fresh boots attach to a dead server and exit early.
- Alt+g launch log now appends timestamped entries (`/tmp/eldenring-lsfg.log`) instead of overwriting, so a failed first attempt leaves evidence.

## 11. Current Clean Baseline (2026-11-03) — Do Not Drift Without Reason

- **Launcher:** `eldenring-lsfg` → `eldenring-launch-inner`, unpinned (`exec`, no taskset), `trap '' HUP` + `nohup`, asusctl Performance→Balanced, WS4 focus, single-instance guard and stale-server reap; no native Steam client startup or readiness gate.
- **Config:** managed `~/.config/eldenring/config_randomizer_stack.toml` points at the current Randomizer v0.12.2 output and loads RandomizerCrashFix + DelayedModLoader + Map for Goblins v2.1.6. Faster Revival v1.0.0 is installed but parked after the verified black-screen regression. Also parked: `config_custom.toml.disabled` (HUD files), `config_imco.toml.disabled` (IMCO).
- **DLL ownership:** Map for Goblins loads directly through ModEngine; DelayedModLoader loads CameraFix and PauseTheGame after 7 seconds. Managed `mod_loader_config.ini` has an empty `[loadorder]`, preventing duplicate injection. FasterRevival, ERFPS and SkipTheIntro/Chromatic/Vignette remain parked.
- **Graphics:** verified LSFG 4x profile (`flow_scale=0.8`, Performance Mode, `preserve_swapchain_image_count=false`) with vsync pacing against the 165.004 Hz panel. MangoHud is **off by default**; `user_settings.py` is neutral. Audio follows the system default.
- **Menu:** Alt+g defaults to `ELDEN RING (Stable / no LSFG)` and includes an explicit experimental LSFG 4x entry. The Alt+Space desktop entry already starts without LSFG; both share `eldenring-run`/`eldenring-lsfg` and the same mods.

## 12. MangoHud Startup Freeze — Fixed 2026-11-03

**Symptom:** the non-Steam randomizer launch created an `ELDEN RING™` fullscreen window but remained on a black/white presentation surface indefinitely. The process stayed alive at high CPU, so this was not a crash.

**A/B result on the same prefix, Proton runner, randomizer seed and game binary:**

| Stack | Result |
|---|---|
| Vanilla `eldenring.exe`, no ModEngine/overlays | Renders |
| ModEngine 2 with empty diagnostic config | Renders |
| Randomizer + `RandomizerCrashFix.dll`, no DLL loader/overlays | Renders |
| Randomizer + CameraFix/EldenModLoader, no MangoHud | Renders |
| Randomizer + **MangoHud**, no CameraFix or LSFG | **Freezes on startup surface** |
| Randomizer + CameraFix + MangoHud, no LSFG | **Freezes on startup surface** |
| Randomizer + CameraFix + LSFG 2x, **no MangoHud** | Renders; LSFG reaches `Initializing lsfg-vk instance with half precision enabled` |

MangoHud logs on the failing path repeatedly report `Present mode is not supported: VK_PRESENT_MODE_FIFO_RELAXED_KHR`. The verified root cause is MangoHud injection itself under the current Elden Ring Proton/VKD3D presentation stack; the unsupported-present warning is retained as the strongest correlated runtime clue, not treated as a standalone proof of MangoHud internals.

**Fix:** normal launch writes a neutral `user_settings.py` and does not inject MangoHud. `ELDENRING_MANGOHUD=1` is retained only as an explicit diagnostic opt-in. LSFG, RandomizerCrashFix, CameraFix, ModEngine 2, and the Blackwell VKD3D flags are unchanged. Final live validation through the real shared launcher produced changing compositor frames, an active RTX 5050 Vulkan workload, and a healthy LSFG 2x initialization.
## 13. FasterRevival Black-Screen Regression — Fixed 2026-11-03

**Symptom:** the real shared launcher could leave `ELDEN RING™` on a persistent black surface even though the process stayed alive and LSFG initialized normally.

**Controlled A/B, same Proton prefix and game data:**

| Stack | Result |
|---|---|
| ModEngine empty profile, LSFG disabled | Renders |
| Randomizer + RandomizerCrashFix, LSFG disabled | Renders |
| Randomizer + DelayedModLoader + MapForGoblins, LSFG disabled | Renders |
| Full managed stack including FasterRevival, LSFG disabled | **Black screen** |
| Randomizer + DelayedModLoader + MapForGoblins + LSFG 4x, FasterRevival omitted | **Renders** |

The final 4x verification explicitly switched Sway to workspace 4 and focused the game node before capture (`visible=true`, `focused=true`). Captures progressed from the normal black startup frame to distinct visible rendered frames while lsfg-vk reported multiplier 4, flow scale 0.80, Performance Mode enabled and successful half-precision initialization. CameraFix, PauseTheGame, MapForGoblins and RandomizerCrashFix were all mapped in the process; FasterRevival was absent.

**Fix:** remove FasterRevival v1.0.0 from managed `config_randomizer_stack.toml`. Keep its DLL and INI on disk for future rebuild/version testing, but do not inject it in normal launches. LSFG 4x remains enabled with the verified profile.
