# 60% Keyboard Workflow Architecture & Ergonomic Standards

> **Hardware Profile:** Katana S K1 (60% ANSI Layout)  
> **Host OS & Desktop:** CachyOS (x86-64-v3) · i3wm (X11) @ 1920x1200 165Hz  
> **Physical Modifiers:** Left Super (`Mod4`) ONLY. No Right Super. No physical F-row (`F1`–`F12`).  
> **Virtual Layering:** `xremap` (CapsLock: Tap = `Esc`, Hold = `RightCtrl` virtual modifier layer).  

---

## 1. Core Ergonomic Philosophy & Invariants

All future keybinding modifications across **i3**, **xremap**, **Zed**, **Alacritty**, and **Rofi** MUST adhere to these invariants:

1. **60%-Keyboard-First:** Never bind essential actions to physical keys that do not exist on a 60% board (e.g. physical `F1`–`F12`, `Home`, `End`, `PageUp`, `PageDown`, `Insert`, `Delete`, `NumPad`, or `Right Super`).
2. **Left Super Exclusivity:** The system has only one physical Super key on the left. Never design two-key combinations that require pressing Left Super plus a key that requires stretching the left hand unnaturally across the board.
3. **Home-Row Centered:** Hands should remain anchored at `A S D F` (left) and `J K L ;` (right). Actions requiring movement away from the home row should be secondary or fallback only.
4. **Two-Hand Balance:** Modifiers pressed by the left hand should ideally trigger keys actuated by the right hand (e.g., `Win + h/j/k/l`, `Win + u/i/o/p`), preventing repetitive strain from one-handed claw grips.
5. **Zero-Modifier Leader Chords for Text:** In editor/buffer contexts (Zed), prioritize sequential leader chords (`Space` leader) over finger-breaking chords (`Ctrl+Alt+Shift+...`).
6. **Persistence & Headless Services:** System features like clipboard history must run persistently and headlessly (`cliphist` BoltDB daemon, surviving reboots) without polling loops.

---

## 2. Multi-Tier Layer Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Tier 1: Left Super (Mod4) — Window & Workspace Management  │
│  - Focus: Win + h / j / k / l                               │
│  - Move:  Win + Shift + h / j / k / l                       │
│  - Switch Workspaces: Win + u / i / o / p  (WS 1–4)         │
│                       Win + [ / ]          (WS 5–6)         │
│  - Move + Follow:     Win + Shift + u / i / o / p           │
│                       Win + Shift + { / }                   │
│  - Layout Toggles:    Win + ; (Smart Tiling/Tab)            │
│  - Fast Window Kill:  Win + q or Win + x                    │
│  - Persistent Clip:   Win + y (Cliphist + Rofi Gruvbox)     │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│  Tier 2: CapsLock Virtual Layer (xremap) — Editorial & Nav   │
│  - Tap (<=200ms):     Escape (instant Vim normal mode exit) │
│  - Hold:              RightCtrl virtual modifier layer      │
│    • Cursor Motion:   Caps + h / j / k / l  (← ↓ ↑ →)       │
│    • Word Navigation: Caps + o / p          (Ctrl+← / →)    │
│    • Word / Char Del: Caps + u / d          (Ctrl+BS / Del) │
│    • Spacing & Line:  Caps + n / m          (Enter / BS)    │
│    • Line End & Ret:  Caps + ;              (End + Enter)   │
│    • Quick Copy/Cut:  Caps + , / g          (Ctrl+a,c / c)  │
│    • Virtual F-Keys:  Caps + 1..0, -, =     (F1..F12)       │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│  Tier 3: Application Leader (Zed) — Buffer & File Operations│
│  - Buffer Close:      Space d d  or  Space q                │
│  - Delete File:       Space d f  (Editor) / d d, d f (Panel)│
│  - Yank File Path:    Space y y  (Editor) / y y (Panel)     │
│  - Yank Full Content: Space y f                             │
│  - Copy Paths:        Space c p (Absolute) / Space c n (Rel)│
│  - Quick File Switch: Space Space (Alt File) / Space , (Tab)│
│  - Harpoon Buffers:   Space 1 .. 5                          │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Ergonomic Scoring & Collision Audit Matrix

| Shortcut / Chord | Modifier | Action | Application | Hand Motion & Ergonomics | Score (1–10) |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **`h / j / k / l`** | `Win` (`Mod4`) | Focus Left / Down / Up / Right | i3wm | Left thumb + Right home row | **10/10** |
| **`Shift + h / j / k / l`** | `Win` (`Mod4`) | Move Container Left / Down / Up / Right | i3wm | Left pinky + thumb + Right home row | **9.5/10** |
| **`u / i / o / p`** | `Win` (`Mod4`) | Switch Workspace 1, 2, 3, 4 | i3wm | Left thumb + Right top row | **9.5/10** |
| **`Shift + u / i / o / p`** | `Win` (`Mod4`) | Move Container + Follow to WS 1–4 | i3wm | Left pinky/thumb + Right top row | **9/10** |
| **`[ / ]`** | `Win` (`Mod4`) | Switch Workspace 5, 6 | i3wm | Left thumb + Right bracket reach | **8.5/10** |
| **`Shift + { / }`** | `Win` (`Mod4`) | Move Container + Follow to WS 5–6 | i3wm | Left pinky/thumb + Right bracket reach | **8.5/10** |
| **`1 .. 6`** | `Win` (`Mod4`) | Switch Workspace 1–6 (Fallback) | i3wm | Left thumb + number row reach | **7/10** |
| **`;` or `a`** | `Win` (`Mod4`) | Smart Layout Toggle (Tabbed ⇄ Split) | i3wm | Right pinky / Left pinky home row | **9.5/10** |
| **`q` or `x`** | `Win` (`Mod4`) | Close / Kill Focused Window | i3wm | Left thumb + ring/index | **8.5/10** |
| **`Return`** | `Win` or `Alt` | Launch Alacritty Terminal | i3wm | Left thumb + Right pinky | **9/10** |
| **`y`** | `Win` (`Mod4`) | Clipboard History (Rofi + Cliphist) | i3wm | Left thumb + Right index | **8.5/10** |
| **`?` (`Shift + /`)** | `Win` (`Mod4`) | Rofi Websearch | i3wm | **8.5/10** |
| **`Caps` (Tap)** | None | `Escape` (Threshold: 200ms) | xremap | Left home pinky | **10/10** |
| **`Caps + h / j / k / l`** | Caps (Hold) | Physical Arrow Keys (← ↓ ↑ →) | xremap | Left home pinky + Right home row | **10/10** |
| **`Caps + o / p`** | Caps (Hold) | Word Jump Left / Right (`Ctrl+← / →`)| xremap | Left home pinky + Right top row | **9.5/10** |
| **`Caps + u / d`** | Caps (Hold) | Delete Word / Delete Char (`Del`) | xremap | Left home pinky + Right top/home row | **9.5/10** |
| **`Caps + n / m`** | Caps (Hold) | `Enter` / `BackSpace` | xremap | Left home pinky + Right index | **9.5/10** |
| **`Caps + ;`** | Caps (Hold) | `End` + `Enter` (Complete line & newline)| xremap | Left home pinky + Right home pinky | **10/10** |
| **`Caps + 1 .. 0, -, =`**| Caps (Hold) | Virtual `F1` .. `F12` | xremap | Fallback for missing physical F-keys | **8/10** |
| **`Space d d`** | Space Leader | Close Active Buffer / File | Zed | Left/Right thumb + Left middle home row | **9.5/10** |
| **`Space d f`** | Space Leader | Close Active Buffer (Editor) / Delete (Panel)| Zed | Left/Right thumb + Left index home row | **9.5/10** |
| **`Space y y`** | Space Leader | Yank File Path to Clipboard | Zed | Left/Right thumb + Right index reach | **9/10** |
| **`Space y f`** | Space Leader | Yank Entire File Content (`SelectAll`+`Copy`)| Zed | Left/Right thumb + Left index home row | **9.5/10** |
| **`Space c p / c n`** | Space Leader | Copy Absolute Path / Relative Path | Zed | Left/Right thumb + home row | **9.5/10** |

---

## 4. Configuration Sources & Sync Paths

Whenever modifying keybindings, update the source configurations and keep dotfiles synchronized:

| Component | Active File | Chezmoi Tracked Path |
| :--- | :--- | :--- |
| **i3 Window Manager** | `~/.config/i3/config` | `~/.local/share/chezmoi/dot_config/i3/config` |
| **xremap Key Remapper** | `~/.config/xremap/config.yml` | `~/.local/share/chezmoi/dot_config/xremap/config.yml` |
| **Zed Editor Keymap** | `~/.config/zed/keymap.json` | `~/.local/share/chezmoi/dot_config/zed/keymap.json` |

### Validation & Reload Checklist
1. **Validate i3 syntax:**
   ```bash
   i3 -C
   i3-msg reload
   ```
2. **Validate xremap service:**
   ```bash
   systemctl --user status xremap.service
   ```
3. **Validate Zed JSONC:** Ensure no trailing comma syntax errors in `~/.config/zed/keymap.json`.
4. **Sync dotfiles:**
   ```bash
   dotsync test
   chezmoi commit -m "feat(keymap): update keybindings"
   ```
