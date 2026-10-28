---
name: 60pct-keyboard-workflow
description: Ergonomic standards, multi-tier layer architecture, and keybinding invariants for 60% keyboards on i3wm, xremap, and Zed.
version: 1.0.0
---

# 60% Keyboard Workflow Architecture & Ergonomic Standards

> **Hardware Profile:** Katana S K1 (60% ANSI Layout)  
> **Physical Modifiers:** Left Super (`Mod4`) ONLY. No Right Super. No physical F-row (`F1`–`F12`).  
> **Virtual Layering:** `xremap` (CapsLock: Tap = `Esc`, Hold = `RightCtrl` virtual modifier layer).  

## 1. Core Ergonomic Philosophy & Invariants

All future keybinding modifications across **i3**, **xremap**, **Zed**, **Alacritty**, and **Rofi** MUST adhere to these invariants:

1. **60%-Keyboard-First:** Never bind essential actions to physical keys that do not exist on a 60% board (e.g. physical `F1`–`F12`, `Home`, `End`, `PageUp`, `PageDown`, `Insert`, `Delete`, `NumPad`, or `Right Super`).
2. **Left Super Exclusivity:** The system has only one physical Super key on the left. Never design two-key combinations that require pressing Left Super plus a key that requires stretching the left hand unnaturally across the board.
3. **Home-Row Centered:** Hands should remain anchored at `A S D F` (left) and `J K L ;` (right). Actions requiring movement away from the home row should be secondary or fallback only.
4. **Two-Hand Balance:** Modifiers pressed by the left hand should ideally trigger keys actuated by the right hand (e.g., `Win + h/j/k/l`, `Win + u/i/o/p`), preventing repetitive strain from one-handed claw grips.
5. **Zero-Modifier Leader Chords for Text:** In editor/buffer contexts (Zed), prioritize sequential leader chords (`Space` leader) over finger-breaking chords (`Ctrl+Alt+Shift+...`).
6. **Persistence & Headless Services:** System features like clipboard history must run persistently and headlessly (`cliphist` BoltDB daemon, surviving reboots) without polling loops.
7. **Collision Audit & Verification Pre-Completion:** Never introduce or leave duplicate keybindings across modes or root scopes in Sway/i3. Before declaring any task complete, ALWAYS run live configuration syntax validation (`sway -C`, `i3 -C`), audit for shadowed key combinations (grep bindsym across scopes), and test live reload (`swaymsg reload`).

## 2. Multi-Tier Layer Architecture

- **Tier 1: Left Super (`Mod4`) — Window & Workspace Management:**
  - Focus: `Win + h / j / k / l`
  - Move: `Win + Shift + h / j / k / l`
  - Switch Workspaces: `Win + u / i / o / p` (WS 1–4), `Win + [ / ]` (WS 5–6)
  - Move + Follow: `Win + Shift + u / i / o / p`, `Win + Shift + { / }`
  - Force Kill: `Win + BackSpace` (SIGKILL via force-kill-window; xremap: `Caps + BackSpace`)
  - Graceful Close: `Win + q` only (polite WM_DELETE; xremap: `Caps + q`). Shift variants removed 2026-10-18.
  - Toggle Floating / Tiling: `Alt + Shift + Space`
  - Toggle Scratchpad / Background Focus: `Win + Space`
  - Spotify Scratchpad Toggle: `Win + m`
  - Process Killer Menu: `Caps + w` (App Aggregator & Terminator; formerly `Win + Shift + e` / `Win + x`)
  - Persistent Clip: `Win + V` / `Win + y` (Centered Foot picker, large prompt preview & deep search)
  - Quick Cheatsheet: `Win + ?` (Interactive Rofi cheatsheet modal)
  - Screen Black (Sleep Audio): `Win + Alt + l` (Display backlight off, keeps agent and audio active)
  - Region Screenshot (Clipboard): `Win + S`
  - OCR Snip: `Win + Shift + S` (fullscreen screenshot in gaming mode)
  - Cursor Theme Toggle: `Alt + Shift + c` (Dark / Light)
  - Cursor Size Adjust: `Alt + Shift + =` (+4px) / `Alt + Shift + -` (-4px) (Persistent)

- **Tier 2: CapsLock Virtual Layer (`xremap`) — Editorial & Navigation:**
  - Tap (<=200ms): `Escape` (instant Vim normal mode exit)
  - Hold: `RightCtrl` virtual modifier layer
  - Right Modifiers: `RightCtrl` -> `RightMeta`, `RightAlt` -> `RightMeta` (both act as Super)
    - Cursor Motion: `Caps + h / j / k / l` (← ↓ ↑ →)
    - Word Navigation: `Caps + o / p` (`Ctrl+← / →`)
    - Word / Char Del: `Caps + u / d` (`Ctrl+BS / Del`)
    - Spacing & Line: `Caps + n / m` (`Enter / BS`)
    - Select All & Copy: `Caps + ,` (`Ctrl+A, Ctrl+C`)
    - Smart Paste: `Caps + .` (Ctrl+V, or Ctrl+Shift+V in terminals; paste-only, never opens a window)
    - Screenshot Buffer Picker: `Caps + Shift + Space` (multi-select picker: Space toggles, arrows navigate, Enter pastes into the prompt)
    - Clipboard Menu: `Caps + c` (Opens centered floating clipboard manager)
    - View Screenshot: `Caps + v` (Opens latest screenshot in imv)
    - Brightness Control: `Caps + [` (BrightnessUp), `Caps + '` (BrightnessDown)
    - Volume Control: `Caps + ]` (VolumeUp), `Caps + \` (VolumeDown)
    - Fullscreen Screenshot: `Caps + Space` (disk + clipboard + AI buffer; WS 3/4 save to `Screenshots/Gaming`)
    - Region Screenshot (Saved to File + Clipboard): `Caps + s`
    - Window Close (Graceful): `Caps + q` only (Two-Handed)
    - Window Force Kill: `Caps + BackSpace` (maps to `Win + BackSpace` force-kill)
    - Process Killer Menu: `Caps + w` (App-level aggregator & terminator; formerly `Win + Shift + e`)
    - Steam Launch (DGPU, background): `Caps + e` (launches or reveals Steam in the background and routes its window to WS 3; the viewport and focus stay where you are; `Win + Shift + g` runs the same script; migrated from `Alt + Shift + S`, 2026-10-18; background-routing rewrite 2026-10-29)
    - Kill Steam & Games: `Caps + r` (Emergency terminator for Steam, Proton games & Wine processes; flock-guarded - repeat presses escalate a hard sweep without stacking compositor reloads, 2026-10-18)
    - Virtual F-Keys: `Caps + 1..0, -, =` (`F1..F12`)

- **Tier 3: Application Leader (Zed) — Buffer & File Operations:**
  - Buffer Close: `Space d d` or `Space q`
  - Delete File: `Space d f` (Editor) / `d d`, `d f` (Project Panel)
  - Yank File Path: `Space y y` (Editor) / `y y` (Project Panel)
  - Yank Full Content: `Space y f`
  - Copy Paths: `Space c p` (Absolute) / `Space c n` (Relative)
  - Quick File Switch: `Space Space` (Alt File) / `Space ,` (Tab Switcher)
  - Harpoon Buffers: `Space 1 .. 5`

## 3. Configuration Sources & Sync Paths

- Sway (Wayland): `~/.config/sway/config` and modular directory `~/.config/sway/config.d/` (chezmoi: `~/.local/share/chezmoi/dot_config/sway/`)
  - Keybindings: `~/.config/sway/config.d/40-keybindings.conf`
  - Gaming mode: `~/.config/sway/config.d/50-gaming-mode.conf`
  - Window rules: `~/.config/sway/config.d/30-window-rules.conf`
- Fish shell: `~/.config/fish/config.fish`, `~/.config/fish/conf.d/`, and `~/.config/fish/functions/` (chezmoi: `~/.local/share/chezmoi/dot_config/fish/`)
- xremap: `~/.config/xremap/config.yml` (chezmoi: `~/.local/share/chezmoi/dot_config/xremap/config.yml`)
- Zed: `~/.config/zed/keymap.json` (chezmoi: `~/.local/share/chezmoi/dot_config/zed/keymap.json`)
