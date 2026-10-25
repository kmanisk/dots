# Terminal & Shell Environment Reference

Architecture, configuration, aliases, and custom utilities for the terminal ecosystem (Fish + Alacritty/Kitty + Starship).  
Use this document as the single source of truth for shell workflows, prompt behaviors, and CLI tools.

---

## 1. Modular Fish Shell Architecture (`~/.config/fish/`)

To eliminate startup delay, reduce token bloat for agents, and enable modular configuration:

| Component | Path | Description |
| :--- | :--- | :--- |
| **Root Index** | `~/.config/fish/config.fish` | Minimal entrypoint sourcing vendor and local configs. |
| **Environment** | `~/.config/fish/conf.d/00-env.fish` | `EDITOR=nvim`, `VISUAL=nvim`, `PATH` prioritization, beam cursor, `LS_COLORS`. |
| **Prompt** | `~/.config/fish/conf.d/10-prompt.fish` | `starship` initialization and `zoxide` directory jumping. |
| **Aliases** | `~/.config/fish/conf.d/20-aliases.fish` | Navigation, modern CLI replacements (`lsd`/`eza`), Git, Chezmoi, Pkg, Theme, Gaming. |
| **Bindings** | `~/.config/fish/conf.d/30-bindings.fish` | Custom shell bindings (`Ctrl + b` for lazy dotfiles sync). |
| **Login** | `~/.config/fish/conf.d/40-login.fish` | TTY1 automated graphical desktop autostart. |
| **Functions** | `~/.config/fish/functions/*.fish` | Standalone utility functions lazy-loaded on demand (zero startup cost). |

---

## 2. Essential Shell Aliases & Shortcuts

### Navigation
| Alias | Command | Purpose |
| :--- | :--- | :--- |
| `up` / `g.` | `cd ..` | Parent directory |
| `...` | `cd ../..` | Two levels up |
| `home` | `cd ~` | User home |
| `doc` / `docs` | `cd ~/Documents` | Documents directory |
| `des` | `cd ~/Desktop` | Desktop directory |
| `dot` / `dots` | `cd ~/.local/share/chezmoi` | Dotfiles repository |
| `local` | `cd ~/.local` | Local user directory |
| `fm` | `yazi` | Launch Yazi terminal file manager |

### Editing & Maintenance
| Alias | Command | Purpose |
| :--- | :--- | :--- |
| `vim` / `vi` | `nvim` | Always launches Neovim |
| `ep` | `nvim ~/.config/fish/config.fish` | Edit Fish configuration |
| `editdot` | `nvim ~/.local/share/chezmoi` | Open dotfiles in Neovim |
| `rel` | `source ~/.config/fish/config.fish` | Reload Fish shell configuration |
| `cls` | `clear` | Clear terminal screen |
| `q` / `:q` | `exit` | Exit terminal shell |
| `agy` | `command agy --dangerously-skip-permissions` | Launch Antigravity CLI |
| `fixtether` | `setup-tether-dns` | Restore mobile tethering DNS resolution |

---

## 3. Terminal Emulators: Alacritty & Kitty

### Alacritty (`~/.config/alacritty/alacritty.toml`)
* **Dynamic Theming:** Imports `~/.local/state/theme/alacritty.toml` directly, syncing instantly on `theme-set`.
* **Typography:** `VictorMono Nerd Font` (Style: `Bold`) @ `19.5pt`.
* **Cursor:** Solid `Block`, blinking `Off`.
* **Clipboard:** `save_to_clipboard = true` (selection auto-copies to clipboard), Middle-click paste.
* **Keyboard Font Zoom:** `Alt + Shift + U` (Zoom in), `Alt + Shift + Y` (Zoom out).

### Kitty (`~/.config/kitty/kitty.conf`)
* **Visual & Performance Parity:** Configured with identical font family, size, block cursor, no window decorations, and zero audio bell.
* **Performance:** `sync_to_monitor yes`, `input_delay 2`, `repaint_delay 6`.
* **Keybindings:** Super+C / Super+V, Alt+Shift+U / Alt+Shift+Y.

---

## 4. Key Custom System Utilities (`~/.local/bin/`)

| Script / Binary | Description |
| :--- | :--- |
| `prime-run` | Executes command on discrete NVIDIA RTX 5050 Mobile via PRIME render offload. |
| `apply-vibrance` | Canonical mode-aware one-shot display vibrance applicator (`AsusMuxDgpu` vs `Hybrid`). |
| `sysmem` | Audits true idle baseline memory (Kernel, root daemons, Sway, background services, hidden scratchpads). |
| `theme-set` | Core Schema 1 theme compiler and atomic distributor. |
| `theme-sync` | Compiles raw themes into active cache manifests. |
| `rofi-theme` | Pure NvChad Base46 theme picker with live swatches and FZF sorting. |
| `rofi-pkill` | Application-level process aggregator and terminator (triggered via `Caps + w`). |
| `toggle-cursor-theme` | Toggles Gruvbox Material Dark vs Light cursor across Sway, GSettings, GTK, and Xresources. |
| `adjust-cursor-size` | Scales cursor size up or down in 2px increments (`16px`–`64px`). |
| `toggle-btop` | Toggles floating system monitor scratchpad (`Ctrl + Shift + Esc`). |
| `scratch-toggle` | Toggles terminal / notes / spotify floating scratchpads with lazy loading and game focus protection. |
| `sway-mcp` | Model Context Protocol server for Sway IPC, syntax check, and duplicate bindsym auditing. |
| `micstudio` / `mic` | Native audio studio and voice preset manager (DPDFNet, 27 models, sidetone, dual spectrograph). |
| `spk` | ASUS TUF DAX3 Dolby Speaker DSP voicing manager (`music`, `dynamic`, `balanced`, `custom`, `experimental`). |
| `rofi-network` | Interactive Rofi & CLI utility for Ethernet / Wi-Fi priority control (bound to `$mod+Mod1+5`/`$mod+Mod1+n`). |
| `killgame` | Clean gaming session terminator (`Caps + R` / hotkey); terminates games without spawning idle menus. |
| `bt-autoconnect` | Event-driven D-Bus daemon auto-connecting target Bluetooth audio devices on power-on/wake. |
