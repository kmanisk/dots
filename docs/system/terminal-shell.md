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
| `clip` | `clip <text>`, `clip <file> [file ...]`, or `<command> \| clip` | Copy literal text, one or more regular files' contents, or stdin to the Wayland clipboard. Fish globs such as `clip *.rs` expand to multiple files. |

### Waydroid
| Alias | Command | Purpose |
| :--- | :--- | :--- |
| `wd` | `waydroid-launcher` | Start Waydroid on demand and open the full Android UI. |
| `wds` | `waydroid-stop` | Stop the Waydroid session/container and restore the disabled-at-boot state. |
| `wdr` | `waydroid-restart` | Perform the same clean stop/start recovery path and reopen the Android UI. |

### Windows VMs: native Fish `win` command

Fish autoloads `~/.config/fish/functions/win.fish` and tab completions from `~/.config/fish/completions/win.fish`. The default target is **Windows 10 X-Lite**; prefix `11` to select Nano11. No aliases, extra daemon or shell-startup work are required.

| Command | Action |
| :--- | :--- |
| `win`, `win status` | Read-only status of both VMs |
| `win start`, `win stop` | Open/focus the default Windows VM; graceful shutdown (ACPI first, guest `wstop.cmd` fallback) |
| `win force-stop` | Emergency hard poweroff, separate from normal stop; requires typing `FORCE POWER OFF` and risks guest data loss |
| `win logs` | Follow Windows 10 QEMU logs; exit with Ctrl+C |
| `win menu` | Open the existing shared Windows Fuzzel/Rofi menu |
| `win reconnect`, `win here` | Reconnect only the Windows 10 display client; move its window here |
| `win fps-on`, `win fps-off` | Toggle Windows 10 Looking Glass diagnostic overlay |
| `win 10 source-status`, `win 10 client-status` | Read-only Windows 10 LGMP transport checks |
| `win 11 start`, `win 11 stop`, `win 11 logs` | Existing Nano11 lifecycle and logs |
| `win 11 rdp`, `win 11 restart` | Nano11 fallback RDP and established restart workflow |
| `win help` | Full command reference |

The shared `win menu` uses four generic, icon-backed entries: **Open Windows**, **Show/Hide Windows FPS / UPS**, **Stop Windows**, and **Restart Windows**. No VM version or high-CPU warning rows appear. The menu controls whichever guest is running; when both are stopped, it defaults to X-Lite. Nano11 remains available through `win 11 ...` and its existing Sway shortcut. `win 10 restart` still routes through the menu rather than resetting the guest. An explicit `win stop` briefly resumes a paused X-Lite guest *only to request ACPI/guest-keyboard graceful shutdown*; if Windows ignores ACPI, it types the short command `wstop` to launch the source-managed `C:\Windows\wstop.cmd` one-shot (installed while the VM was offline), rather than typing the full shutdown command. If Windows still ignores it, execution is re-paused instead of force-killing QEMU. The separate `win force-stop` action is confirmation-gated, cuts guest power via QEMU quit (with verified-PID SIGTERM fallback), and must not be mistaken for a clean shutdown. Opening a paused guest remains confirmation-gated. Paused-VM safeguards are enforced by the underlying `win10lab` launcher. The old redundant `nano11.fish` function wrapper was removed from both source and live Fish paths; the actual `~/.local/bin/nano11` and `win10lab` binaries remain available because Sway and menus use them. Other Fish functions and aliases are preserved.

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
| `uall` | Runs one official-repository upgrade with `pacman -Syu`, then an AUR-only `paru -Sua` pass, followed by npm globals and Fish plugin updates. It does not repeat the repository upgrade in the Paru phase. |
| `rofi-theme` | Pure NvChad Base46 theme picker with live swatches and FZF sorting. |
| `rofi-pkill` | Minimal application process aggregator and terminator via Fuzzel dmenu (triggered via `Caps + w`). |
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
