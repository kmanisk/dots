# File Management & Editor Reference (Yazi + Zed + Thunar)

Architecture, keybindings, and typography standards for file management tools and secondary editors.  
Use this document as the single source of truth for terminal file navigation and Zed editor workflows.

---

## 1. Terminal File Manager: Yazi (`~/.config/yazi/`)

* **Configuration:** `~/.config/yazi/yazi.toml` & `keymap.toml`.
* **Pane Ratios:** `[ 3, 7, 8 ]` (parent 16.7%, active listing 38.9%, preview 44.4%). This balances readable parent filenames against a larger preview. Earlier live `[ 1, 3, 4 ]` (12.5%/37.5%/50%) clipped parent names, whereas `[ 2, 4, 3 ]` (22.2%/44.4%/33.3%) made the preview too narrow. Changes take effect on the next Yazi launch; no plugin or daemon required.
* **Display Defaults:**
  * Directory sorting: `sort_dir_first = true`.
  * Hidden files: `show_hidden = true`.
  * Viewport scrolling: `scrolloff = 5`.
  * Linemode: `none` (minimalist filename display).
* **Opener Invariants:**
  * Edit: `${EDITOR:-vi} %s` $\to$ automatically opens files in Neovim (`nvim`).
  * Media / Fallback: `xdg-open %s1`.
* **Neovim Integration:** Can be invoked inside any Neovim session via `<leader>fm`.
* **Square UI (2026-11-07):** `dot_config/yazi/init.lua` sets `full-border` to `ui.Border.PLAIN`; theme template `dot_config/theme/templates/yazi.toml` sets `[indicator].padding` to `{ open = "▐", close = "▌" }` to replace the rounded selection/hover pills, and `[status].sep_left` / `sep_right` to empty caps for rectangular status blocks. These are supported in Yazi 26.9.1. The live file `~/.config/yazi/theme.toml` is a symlink to the palette-managed `~/.local/state/theme/yazi.toml`. After a November 7 regression, we confirmed the live generator at `~/.config/theme/templates/yazi.toml` was still the old rounded variant even though chezmoi was updated; it has now been synchronized with the source. `[tabs].sep_inner`/`sep_outer` are also explicitly empty so defaults cannot reintroduce round caps. The selected `all-hallows-eve` theme was re-rendered successfully and all indicator/tab/status separator fields were checked. Do not edit only the generated file: theme switches regenerate it. Yazi must be reopened for changed `init.lua` plugins; if an instance is already running, `F5` or `ya emit-to 0 app:theme` reloads theme data. Yazi was closed during the update, so the next launch reads both files automatically.

---

## 2. GUI Editor: Zed (`~/.config/zed/`)

### Typography Standards (`settings.json`)
* **Buffer Dimensions:**
  * Font Size: `32.0` – `35.0` (standard high-DPI scaling on 1920x1200).
  * Line Height: `custom: 1.40` (strict vertical rhythm invariant).
  * Coding Ligatures: `calt = true` and `liga = true` enabled for programming symbols (`->`, `=>`, `!=`, `===`).
* **Active Fonts:**
  * Buffer: `Comic Mono` / `Iosevka Nerd Font Mono`.
  * Terminal: `Iosevka Nerd Font Mono` (custom line height `1.0`).

### 60% Ergonomic Leader Chords (`keymap.json`)
In keeping with the 60% keyboard philosophy, all editor operations use non-straining sequential leader chords (`Space` leader) in Normal mode:

| Chord | Action | Context |
| :--- | :--- | :--- |
| `Space d d` / `Space q` | Close current buffer / tab | Editor |
| `Space d f` | Delete file | Editor & Project Panel |
| `Space y y` | Yank current file path to clipboard | Editor & Project Panel |
| `Space y f` | Yank full file contents | Editor |
| `Space c p` | Copy absolute file path | Editor |
| `Space c n` | Copy relative file path | Editor |
| `Space Space` | Switch to alternate file | Editor |
| `Space ,` | Open quick tab switcher | Editor |
| `Space 1` .. `5` | Harpoon quick jump buffers | Editor |

---

## 3. GUI File Managers (Supplementary)

* **Thunar (`thunar.Thunar`):**
  * Lightweight GTK3 file manager used for external drives, graphical drag-and-drop, and visual file inspections.
  * Can be spawned directly from Neovim's Oil buffer via `<leader>oE`.
* **PCManFM-Qt:** Minimal Qt-based fallback file manager.

---

## 4. Ventoy GUI on Sway/Xwayland

The system package `ventoy-bin` supplies `/usr/bin/ventoygui` and `/usr/share/applications/ventoy.desktop`. Ventoy uses polkit (`pkexec`) to elevate its GTK3 GUI and forces `GDK_BACKEND=x11`; Sway's Xwayland ACL normally authorizes only the logged-in user, so an elevated Ventoy window may fail to map even after authentication.

The managed user command `~/.local/bin/ventoygui` (`dot_local/bin/executable_ventoygui`) grants `SI:localuser:root` using `xhost` **only** for the lifetime of the GUI, runs the unmodified `/usr/bin/ventoygui` with its normal polkit challenge, and revokes its own grant on exit. A nonblocking lock prevents overlapping wrappers from undoing each other's permission. The user desktop override at `~/.local/share/applications/ventoy.desktop` (source: `dot_local/share/applications/ventoy.desktop.tmpl`) routes the app launcher explicitly to the managed helper. Never use broad `xhost +` or bypass polkit. No Ventoy install/write command is run automatically.

Live verification on 2026-11-05: the GTK3 interface initialized, enumerated the host NVMe disk, found no Ventoy installation, and exited; no removable USB drive was attached and no disk was modified. The root-only X11 grant was observed during launch and absent again after exit. For normal use select only the intended removable USB disk in the GUI; never select the internal `nvme0n1` drive.

---

## 5. Maintenance & File Locations

| File | Purpose |
| :--- | :--- |
| `~/.config/yazi/yazi.toml` | Yazi core settings and preview configurations |
| `~/.config/yazi/keymap.toml` | Yazi custom keybindings |
| `~/.config/zed/settings.json` | Zed typography, theme, and linter settings |
| `~/.config/zed/keymap.json` | Zed 60% ergonomic leader key mappings |
