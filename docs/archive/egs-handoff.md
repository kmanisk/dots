# AI Handover — CachyOS/Sway session context (Oct 2026)

## Machine
ASUS TUF F16 · i5-13450HX + RTX 5050 Mobile · CachyOS, Sway/Wayland, 1920x1200@165Hz.
Package manager: pacman/paru. Dotfiles: chezmoi (`~/.local/share/chezmoi`, repo `kmanisk/dots`, branch master).
Skills (already in agent context): 60pct-keyboard-workflow, cachyos-performance,
elden-ring-proton, emacs-ide-performance, gta-iv-proton, waydroid-cachyos-root,
intel-drm-ctm-vibrance. Standing rule: check `~/docs` for skills/MCP info when needed.

## Hard rules (from AGENTS.md)
- Snapshot via snapper BEFORE `pacman -Syu`/install/remove. Never `pacman -Sy`.
- No secrets/tokens in files or commands. rclone.conf-style tokens → `chezmoi add --encrypt`.
- Sway changes live in `~/.config/sway/config.d/*.conf` submodules (14-line index file).
  Every sway change: `sway -C` + keybind collision audit + `swaymsg reload` before reporting done.
- Targeted file reads only (token efficiency). Chezmoi-track everything (`re-add`/`add`).
- Zero-daemon philosophy: one-shot scripts, no resident processes.
- MangoHud.conf is immutable, never touch it.

## Rofi system theme (done, stable)
One theme: `~/.config/rofi/system.rasi` (VictorMono Nerd Font Mono, 0 radius,
dynamic colors from `~/.local/state/theme/rofi.rasi` via theme-set). All layouts import it:
`system-floating`, `tsoding` (Alt+Space bar), `powermenu` (Win+Shift+E... see keybinds),
`clipboard-floating`, `websearch-floating`, `cheatsheet`, `theme-picker-nvchad` (Alt+Shift+M),
`wallpaper` grid, `theme-picker`, `games.rasi` (Alt+G). No rounded corners anywhere
(verify: `grep -rn "border-radius.*[1-9]" ~/.config/rofi/*.rasi` must be empty).

## Keybinds (sway, current)
- Win+Esc = powermenu (horizontal 5-button). Win+Shift+E = kill menu (rofi-pkill).
- Win+' = kill menu (added; left Win + right pinky). Alt+Esc = kill menu.
- Win+Alt+1 = wifitui (Alacritty). Win+Alt+2 = bluetui (Alacritty).
  Deleted: old rofi `wifi-menu`, `rofi-bluetooth` scripts (disk + chezmoi).
- Win+Shift+W = ds3-wallpaper stepper. Alt+Shift+W = random-wallpaper.
- Win+Shift+S = ocr-snip (region→tesseract→wl-copy). Win+S = screenshot-region.
- Win+C / Win+V UNBOUND (freed for xremap universal copy/paste).
- Shift+Space UNBOUND (was mode_toggle, conflicted with fast typing).
- Middle-click in Alacritty = Paste (native mouse.bindings, NOT xremap).
- Wallpaper: sway native only (`swaymsg output "*" bg …`), `wset <img> [mode]` (default fit).
  32 DS3 wallpapers in `~/.local/share/wallpapers/ds3_*`; minecraft set deleted.
- ws1/ws2/ws3 = forced tabbed. Games → ws4 fullscreen. Browser `.*rockstar.*` title rules
  have browser/Steam exclusions (heavy WebGL tabs no longer yanked to ws4).

## Bluetooth audio (RESOLVED — RULE 10 in place)
- `dusky-audio-dsp.service` completely deprecated and removed; replaced by native PipeWire filter chains + MicStudio.
- `11-bluetooth-policy.conf` strictly enforces A2DP (`bluez5.roles = [ a2dp_sink a2dp_source ]`), preventing headsets from falling back to low-quality HSP/HFP.
- Internal laptop microphone (`ghelper-audio`) strictly serves as system input; Bluetooth mic profiles are never engaged.
- `bluetui` is bound to Win+Alt+2.

## OpenCode MCPs (`~/.config/opencode/opencode.json` + `.tmpl` in chezmoi)
Servers now: system-metrics, gpu-tuning, systemd, desktop, chezmoi, sway, input-stack.
REMOVED: i3, x11. New: `~/.local/bin/sway-mcp` (tested live). Live file has extra local
Ollama/LM-Studio customizations — edit the `.tmpl` for structural changes, never overwrite live.

## Epic / Legendary gaming
- `legendary` v0.21.0, 113 games. Install base `/mnt/Games/EpicGames`. HLL installed (67GB).
- `epic-launch <appid> [prefix]` = fresh EOS ticket via `--dry-run` (stderr!) + umu container
  + GE-Proton11-7 + prime-run. `hll-launch` wraps it (prefix `hll`).
- HLL input-dead root cause: raw proton = no container (broken videos) + no EAC bridge.
  HLL routed to ws4 (rules + daemon updated). **User has NOT yet confirmed menu input works.**
- `egs` (bash, fzf) lives at `~/.local/bin/egs.bash.bak` (backup kept).

## `egs` Rust TUI — IN PROGRESS (does NOT compile right now)
- Source: `~/.local/src/egs/` (12 modules), binary `~/.local/bin/egs` (currently the LAST GOOD
  1.4MB build from previous session — still installed and working, DO NOT overwrite until
  the new build passes tests).
- Baseline (working, 7/7 tests, zero warnings): library/cache/search/actions/details/
  delete flows/Alt+G registry (`~/.config/rofi/epic-games.list`, `Title|appid|prefix`)/
  Settings/terminal RAII guard.
- In-progress edit (second session): theme.rs (colors.sh accent-fill selection),
  nav (Ctrl+d/u, g/G/gg, Tab filter All/Installed/Available), status bar, ui.rs theming.
  **ui.rs has an unfixed `title_style()` call (no-arg) at ~line 125 and popup borders
  lack theme styling — finish these, then `cargo check`, `cargo test`, `cargo clippy`,
  `cargo fmt`, rebuild, pty-test, install.**
- Spec for remaining phases (metadata cache, in-TUI install progress, Proton system,
  launch composer, LSFG/GameMode, Tab add-flow, expanded tests, 20-Minutes-Till-Dawn
  live test) was given in full in the previous session — ask user to re-paste if needed,
  or continue from this file's direction.
- Prefix convention: registry field → `compatdata/<field>` → `compatdata/<appid>` →
  fail closed. NEW root `~/.local/share/egs/prefixes/<appid>` planned but NOT implemented.
  HLL must keep working via `compatdata/hll` (+umu escape hatch).

## Misc state
- Snapshots: single baselines `stable-baseline-20261002` (#706 root, #74 home). Old ones pruned.
- Firefox fully removed (no binary existed; deleted 2 .desktops + dead wrapper).
- `xfce4-about.desktop` hidden via local override (libxfce4ui can't be removed — Thunar needs it).
- Rclone: evaluated viable (one-shot sync OK, on-demand mounts only, no web GUI, config must
  be age-encrypted). NOT installed. Offered `cloud-sync`/`cloud-mount` wrappers — pending user go.
- Outstanding user questions: HLL input confirmation, rclone go-ahead.
