# Unified Theme Engine Architecture & System Documentation

> **Target Machine:** CachyOS rolling (BORE/EEVDF, x86-64-v3) · Sway / Wayland (with i3/X11 compatibility) · Fish / Zsh · Alacritty / Kitty · Zed  
> **Philosophy:** Zero resident daemons, zero background polling watchers, sub-100ms atomic compilation, instantaneous IPC/POSIX signal hot-reloading, ephemeral sandboxing, and strict disk/memory minimalism.

---

## 1. System Philosophy & Invariants

The theme engine bridges Omarchy community themes, Base46/NvChad palettes, and desktop applications into a unified, high-performance orchestration system designed specifically for minimal Linux workstations.

### Core Architecture Invariants:
1. **Zero Resident Daemons:**
   - No background watchers, no cron polling loops, no memory-resident theming services.
   - Execution is purely on-demand: CLI invocation (`theme-set`, `omarchy-import`) or launcher (`rofi-theme`).
2. **Sub-100ms Wall-Clock Switching:**
   - Pre-rendered Schema 1 canonical JSON cache (`~/.cache/theme/themes/`).
   - Single-pass `/proc` process scan across all running applications.
   - Total switch latency is typically **30ms – 80ms**.
3. **Transactional Staged Compilation (`.next/`):**
   - All templates are rendered into an isolated staging directory (`~/.local/state/theme/.next/`).
   - Atomic promotion via `os.replace`. If any render fails or is zero-sized, zero live files are modified.
4. **Disk Space Discipline & Ephemeral Sandboxing:**
   - Git repository imports clone shallowly (`--depth 1 --quiet`) into a temporary PID-isolated sandbox (`~/.cache/theme/import-tmp/{owner}_{repo}_{pid}`).
   - Immediately after passive data extraction, the entire cloned directory is **unconditionally deleted** via `finally: shutil.rmtree(clone_dir)`, preventing any disk bloat.
5. **Sway / Wayland Environment Authority:**
   - Third-party themes targeting Hyprland/Hyprlock are sanitized: foreign window manager configs (`hyprland.conf`, `hyprlock.conf`, `hypridle.conf`) and arbitrary scripts (`*.sh`, binaries) are strictly ignored and never executed.
6. **Hardware Display Saturation Authority (`apply-vibrance`):**
   - In `AsusMuxDgpu` (active mode): Handled directly in the NVIDIA display pipeline via NVKMS ioctls (`nvibrant 0 0 <val>`) configured at `~/.config/nvibrant` (value `614` / `800`).
   - In `Hybrid`: Handled via Intel CRTC CTM at 1.40 saturation (`~/.config/vibrance`).
   - Unified via the canonical one-shot helper `~/.local/bin/apply-vibrance`.
   - `vkBasalt` vibrance remains completely disabled (`ENABLE_VKBASALT=0`), preventing any GPU shader or frame latency overhead in CS2 and Vulkan games.
7. **MangoHud Protection:**
   - `~/.config/MangoHud/MangoHud.conf` is managed by chezmoi and remains immutable. The theme engine never modifies it.

---

## 2. Architecture Overview

```text
       UPSTREAM SOURCES
 (Omarchy Repos / Base46 Lua / Custom)
                │
                ▼
        omarchy-import / theme-sync
                │
                ├─► Ephemeral Sandbox Cloned (~/.cache/theme/import-tmp/)
                ├─► Passive Parsing (TOML / YAML / Alacritty / Kitty / Btop)
                ├─► Wipes Cloned Sandbox Instantly (Zero Disk Bloat)
                ▼
      ~/.cache/theme/themes/*.json  (Schema 1 Canonical Cache)
                │
                ▼
      theme-set <name>  (<100ms execution)
                │
  ┌─────────────┴────────────────────────┐
  ▼                                      ▼
STAGE COMPILATION (.next/)             RUNTIME DISPATCH (IPC / Signals)
- Zed (nvchad-system.json)             - Zed: inotify touch (os.utime)
- Alacritty (alacritty.toml)           - Sway: swaymsg client.* / bar
- Sway (sway.conf)                     - Neovim: RPC domain socket eval
- Cava (cava.conf)                     - Cava: SIGUSR2
- btop (btop.theme)                    - btop: SIGUSR2
- Yazi (yazi.toml)                     - Yazi: DDS emit app:theme
- GTK (gtk.css)                        - Mako: makoctl reload
- Mako (mako.conf)                     - GTK: GSettings D-Bus
  │
ATOMIC PROMOTION (os.replace)
~/.local/state/theme/*
```

---

## 3. Schema 1 Standard

All themes are compiled into a normalized, type-safe Schema 1 JSON format:

```json
{
  "schema": 1,
  "name": "drac",
  "display_name": "Drac",
  "type": "dark",
  "accent": "#1e90ff",
  "source": {
    "provider": "omarchy",
    "repository": "https://github.com/ShehabShaef/omarchy-drac-theme",
    "author": "ShehabShaef",
    "commit": "6fd9e1a"
  },
  "capabilities": {
    "palette": true,
    "wallpaper": true,
    "cava": true,
    "terminal": true,
    "alacritty": true,
    "kitty": true,
    "ghostty": true,
    "btop": true,
    "waybar": true
  },
  "palette": {
    "accent": "#1e90ff",
    "base_16": {
      "BASE00": "#101428",
      "BASE01": "#1b1d21",
      "BASE02": "#033259",
      "BASE03": "#555555",
      "BASE04": "#bbbbbb",
      "BASE05": "#f2f4f8",
      "BASE06": "#bbbbbb",
      "BASE07": "#ffffff",
      "BASE08": "#ff5555",
      "BASE09": "#ff6e6e",
      "BASE0A": "#f1fa8c",
      "BASE0B": "#1e90ff",
      "BASE0C": "#8be9fd",
      "BASE0D": "#50fa7b",
      "BASE0E": "#ff79c6",
      "BASE0F": "#ff92df"
    }
  },
  "derived": {
    "base_30": { ... },
    "semantic": {
      "background": "#101428",
      "surface": "#1b1d21",
      "border": "#1e90ff",
      "accent": "#1e90ff",
      "selection": "#033259",
      "foreground": "#f2f4f8"
    },
    "contrast": {
      "ratio": 16.54,
      "wcag_aa": true,
      "wcag_aaa": true
    }
  },
  "apps": {
    "cava": {
      "source": "accent",
      "gradient": 0,
      "gradient_count": 0,
      "colors": ["#1e90ff"],
      "background": "default",
      "foreground": "#1e90ff"
    }
  }
}
```

### Contrast Evaluation:
Every theme undergoes WCAG 2.1 AA relative luminance testing (`contrast_ratio(bg, fg)`). If the ratio is below `4.5:1`, the engine issues a non-destructive audit warning without mutating the author's authentic colors.

---

## 4. Universal Application Coverage & Hot-Reload Mechanics

The engine does not require theme repositories to provide application-specific files. It compiles native configurations from templates for all supported tools:

| Application | Configuration Target | Hot-Reload Mechanism | Latency |
| :--- | :--- | :--- | :--- |
| **Zed Editor** | `~/.config/zed/themes/nvchad-system.json` | `os.utime` touch on `settings.json` (inotify) | ~1ms |
| **Sway WM** | `client.*` borders & bar blocks | Batched `swaymsg` IPC commands | ~8ms |
| **Alacritty** | `~/.local/state/theme/alacritty.toml` | Inotify file watch on symlink target | Instant |
| **Cava** | `~/.config/cava/config` (`[color]` section) | `SIGUSR2` POSIX signal to running PIDs | ~2ms |
| **btop** | `~/.config/btop/themes/nvchad.theme` | `SIGUSR2` POSIX signal to running PIDs | ~2ms |
| **Neovim** | Highlights via NvChad Base46 | Unix Domain Socket RPC (`nvim --server ...`) | ~12ms |
| **Yazi** | `~/.config/yazi/theme.toml` | Data Distribution Service (`ya emit-to 0 app:theme`) | ~4ms |
| **Mako / Dunst** | `~/.config/mako/config` | `makoctl reload` / `dunstctl reload` | ~5ms |
| **GTK 3 / 4** | `~/.config/gtk-3.0/gtk.css` | GSettings D-Bus broadcast | ~10ms |

### Zed Editor Theming Mechanics:
- Zed is configured in [`~/.config/zed/settings.json`](file:///home/onyx/.config/zed/settings.json) to use the custom theme `"NvChad System"`:
  ```json
  "theme": {
      "mode": "dark",
      "light": "NvChad System",
      "dark": "NvChad System"
  }
  ```
- Whenever any theme is applied, `theme-set` renders [`~/.config/theme/templates/zed-theme.json`](file:///home/onyx/.config/theme/templates/zed-theme.json) directly into `~/.config/zed/themes/nvchad-system.json`.
- It executes `os.utime("~/.config/zed/settings.json", None)`. Zed's internal filesystem watcher instantly reloads the editor's window and syntax highlights live without closing or restarting tabs.

### Cava Audio Visualizer Mechanics:
- **No Rainbow Spectrum**: Eliminates artificial multi-color rainbow gradients across the bars.
- **Prominent Accent Theming (`gradient = 0`)**: The entire visualizer is rendered in the theme's signature accent color (`foreground = '{{accent}}'`), with `background = 'default'` ensuring the terminal's native transparency and background shine through cleanly.
- The `[color]` block in `~/.config/cava/config` is atomically updated while preserving all user audio, PipeWire input, and monstercat smoothing settings, followed by a `SIGUSR2` signal for instant live reload.

---

## 5. Dynamic Omarchy Importer (`omarchy-import`)

Located at: [`~/.local/bin/omarchy-import`](file:///home/onyx/.local/bin/omarchy-import)

The importer dynamically parses community repositories without imposing rigid directory layouts or requiring `colors.toml`:

### Format Discovery Hierarchy:
1. **Native Omarchy (`colors.toml`):** Discovered in repo root or subdirectories (`theme/`, `.omarchy/`, `src/`, etc.).
2. **TOML Palettes:** `palette.toml`, `theme.toml`, `colorscheme.toml`.
3. **YAML Palettes:** `base16.yaml`, `base24.yaml`, `colors.yaml`.
4. **Alacritty:** `alacritty.toml` / `alacritty.yml` (ANSI 0–15, cursor, and primary colors).
5. **Kitty:** `kitty.conf` (color0–15, cursor, and selection background).
6. **Ghostty:** `ghostty.conf` / `ghostty-theme`.
7. **Btop:** `btop.theme` (main_bg, title accent, selected_bg).

### Cross-Source Semantic Enrichment:
When an author distributes a theme without a master `colors.toml` (e.g. `ShehabShaef/omarchy-drac-theme`), the engine:
- Extracts the primary palette from `alacritty.toml`.
- Cross-enriches missing semantic tokens (like selection background `#033259` and foreground) from `kitty.conf` and `ghostty.conf`.
- Extracts the signature accent (`#1e90ff` Drac Blue) from cursor and Btop title definitions.
- Discovers wallpapers in `backgrounds/`, `wallpapers/`, or `wallpaper/`.
- Extracts screenshot previews (`preview.png`, `theme-preview.*`) into `~/.cache/theme/previews/`.
- **Wipes the temporary clone directory immediately upon completion.**

---

## 6. Operational CLI Reference

### Switching Themes:
```bash
# Apply a theme by name (<80ms)
theme-set drac
theme-set tokyonight
theme-set forest-green

# Launch the interactive Rofi theme picker (Native Script Mode with in-place mutations)
rofi-theme                          # Keys: Enter (Apply), Ctrl+D (Delete), Ctrl+R (Sync), Ctrl+I (Info)

# List themes (clean output for scripts and piping)
theme-ls                            # Print all theme names (1 per line)
theme-ls -l                         # Print detailed table (Name, Provider, Type, Active)

# Delete themes (interactive FZF or CLI args)
theme-rm                            # Opens interactive FZF search with live truecolor preview & multi-select!
theme-rm <theme-name>...            # Delete specific theme(s) directly
theme-ls | fzf -m | theme-rm        # Pipe custom FZF selections into theme-rm
theme-rm <theme-name> --force       # Skip interactive confirmation
theme-rm <theme-name> --dry-run     # Preview what files would be removed

# Fast Fish Shell Aliases & Native Tab-Completions
thrm <theme>                        # alias for theme-rm (supports tab-completion & interactive fzf)
thset <theme>                       # alias for theme-set (supports tab-completion)
thls                                # alias for theme-ls
thmenu                              # alias for rofi-theme
thsync                              # alias for theme-sync
```

### Importing Omarchy Themes:
```bash
# Inspect a theme's format, upstream assets, and capabilities without saving
omarchy-import --info https://github.com/ShehabShaef/omarchy-drac-theme

# Test import and schema validation in dry-run mode
omarchy-import --dry-run https://github.com/ShehabShaef/omarchy-drac-theme

# Import, convert to Schema 1, and compile into cache
omarchy-import https://github.com/ShehabShaef/omarchy-drac-theme

# Import and immediately activate on desktop
omarchy-import https://github.com/ShehabShaef/omarchy-drac-theme --apply

# Update an already imported theme if upstream git changed
omarchy-import --update https://github.com/ShehabShaef/omarchy-drac-theme

# Remove an imported theme cleanly
omarchy-import --remove drac
```

### Auditing & Diagnostics:
```bash
# Validate theme schema and contrast compliance
theme-check drac
theme-check --all

# Run full system diagnostic suite (themes, templates, apps, and hardware CTM)
theme-doctor
```

---

## 7. Performance & Verification Metrics

```text
Theme Sources
  Schema:                 1
  Omarchy imported:       169 (official catalog)
  Base46 (NvChad):        97 (core lua)
  Custom themes:          23
  ──────────────────────────────
  Total compiled:         290

Switch Wall-Clock Time:   32ms – 74ms
Background Daemons:       0 (Zero memory / CPU footprint)
Hardware Display Vibrance: Active on eDP-1 (NVKMS direct ioctl via nvibrant / CTM in Hybrid)
vkBasalt Latency:         0ms (Disabled, ENABLE_VKBASALT=0)
Disk Overhead:            0MB lingering (All clone sandboxes auto-wiped)

---

## 8. Palette Similarity / Duplicate Audit (2026-10-18)

Method: 16-color `base_16` palettes from `~/.cache/theme/themes/*.json`, compared only
dark-to-dark / light-to-light, mean Euclidean RGB distance per pair.
Scale: 0 = identical palettes; typical unrelated-theme gap = 60-110; < 30 = variant of
the same palette. Auditor: `theme-dup-audit` (installed ~/.local/bin, schema-1 aware,
union-find clustering at distance < 30). Pre-removal fleet: 292 full-palette themes.

### Removals Performed
- `omarchy-flat-dracula` — REMOVED 2026-10-18 (engine `theme-rm`, cache rebuilt; chezmoi
  81ca2c5). Palette is byte-identical to `omarchy-dracula` (distance 0.0). Canonical
  survivor: `omarchy-dracula`. Fleet after removal: 291 entries. Remaining draculas
  (`chadracula`, `chadracula-evondev`) are distinct palettes, not duplicates.

### Void / cthulhu Example (Refuted)
`void` vs `omarchy-cthulhu-colour-out-of-space` = 76.0 — clearly distinct; `void` has no
same-type neighbor within 45 distance anywhere in the fleet. Keep it. The cthulhu
variants are near-duplicates of each other instead (25.5 - 29.7). Note: the picker sorts
the active theme to the top, which can make unrelated entries look related.

### Retained Variant Clusters (documented, intentionally not removed)
Clusters closer than 30.0 (members shown with provider):

| Size | Cluster | Distances |
| :--- | :--- | :--- |
| 5 | catppuccin(base46) \| omarchy-catppuccin(custom) \| omarchy-catppuccin-dark(omarchy) \| omarchy-rainynight(omarchy) \| pastelDark(base46) | 19-32 |
| 4 | everforest(base46) \| omarchy-everforest(custom) \| omarchy-gruvbox(custom) \| omarchy-gruvbox-material(omarchy) | 25-28 |
| 3 | omarchy-blood-and-bone \| omarchy-kanagawa-dragon \| omarchy-terminus (all omarchy) | 27-30 |
| 3 | omarchy-cthulhu-colour-out-of-space [ACTIVE 2026-10-18] \| omarchy-cthulhu-deep-one \| omarchy-cthulhu-rlyeh (all omarchy) | 25-30 |
| 2 | doomchad \| onedark (base46) | 22.3 |
| 2 | omarchy-dune-messiah \| omarchy-quattrocento-light (omarchy) | 26.4 |
| 2 | omarchy-futurist \| omarchy-oligarchy (omarchy) | 28.0 |
| 2 | omarchy-gand \| omarchy-theme-year-linux-desktop (omarchy) | 27.2 |
| 2 | omarchy-ghost-pastel \| omarchy-hermarchy (omarchy) | 28.4 |
| 2 | omarchy-nord(custom) \| onenord(base46) | 26.7 |
| 2 | omarchy-one-dark \| omarchy-one-dark-pro (omarchy) | 19.7 |
| 2 | omarchy-periphery \| omarchy-starsend (omarchy) | 20.7 |
| 2 | omarchy-rose-pine-dark \| omarchy-rose-pine-moon (omarchy) | 27.9 |
| 2 | omarchy-tokyo-night(custom) \| omarchy-tokyoled(omarchy) | 20.2 |
| 2 | rxyhn \| yoru (base46) | 16.5 |
| 2 | sweetpastel \| tundra (base46) | 27.0 |

Borderline pairs (30-32, review later): decay/jabuti (31.0), catppuccin/sweetpastel
(31.8), everblush/vscode_dark (31.4), catppuccin(base46)/omarchy-catppuccin (31.5).

Pairs like one-dark/one-dark-pro and rose-pine-dark/moon are intentional upstream
variants; most ecosystems keep both. Judgment call per cluster: exact-duplicate palette-level redundancy is safe to prune;
family variants usually earn their spot.

### Pruning Workflows
- Single: `theme-rm <name> --force`
- Interactive multi-select: `theme-ls | fzf -m | theme-rm`
- Inside picker: `rofi-theme`, select, Ctrl+D (active theme is immune)
- After manual deletion of source JSON, run the engine remover so manifest + cache stay
  synchronized; raw rm is never sufficient (compiled cache lives in ~/.cache/theme).
```
