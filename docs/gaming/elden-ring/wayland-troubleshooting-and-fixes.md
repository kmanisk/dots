# Elden Ring on CachyOS — Issue-by-Issue Fix Log

**Date:** September 16–17, 2026
**Author / Maintained by:** manisk
**System:** ASUS TUF Gaming F16 (Intel i5-13450HX + NVIDIA RTX 5050 Mobile, Blackwell `sm_120`)
**Sessions:** i3wm (X11, primary) · KDE Plasma 6 Wayland (fallback) · Hyprland (past)
**Storage:** `/mnt/Games/Games/ELDEN RING/Game/` · Prefix: `~/.local/share/Steam/steamapps/compatdata/2703476723`
**Runner:** `~/.local/bin/eldenring-run` (Proton Experimental, Prime offload, Blackwell VKD3D flags)

---

## 1. Vanilla-Wine crash (`0x0000000000000000` null read)

- **Symptom:** Double-clicking `eldenring.exe` in Dolphin/Thunar → `winedbg` dialog, `Exception c0000005`, page fault on read of null. Full trace: `~/Documents/backtrace.txt`.
- **Root cause:** File managers invoke system Wine (`wine-11.17`), which has no VKD3D-Proton (DX12), no prefix, no GPU offload. The module list proves it: Wine's `wined3d`/`dxgi`/`d3d12` instead of vkd3d-proton.
- **Rule (invariant): never run the exe directly.** Safe methods (§4) only.
- **Guardrail:** Thunar right-click → `Play via Proton (eldenring-run)` custom action in `~/.config/Thunar/uca.xml`, pattern-matched to `eldenring.exe` only.

## 2. Steam `Permission denied` on launch

- **Root cause:** `pressure-vessel`/`pv-adverb` needs `+x` on the binaries.
- **Fix (verify, don't assume):** `ls -la` must show `-rwxr-xr-x` on `eldenring.exe` and `start_protected_game.exe`; if not, `chmod +x` both.

## 3. Split Steam prefix + save recovery

- **Root cause:** Saves lived in non-Steam shortcut prefix `4121912863`; scripts pointed at official AppID `1245620` (missing dir).
- **Sep 16, ~21:41 incident:** Adding the game as a non-Steam shortcut minted a **new** ID `2703476723` and Steam **deleted** `4121912863`. Every launcher failed at once with `FileNotFoundError: .../1245620/pfx.lock` in `setup_prefix`.
- **Fix:** Saves recovered from `~/EldenRing_Saves_Backup/.../ER0000.sl2` (md5-verified) into the new prefix (`.../AppData/Roaming/EldenRing/76561197960271872/`). Home snapper snapshots only go back to Sep 14 — the manual backup was the rescuer.
- **Current mapping:** `eldenring-run` → `STEAM_COMPAT_DATA_PATH=.../compatdata/2703476723`; `1245620` symlinked to `2703476723`.
- **Lesson:** After any Steam shortcut add/remove, check `ls .../compatdata/` first. Keep backing up `EldenRing_Saves_Backup/`.
- **Diagnosis rule:** Run `eldenring-run` in a terminal and read stderr — never silent-guess.

## 4. Launch methods (all verified working)

1. **Rofi (`Alt+g`):** `~/.local/bin/rofi-games` — `ELDEN RING` (Proton, `DISABLE_LSFGVK=1`, MangoHud), `Steam library`, `Kill game`. (History: the original `elden-ring-launcher` ran bare `prime-run "$@"` with no Proton — silent exit with no args, vanilla-Wine crash with exe arg. Fixed by delegating to `eldenring-run`, later removed with the LSFG entries.)
2. **Terminal:** `eldenring-run` (auto-switches to ws4, fullscreen, border none per i3 game rules).
3. **Thunar:** right-click → Play via Proton (§1).
4. **Steam non-Steam shortcut:** Target `.../Game/eldenring.exe`, Start In `.../Game/`, Compatibility forced **Proton Experimental**, overlay OFF. Working launch options (§5).
5. **KDE launcher:** `~/.local/share/applications/eldenring.desktop` (fallback session — KDE Plasma itself uninstalled Sep 17, i3-only now).
- Note: direct-`exe` launches skip the EAC launcher = **offline mode**. Online needs `start_protected_game.exe` via Steam runtime.

## 5. Steam container pitfalls (learned the hard way)

- **No host-side wrapper scripts in launch options.** `prime-run` (`~/.local/bin`), `gamemoderun` (missing `libgamemode.so`), and CachyOS `game-performance` (exits 1, no `powerprofilesctl` in container) are all unresolvable inside pressure-vessel/soldier — the chain dies before Proton starts: black window, instant close, **no Proton log at all**. Inline env only. Working options:
  ```text
  PRESSURE_VESSEL_FILESYSTEMS_RW="/mnt/Games" VKD3D_CONFIG="no_upload_hvv,force_host_cached" PROTON_ENABLE_NVAPI=0 __NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only __GLX_VENDOR_LIBRARY_NAME=nvidia %command%
  ```
  Verified live: `reaper → pressure-vessel → proton waitforexitandrun → eldenring.exe`, sustained play, clean teardown.
- **Steam re-syncs launch options/overlay from its own store on every start.** CLI edits to `shortcuts.vdf`/`localconfig.vdf` are lost — change them in the GUI (Properties → General/Controller). (Overlay OFF for this shortcut.)
- **`steam://rungameid/<id>` does NOT launch non-Steam shortcuts** (`Unknown GameID type`, silent no-op). Works for real AppIDs (tested with GTA IV `12210`).
- Absence of `~/steam-<appid>.log` with `PROTON_LOG=1` set = death before Proton init = launch-chain problem, not a game problem.

## 6. LSFG-VK 2.0 frame-gen (dormant)

- On `2.0.0-1` (pacman). Removed v1-era shadow copies (`~/.local/lib/liblsfg-vk-layer*.so`, `~/.local/bin/lsfg-vk-{cli,ui}`); `lsfg-vk-cli healthcheck` clean; tools are `/usr/bin/lsfg-vk-*`.
- Profile `Elden Ring 2x` in `~/.config/lsfg-vk/conf.toml` (2x, flow 1.0, vsync pacing) has **no `active_in`** — activates only via `LSFGVK_PROFILE` env, so nothing triggers it today.
- v1 env (`ENABLE_LSFG`/`LSFG_DLL_PATH`/`LSFG_MULTIPLIER`) is dead under v2; v2 honors `LSFGVK_PROFILE`, `DISABLE_LSFGVK=1`, `LSFGVK_CONFIG`, `LSFGVK_ENV=1`.
- Test runners removed (Sep 17 cleanup). Rofi is LSFG-free.
- Notes for future use: v2 pacing is Vsync-only (cap base rate ~40 in-game or `DXVK_CONFIG="dxgi.maxFrameRate=40"`); bad frametimes → `ENABLE_GAMESCOPE_WSI=0`; old log spam `(lsfg-vk) [ERROR]: Invalid profiles section` was the v1 conf lacking profiles — resolved by the v2 config.

## 7. FPS cap (MangoHud)

- **Symptom:** FPS uncapped past 60. **Cause:** global MangoHud `fps_limit=120,60,165` defaults to the first entry (120) for every rofi-launched game.
- **Fix:** per-game `~/.config/MangoHud/eldenring.exe.conf` with `fps_limit=60` (auto-picked by exe name, no launcher change). F8 still cycles; F9 toggles HUD.

## 8. Input-focus FPS drops — RESOLVED, stable 60 FPS

- **Symptom:** 60 FPS unfocused, 20–25 FPS the moment input resumes; GPU stuck at 20–30% (starved render thread, not graphics load).
- **Primary cause: CPU power management.** Governor `powersave` ×16 starved the input/render thread (ramp latency per keystroke). Switching to governor `performance` + `asusctl Performance` fixed it instantly mid-session — no relaunch needed.
- **Auto power profile:** `eldenring-run` sets Performance + `performance` on launch (AC only; battery stays Balanced) and restores Balanced/`powersave` on exit via `trap ... EXIT INT TERM` — no `exec` on the proton call, deliberately, so the trap fires. Covers rofi/Thunar/terminal; Steam-direct bypasses the script (set Performance manually before Play there).
- **Thermal guard:** Performance pinned P-cores at 4.4–4.6GHz → CPU 95°C at 34% load (shared heatpipes with 73°C dGPU). Script also caps `scaling_max_freq` to 3.8GHz during play (no FPS cost at 60fps, ~20°C+ drop observed) and restores 4.6GHz on exit.
- **Contributors:** mouse confirmed 1000Hz (`bInterval=1`, HyperX Pulsefire Core) → capped to 500Hz via `usbhid.mousepoll=2` (live + GRUB-persisted with snapper snapshot; needs replug/reboot). i3 `for_window [title="ELDEN RING™"] fullscreen enable` stops pointer-boundary/focus event spam.
- **Kept `VKD3D_CONFIG="no_upload_hvv,force_host_cached"`** against advice to drop it: `dmesg` shows NVRM `NV_ERR_NO_MEMORY` failures on driver 610 without these flags. Do not remove before the §10 driver upgrade.
- Steam Input disable: GUI only (Properties → Controller); storage not safely hand-editable.
- GPU clock lock (`nvidia-smi -lgc`, `-rgc`) declined for daily use — laptop thermals.

## 9. CS2 Wayland setup (separate game, kept intact)

- Consolidated Wayland launcher `~/.local/bin/cs2-launch`: native Wayland SDL3 (`SDL_VIDEO_DRIVER=wayland`), `SDL_VIDEO_WAYLAND_SCALE_TO_DISPLAY=1` for 1.2× fractional scale, NVIDIA offload (`LIBVA_DRIVER_NAME=iHD`), P-core pinning `taskset -c 0-11`, `gamemoderun`, optional Gamescope 4:3 stretch (`--stretch` / `CS2_STRETCH=1`).
- KWin: `[Wayland] AllowTearing=true` in `~/.config/kwinrc`, reloaded via D-Bus.
- In-game (`cs2_video.txt`): exclusive fullscreen, 165Hz numerator/denominator.
- Steam launch options: `$HOME/.local/bin/cs2-launch %command%` (+ `--stretch` variant).

## 10. Environment watch-items

- **NVIDIA driver 610 SW Power Cap:** `nvidia-smi` reports `SW Power Cap: Active` on `610.57.04-1` (downgraded during GTA IV testing). Upgrade path: CachyOS `linux-cachyos-nvidia-open` (`615.71.09-1`) — with snapper snapshot first. Re-evaluate VKD3D flags + NVRM OOMs after.
- **NVRM `Out of memory` dmesg warnings** around launch (non-fatal with current mitigations).

## 11. Maintenance rules

- Back up `~/EldenRing_Saves_Backup/` (only reliable save rescue — §3).
- Before Steam shortcut add/remove: note `compatdata/` IDs; after: verify and repoint.
- Before `pacman -Syu`/installs: snapper snapshot (per system rules); never `pacman -Sy`.
- One-shot diagnostics: `PROTON_LOG=1` in launch options → `~/steam-<appid>.log`; remove after (34MB per session).
- `killgame`/`Alt+g` → Kill game for hung processes; `~/.local/bin/killgame` also restores display/polybar.
- i3 game rules live in `~/.config/i3/config` (~line 362): ws4 assign, tiled, border none + `ELDEN RING™` fullscreen.
