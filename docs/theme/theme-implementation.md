# Desktop Theme Orchestration & Live-Reload Architecture

> **Target System:** CachyOS (x86-64-v3) · Sway / Wayland (with i3/X11 compatibility) · Fish / Zsh · Alacritty  
> **Philosophy:** Zero resident daemons, zero background polling watchers, sub-100ms atomic compilation, instantaneous IPC/RPC hot-reloading.

---

## 1. Architecture Overview

The system bridges Omarchy theme sources (`colors.toml`), Base46/NvChad themes, and desktop applications into a unified, instant-switching theme pipeline without running persistent watchers or background daemons.

```text
               OMARCHY / BASE46 THEME SOURCES
                              │
                    omarchy-import / theme-sync
                              │
                              ▼
                 ~/.cache/theme/themes/*.json
                              │
                    theme-set <name> (<100ms)
                              │
        ┌─────────────────────┴─────────────────────┐
        ▼                                           ▼
  STAGE COMPILATION (.next/)              RUNTIME DISPATCH (IPC/RPC)
  - Alacritty (alacritty.toml)            - Sway: swaymsg client.* / bar
  - Sway (sway.conf)                      - Neovim: RPC socket eval
  - Yazi (yazi.toml)                      - Zed: inotify touch
  - Zed (nvchad-system.json)              - btop: SIGUSR2
  - btop (btop.theme)                     - Mako / Dunst: makoctl / dunstctl
  - Mako (config)                         - Yazi: ya emit-to 0 app:theme (DDS)
  - Qt5/Qt6 (nvchad.conf)                 - GTK: gsettings color-scheme
        │
  ATOMIC PROMOTION (os.replace)
  ~/.local/state/theme/*
```

---

## 2. Omarchy Theme Importer (`omarchy-import`)

Located at: [`~/.local/bin/omarchy-import`](file:///home/manisk/.local/bin/omarchy-import)

Omarchy themes (designed for Hyprland/Arch) provide canonical palettes in `colors.toml`. The importer maps them directly into our native Base16 and Base30 schemas.

### What it does:
1. **Source Ingestion:** Accepts a local directory or GitHub repository URL (e.g. `https://github.com/omarchy/omarchy-batman`).
2. **Palette Normalization:** Converts `colors.toml` into:
   - Full Base16 mapping (`base00`–`base0F`).
   - Extended Base30 mapping (`black`, `white`, `folder_bg`, `grey_fg`, `one_bg`, etc.).
   - Explicit signature accent resolution (`folder_bg` / `base0D` priority).
3. **Asset Handling:** Automatically extracts `preview.png` or `thumbnail.png` into `~/.config/theme/previews/<name>.png` for launchers (Walker/Rofi).
4. **Neovim Lua Generator:** Writes `~/.config/nvim/lua/themes/<name>.lua` containing dual-cased Base16 keys (`base0A` and `base0a`) to ensure complete compatibility with NvChad's Base46 compiler.
5. **Theme Cache Update:** Writes the compiled JSON directly into `~/.cache/theme/themes/<name>.json`.

---

## 3. Sub-100ms Atomic Rethemer (`theme-set`)

Located at: [`~/.local/bin/theme-set`](file:///home/manisk/.local/bin/theme-set)

`theme-set` executes in **70ms – 110ms** total wall-clock time.

### Guarantees:
- **Two-Phase Staged Compilation:** All templates are rendered into `~/.local/state/theme/.next/` and validated for non-zero size before promotion. If any template fails, zero live files are modified.
- **Atomic Promotion:** Promotes files using `os.replace` directly into target paths and symlink targets.
- **Single-Pass `/proc` Process Discovery:** Scans `/proc` exactly once to discover PIDs for `sway`, `btop`, `dunst`, `mako`, `waybar`, and `yazi`, avoiding multiple `pgrep` or `pkill` subprocess invocations.
- **Non-Blocking Best-Effort IPC:** All live signals, RPC calls, and socket commands execute asynchronously or in detached background threads.

---

## 4. Live Hot-Reload Mechanisms

| Application | Hot-Reload Mechanism | Latency | Details |
| :--- | :--- | :--- | :--- |
| **Sway** | Batched `swaymsg` IPC | ~8ms | Updates `client.focused`, `focused_inactive`, `unfocused`, `urgent` borders and swaybar statusline/workspaces without reloading the window manager. |
| **Alacritty** | File Watcher / Inotify | Instant | `~/.config/alacritty/alacritty.toml` symlinks to `~/.local/state/theme/alacritty.toml`. Atomic replacement triggers native reload. |
| **Neovim (NvChad)** | RPC via Unix Domain Sockets | ~12ms | Queries live sockets in `$XDG_RUNTIME_DIR/nvim.*`, triggers `vim.g.system_theme_sync = true` and `require('base46').load_all_highlights()` across all open editor instances. |
| **Zed** | Atomic file + `os.utime` touch | Instant | Atomic rewrite of `~/.config/zed/themes/nvchad-system.json` followed by an `os.utime` touch on `~/.config/zed/settings.json`. |
| **btop** | Direct POSIX signal | ~2ms | Sends `SIGUSR2` directly to discovered `btop` PIDs via `os.kill`. |
| **Mako / Dunst** | Daemon Control CLI | ~5ms | Dispatches `makoctl reload` or `dunstctl reload`. Updates notifications, OSD sliders, and system alerts. |
| **Yazi** | Data Distribution Service (DDS) | ~4ms | Broadcasts `app:theme` to all active instances using `ya emit-to 0 app:theme`. |
| **GTK 3 / 4** | GSettings IPC / On-Launch | ~10ms | Updates GSettings `color-scheme` and `gtk-theme` over D-Bus for newly launched apps. Running GTK3 file managers (Thunar/Nemo) do not hot-reload in-place without a resident settings daemon (see Section 6). |

---

## 5. Legibility, Contrast & Styling Invariants

### 1. Yazi Light & Dark Hot-Reload Contrast
- **The Problem:** In `~/.config/theme/templates/yazi.toml`, unstyled files previously had `{ mime = "*", fg = "{{white}}" }`. In light mode, this resulted in white-on-white unreadable text on running instances.
- **The Fix:** Changed fallback rules to dynamic `{{fg}}` (`{ mime = "*", fg = "{{fg}}" }`) and inverted bars to `{ fg = "{{bg}}", bg = "{{fg}}" }`.
- **DDS Reload:** `theme-set` broadcasts `ya emit-to 0 app:theme` on every switch so running Yazi sessions adapt immediately without restarting.
- **Manual Keybind:** Bound `<F5>` in `~/.config/yazi/keymap.toml` to `app:theme` for on-demand reload.

### 2. High-Definition Theme Picker UI (Rofi)
- **Typography:** Switched from cramped Iosevka to geometric **JetBrainsMono Nerd Font 16pt** (18pt Bold prompt) for showcase readability.
- **Vibrant Spectrum Swatches:** Shows the 8 syntax spectrum colors (`base08`–`base0F`) in neat aligned columns (`● ● ● ● ● ● ● ●`).
- **Floating Pill Selection:** Selected items use a soft background fill (`@background-alt`) with an elegant 4px accent border bar on the left instead of a flat transparent underline.
- **Dynamic Active Badge:** The current theme receives an explicit `[ACTIVE]` badge matching the theme's green accent.
- **Spacious Layout:** Widened from 700px to **860px** with 16px corner radius and 24px padding.

### 3. Notification & OSD Styling (Mako)
- **Contrast Fix:** Replaced solid opaque background accents with translucent alpha fills (`progress-color=over {{accent}}45`) to prevent unreadable white text on bright yellow/gold accents.
- **Dynamic Theming:** Volume, Brightness, Screenshot alerts, and Night Light notifications dynamically inherit the active theme accent.

### 4. Sway Tabbed & Border Accents
- Focused window borders use the true signature theme accent.
- Tabbed title bars retain dark, sleek interiors while highlighting the border outline:
  ```text
  client.focused {{accent}} {{bg2}} {{fg}} {{accent}} {{accent}}
  ```

---

## 6. GUI File Manager Runtime Theme Reload Investigation

Empirical evaluation to determine whether in-process runtime theme hot-reloading is possible for GUI file managers on vanilla Sway without a persistent daemon.

### Investigation & Baseline Results

| Metric | Thunar | Nemo | PCManFM-Qt |
| :--- | :--- | :--- | :--- |
| **Package / Version** | Thunar `4.20.10` (Xfce 4.20) | Nemo `6.6.4` (Cinnamon) | PCManFM-Qt `2.4.1` (LXQt) |
| **Toolkit** | GTK3 (`3.24.52`) | GTK3 (`3.24.52`) | Qt6 (`6.7.5` / `libfm-qt6`) |
| **Wayland Backend** | Native Wayland (`xdg_shell`) | Native Wayland (`xdg_shell`) | Native Wayland (`qt6-wayland`) |
| **PID Stability During Test** | `114677` (unchanged) | `134439` (unchanged) | N/A (tested restart) |
| **Did Theme Visually Change Live?** | **No** | **No** | **No** (requires restart) |
| **Did User `gtk.css` Reload In-Place?** | **No** (cached in memory) | **No** (cached in memory) | N/A (`qt6ct` palette) |
| **Window & Directory State Intact?** | **Yes** | **Yes** | **Yes** (if untouched) |

### Technical Root Cause in GTK3 on Vanilla Sway
1. **User CSS Caching:** In GTK3, `~/.config/gtk-3.0/gtk.css` is parsed once at application launch into the default CSS provider at `GTK_STYLE_PROVIDER_PRIORITY_USER` (800).
2. **Lack of Inotify Watcher:** GTK3 does not watch `gtk.css` on disk. When `theme-set` rewrites `gtk.css`, running GTK3 windows never re-parse the file.
3. **Overriding Theme Definitions:** Because `gtk.css` defines `@define-color window_bg_color ...`, its initial in-memory stylesheet continues overriding the system theme even if `GtkSettings` receives a property change.
4. **Wayland / Sway Architecture:** Outside of a desktop environment with a persistent settings daemon (`gsd-color`, `xsettingsd`), GTK3 applications only parse `settings.ini` and `gtk.css` from disk at startup.

### Decision Outcome: Decision C
```text
GTK3/THUNAR (AND NEMO) CANNOT RELIABLY HOT-RELOAD UNDER OUR CURRENT SWAY ARCHITECTURE
```
- No artificial reload is faked.
- Thunar is preserved as the default system file manager.
- PCManFM-Qt-specific restart wrappers have been stripped from `theme-set`.
- Zero resident daemons are introduced, honoring system resource invariants.

---

## 7. Maintenance & Dotfile Safety

- **Chezmoi Invariant:** All configuration changes are tracked via `chezmoi add`.
- **MangoHud Invariant:** `~/.config/MangoHud/MangoHud.conf` remains protected and is never modified by automated retheming tools.
- **Resource Discipline:** Zero background daemons, cron loops, or resident inotify wrappers are introduced.

