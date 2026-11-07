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

1. **Game menu (`Alt+g`):** `~/.local/bin/rofi-games` → `ELDEN RING (Stable / no LSFG)` → `eldenring-lsfg`. A separate `ELDEN RING + LSFG 4x (experimental)` entry opts in with `ENABLE_LSFG=1`.
2. **Terminal / Alt+Space desktop entry:** `eldenring-run`, which delegates to the same `eldenring-lsfg` stack. The launcher switches to workspace 4 and defaults to LSFG **off** after the 2026-11-06 session-specific 4x black-screen regression. The full non-Steam ModEngine/Proton mod stack remains active; no native Steam client is started.
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

## 6. LSFG-VK 2.0 frame-gen

- On `2.0.0-1` (pacman). Opt-in `ENABLE_LSFG=1 eldenring-lsfg` exports `LSFGVK_PROFILE="Elden Ring"`; the existing profile uses 4x, flow 0.8, Performance Mode and vsync pacing. Normal launches export `DISABLE_LSFGVK=1` for a verified stable session.
- `ENABLE_LSFG=0 eldenring-run` / the desktop `Launch without Lossless Scaling` action disables the layer through `DISABLE_LSFGVK=1`.
- Corrected 2026-11-03 validation explicitly switched Sway to workspace 4 and focused the game node before capture. BORDERLESS + randomizer + CameraFix/Pause + MapForGoblins + LSFG 4x rendered once FasterRevival was omitted; lsfg-vk reported multiplier 4, flow 0.80 and successful half-precision initialization.
- **2026-11-06 A/B regression:** Current 4x startup remained black (>99.9% black compositor captures) with FasterRevival and MangoHud both absent; same ModEngine/Pause/Camera/Map randomizer profile without LSFG immediately rendered changing frames. Keep frame generation opt-in until isolated further; the earlier 4x success is historical evidence of intermittency, not a reason to default to a black screen.
- FasterRevival v1.0.0 is independently incompatible with the current stack: full-stack/no-LSFG stayed black while the otherwise identical profile without FasterRevival rendered. Keep that DLL parked.
- v1 env (`LSFG_DLL_PATH`/`LSFG_MULTIPLIER`) is obsolete under v2; profile selection is the supported path.

## 7. MangoHud — parked after verified startup freeze

- 2026-11-03 controlled A/B testing isolated MangoHud as the startup-freeze trigger: randomizer alone, randomizer + CameraFix, and randomizer + CameraFix + LSFG rendered; adding MangoHud froze the startup presentation even without CameraFix/LSFG.
- The failing MangoHud path logs `Present mode is not supported: VK_PRESENT_MODE_FIFO_RELAXED_KHR`. Normal Elden Ring launches therefore write `user_settings = {}` and do **not** inject MangoHud.
- `Game/MangoHud.conf` and the old HUD hotkeys remain on disk for experiments only. Opt in explicitly with `ELDENRING_MANGOHUD=1 eldenring-run`; expect the current regression until retested after MangoHud/Proton changes.
- Frame pacing is owned by Elden Ring's 60 FPS base and LSFG-VK 2x/vsync, not by MangoHud.

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

- Legacy X11 launcher `~/.local/bin/cs2-launch` (xrandr 1344x1008, polybar hide, picom kill) is i3-only — segfaults under Wayland. **Untouched.**
- Wayland launcher `~/.local/bin/cs2-launch-wayland`: native Wayland SDL3 (`SDL_VIDEO_DRIVER=wayland`), `SDL_VIDEO_WAYLAND_SCALE_TO_DISPLAY=1` for 1.2× fractional scale, NVIDIA offload (`LIBVA_DRIVER_NAME=iHD`), P-core pinning `taskset -c 0-11`, `gamemoderun`, optional Gamescope 4:3 stretch (`--stretch` / `CS2_STRETCH=1`).
- KWin: `[Wayland] AllowTearing=true` in `~/.config/kwinrc`, reloaded via D-Bus.
- In-game (`cs2_video.txt`): exclusive fullscreen, 165Hz numerator/denominator.
- Steam launch options: `$HOME/.local/bin/cs2-launch-wayland %command%` (+ `--stretch` variant).

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
