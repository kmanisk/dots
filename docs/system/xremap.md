# xremap Key Remapping & 60% Keyboard Architecture

Comprehensive architectural reference for the system-wide key remapping setup via `xremap`.  
Use this document as the single source of truth for keyboard layering, eliminating the need to read all underlying configuration files.

---

## 1. Hardware & System Context

* **Physical Keyboard:** Katana S K2 / K1 (60% ANSI layout).
* **Physical Constraints:**
  * Single Left Super (`Mod4`) key; no physical Right Super.
  * No dedicated physical F-row (`F1`–`F12`).
  * No dedicated arrow cluster or navigation cluster (`Home`, `End`, `PageUp`, `PageDown`, `Insert`, `Delete`).
* **Daemon Execution:** Headless `xremap` user service via systemd.
  * Service Unit: `~/.config/systemd/user/xremap.service`
  * Exec Command: `/usr/bin/xremap --watch --allow-launch true %h/.config/xremap/config.yml`
  * Flag `--allow-launch true` is required to execute external shell binaries/scripts directly on key combinations.
  * Environment Inherited: `WAYLAND_DISPLAY`, `SWAYSOCK`, `DISPLAY`.

---

## 2. Global Modmap (Dual-Role CapsLock & RightCtrl)

```yaml
modmap:
  - name: Global Modmap
    remap:
      CapsLock:
        held: CapsLock               # Acts as custom virtual modifier layer
        alone: Esc                    # Instant Escape on tap (<= 200ms)
        alone_timeout_millis: 200
      RightCtrl: RightMeta           # Remaps physical Right Ctrl to Super/Meta
```

* **Tap CapsLock:** Instant `Escape` (ergonomic Vim Normal Mode exit without hand travel).
* **Hold CapsLock:** Virtual modifier activating the **CapsLock Layer**.
* **RightCtrl:** Becomes `RightMeta` (`Super`).

---

## 3. CapsLock Layer (`virtual_modifiers: [CapsLock]`)

### Navigation & Text Editing
| Chord | Emitted Key / Action | Ergonomic Role |
| :--- | :--- | :--- |
| `Caps + h` | `Left` | Vim-style left motion |
| `Caps + j` | `Down` | Vim-style down motion |
| `Caps + k` | `Up` | Vim-style up motion |
| `Caps + l` | `Right` | Vim-style right motion |
| `Caps + o` | `Ctrl + Left` | Word jump backward |
| `Caps + p` | `Ctrl + Right` | Word jump forward |
| `Caps + m` | `BackSpace` | Natural backspace under right hand |
| `Caps + u` | `Ctrl + BackSpace` | Word deletion backward |
| `Caps + d` | `Delete` | Forward character deletion |
| `Caps + n` | `Enter` | Home-row enter |
| `Caps + ;` | `[End, Enter]` | Jump to end of line & newline |
| `Caps + i` | `[Ctrl+a, BackSpace]` | Clear entire buffer/line |
| `Caps + g` | `[Ctrl+a, Ctrl+c, Right]` | Copy entire line/buffer & deselect |
| `Caps + ,` | `[Ctrl+a, Ctrl+c]` | Select all & copy |
| `Caps + .` | `Ctrl + v` | Paste clipboard |
| `Caps + f` | `Ctrl + f` | Find / search |
| `Caps + y` | `Ctrl + z` | Undo |
| `Caps + /` | `Ctrl + Alt + q` | Custom macro |

### Virtual Function Row (F1–F12)
| Chord | Emitted Key |
| :--- | :--- |
| `Caps + 1` .. `Caps + 0` | `F1` .. `F10` |
| `Caps + -` | `F11` |
| `Caps + =` | `F12` |

### Hardware Controls (Backlight & Audio)
| Chord | Action | Note |
| :--- | :--- | :--- |
| `Caps + [` | `BrightnessUp` | Screen backlight up |
| `Caps + '` | `BrightnessDown` | Screen backlight down |
| `RightAlt + q` | `BrightnessDown` | Hardware sub-legend on Katana |
| `RightAlt + w` | `BrightnessUp` | Hardware sub-legend on Katana |
| `Caps + ]` | `VolumeUp` | System volume up |
| `Caps + \` | `VolumeDown` | System volume down |

### Screenshots (Direct Script Launchers)
| Chord | Emitted Action | System Behavior |
| :--- | :--- | :--- |
| `Caps + Space` | `launch: ["screenshot-fullscreen", "--clipboard-only"]` | Fullscreen capture $\to$ Clipboard only (zero file storage) |
| `Caps + s` | `launch: ["screenshot-region", "--save"]` | Slurp/Grim region selection $\to$ Saved to `~/Pictures/Screenshots` + Clipboard |

### Window Management & Process Killer
| Chord | Emitted Action | Behavior |
| :--- | :--- | :--- |
| `Caps + q` | `Super + q` | Graceful window close (native Sway) |
| `Caps + BackSpace` | `Super + BackSpace` | Two-handed graceful window close |
| `Caps + Shift + q` | `Super + Shift + q` | Force kill window |
| `Caps + Shift + BackSpace`| `Super + Shift + BackSpace` | Two-handed force kill window |
| **`Caps + w`** | `launch: ["/home/onyx/.local/bin/rofi-pkill"]` | **Process Killer Menu** (Aggregator & Terminator; replaced `Win + Shift + e`) |

### Universal Mouse Wheel Emulation (`xscroll`)
| Chord | Action | Behavior |
| :--- | :--- | :--- |
| `Alt + Ctrl + j` / `Caps + Alt + j` | `xscroll down` | Warps cursor to center of focused output and emits wheel down ticks (`REL_WHEEL_HI_RES` -120 & `REL_WHEEL` -1) |
| `Alt + Ctrl + k` / `Caps + Alt + k` | `xscroll up` | Warps cursor to center of focused output and emits wheel up ticks (`REL_WHEEL_HI_RES` +120 & `REL_WHEEL` +1) |
* Persistent UInput mouse daemon (`xscroll.service`) ensures < 0.2ms event delivery.
* Operates identically across all native Wayland and XWayland apps (Foot, OpenCode, Brave, etc.).

---

## 4. Universal Application Clipboard

To prevent `Ctrl+C` from sending `SIGINT` to terminal tasks while maintaining uniform clipboard shortcuts across Linux GUI apps:

### Alacritty (`application.only: ["Alacritty"]`)
* `Win + c` $\to$ `Ctrl + Shift + C` (safe terminal copy)
* `Win + v` $\to$ `Ctrl + Shift + V` (safe terminal paste)
* `Alt + c` $\to$ `Ctrl + Shift + C`
* `Caps + .` $\to$ `Ctrl + Shift + V`
* *(Note: `Win + x` is intentionally unmapped in Alacritty to preserve Vim/terminal control purity)*

### GUI Apps (`application.not: ["Alacritty"]`)
* `Win + c` $\to$ `Ctrl + C` (universal copy)
* `Win + v` $\to$ `Ctrl + V` (universal paste)
* `Win + x` $\to$ `Ctrl + X` (universal cut)

---

## 5. File Locations & Maintenance Workflows

| Target File | Chezmoi Source | Purpose |
| :--- | :--- | :--- |
| `~/.config/xremap/config.yml` | `~/.local/share/chezmoi/dot_config/xremap/config.yml` | Remapping rules |
| `~/.config/systemd/user/xremap.service` | `~/.local/share/chezmoi/dot_config/systemd/user/xremap.service` | Systemd service |
| `~/.config/sway/config` | `~/.local/share/chezmoi/dot_config/sway/config` | Window manager bindings |

### Applying Changes
```bash
# Test or reload xremap service
systemctl --user daemon-reload
systemctl --user restart xremap

# Reload Sway configuration
swaymsg reload

# Persist to dotfiles repo
chezmoi add ~/.config/xremap/config.yml ~/.config/systemd/user/xremap.service ~/.config/sway/config
cd ~/.local/share/chezmoi && git commit -m "update keybindings" && git push
```

---

## 6. Future Plans — RightAlt Override Layer

Goal: keep RightAlt as a faithful right-hand Super key, while allowing
**single-chord overrides** for future custom binds (same pattern as the
CapsLock layer, but surgical: one chord at a time).

### Mechanism

xremap applies `modmap` before `keymap`. Since the Global Modmap converts
`RightAlt → RightMeta`, keymap entries must be written as `RightMeta-<key>`
(`RightAlt-<key>` entries never match — proven by the removed Katana
brightness entries, which Sway ate as Super+q/Super+w).

- A `RightMeta-q: <action>` keymap entry consumes **only** that chord.
- Every other `RightMeta+*` chord falls through to Sway as a normal
  `$mod+*` binding. Sway config needs no changes.

### Rules for adding overrides

1. Write the entry as `RightMeta-<key>`, never `RightAlt-<key>`.
2. Check `~/.config/sway/config` `$mod` bindings first — the entry shadows
   Sway for that chord, so pick chords deliberately.
3. One entry per use case; rest of Super behavior stays intact.
4. Backup config, validate YAML, `systemctl --user restart xremap`
   (`--watch` does not reliably reload).

### Reserved / decided

- `RightAlt` tap-alone: bare Super (no-op, same as left Win) — no change.
- `RightAlt` held: `RightMeta` (right-hand Super) — already live via modmap.
- Pending example: `RAlt+q → <custom action TBD>` (currently Sway `kill`).

### Override recipe (worked example: RAlt+q)

```yaml
keymap:
  - name: RightAlt future layer
    remap:
      # Shadows ONLY Sway's $mod+q (kill). Every other RightAlt chord
      # still reaches Sway as Super. Replace the launch target when the
      # action is decided; delete the entry to restore Sway kill.
      RightMeta-q:
        launch: ["/home/onyx/.local/bin/<your-action-here>"]
```

Behavior contract:

- `RAlt+q` → runs the launch target; Sway never sees it.
- `RAlt+w`, `RAlt+1`, `RAlt+d`, … → unchanged Super bindings in Sway.
- `RightAlt` tap-alone → still bare Super (no-op).
- Test after applying: `systemctl --user restart xremap`, then press the
  chord and confirm Sway's original action no longer fires.
