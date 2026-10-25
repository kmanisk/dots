# File Management & Editor Reference (Yazi + Zed + Thunar)

Architecture, keybindings, and typography standards for file management tools and secondary editors.  
Use this document as the single source of truth for terminal file navigation and Zed editor workflows.

---

## 1. Terminal File Manager: Yazi (`~/.config/yazi/`)

* **Configuration:** `~/.config/yazi/yazi.toml` & `keymap.toml`.
* **Pane Ratios:** `[ 1, 4, 3 ]` (Parent directory, active listing, preview window).
* **Display Defaults:**
  * Directory sorting: `sort_dir_first = true`.
  * Hidden files: `show_hidden = true`.
  * Viewport scrolling: `scrolloff = 5`.
  * Linemode: `none` (minimalist filename display).
* **Opener Invariants:**
  * Edit: `${EDITOR:-vi} %s` $\to$ automatically opens files in Neovim (`nvim`).
  * Media / Fallback: `xdg-open %s1`.
* **Neovim Integration:** Can be invoked inside any Neovim session via `<leader>fm`.

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

## 4. Maintenance & File Locations

| File | Purpose |
| :--- | :--- |
| `~/.config/yazi/yazi.toml` | Yazi core settings and preview configurations |
| `~/.config/yazi/keymap.toml` | Yazi custom keybindings |
| `~/.config/zed/settings.json` | Zed typography, theme, and linter settings |
| `~/.config/zed/keymap.json` | Zed 60% ergonomic leader key mappings |
