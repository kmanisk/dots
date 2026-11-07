# Unified Theme Engine Architecture & System Documentation

> **Target Machine:** CachyOS rolling (BORE/EEVDF, x86-64-v3) · Sway / Wayland (with i3/X11 compatibility) · Fish / Zsh · Alacritty / Kitty · Zed  
> **Philosophy:** Zero resident theming daemons, transactional compilation, palette-faithful normalization, ordered live reload, conservative deduplication, ephemeral import sandboxes, and strict disk/memory discipline.

---

### Curated solid-color palette collection (2026-11-07)

Twelve additional popular/familiar Base16 palette variants were imported as standalone **custom** themes; no wallpaper files are needed or downloaded. They use `assets.background_mode="solid"`, which deliberately bypasses the normal wallpaper-donor resolution and uses the theme's own Sway solid background. The new catalog has **339** visible picker themes; the 2026-11-01 counts below are retained as historical baseline measurements. See [`curated-solid-palettes.md`](curated-solid-palettes.md) for the exact IDs, upstream revision, tests, and removal procedure.

---

## 1. System Philosophy & Invariants

The theme engine bridges Omarchy community themes, Base46/NvChad palettes, and desktop applications into a unified, high-performance orchestration system designed specifically for minimal Linux workstations.

### Core Architecture Invariants:
1. **Zero Resident Daemons:**
   - No background watchers, no cron polling loops, no memory-resident theming services.
   - Execution is purely on-demand: CLI invocation (`theme-set`, `omarchy-import`) or launcher (`rofi-theme`).
2. **Fast, Ordered Wall-Clock Switching:**
   - Pre-rendered Schema 1 canonical JSON cache (`~/.cache/theme/themes/`).
   - Single-pass `/proc` process scan across all running applications.
   - Reload IPC is short-lived and bounded, but it is deliberately ordered instead of detached. On the live F16 workload measured 2026-11-01, same-theme runs averaged about **169ms with `--no-nvim`** and **247ms with the Base46 refresh enabled**.
3. **Transactional Staged Compilation (`.next/`) with Single-Writer Locking:**
   - `~/.local/state/theme/.lock` serializes every mutation with `fcntl.flock()`, including `--next` / `--prev` resolution.
   - All templates are rendered into `~/.local/state/theme/.next/` while that lock is held.
   - Atomic promotion via `os.replace`. If any render fails or is zero-sized, zero live files are modified.
4. **Disk Space Discipline & Ephemeral Sandboxing:**
   - Git repository imports clone shallowly (`--depth 1 --quiet`) into a temporary PID-isolated sandbox (`~/.cache/theme/import-tmp/{owner}_{repo}_{pid}`).
   - Palette/config data is parsed passively; selected repository wallpapers are copied into the persistent `~/.local/share/theme/wallpapers/upstream/<theme>/` cache, then the cloned repository is **unconditionally deleted** via `finally: shutil.rmtree(clone_dir)`.
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
      theme-set <name>
                │
       fcntl mutation lock
                │
  ┌─────────────┴────────────────────────┐
  ▼                                      ▼
STAGE COMPILATION (.next/)             ORDERED RUNTIME DISPATCH
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

`theme-sync` uses deterministic JSON ordering plus atomic write-if-changed semantics. It prunes generated cache/preview/NvChad artifacts whose source themes disappeared, preserves hand-written Neovim themes, and runs the conservative duplicate policy before exposing the picker catalog. `~/.cache/theme/dedup.json` records every suppressed entry and its canonical survivor.
It also emits `~/.cache/theme/picker-index.json`, a compact 327-entry row index containing only theme ID, swatches, and search metadata. Normal `rofi-theme` startup reads this single file and the active palette; it does not perform source freshness scans or automatic full sync. Missing cache remains a recovery case, while imports/deletes synchronize explicitly and Ctrl+R remains the user-requested refresh path.

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

### Palette Fidelity and Contrast Enforcement:
The canonical palette is author-first: syntax hues are never replaced with generic red/green/blue targets. For imported Omarchy themes, explicit semantic values from `colors.toml` are preserved under `authored.semantic` / `authored.base_30`, while generated compatibility aliases are never re-consumed as author input on later syncs.

Readability adjustments are lightness-only, so hue and saturation remain theme-specific. The current invariants are: body foreground `>= 4.5:1`, syntax roles `>= 3.0:1`, focused Sway borders `>= 3.0:1`, and inactive/floating-window borders `>= 1.7:1` against the active background. Background luminance is authoritative for light/dark polarity when upstream metadata is wrong.

---

## 4. Universal Application Coverage & Hot-Reload Mechanics

The engine does not require theme repositories to provide application-specific files. Generated templates remain the universal fallback, but Omarchy repositories now have **author-app-profile precedence**: when a selected repository ships a recognized application theme, the importer preserves its safe color/profile data and `theme-set` uses those app-specific colors before synthesized values. It never imports third-party fonts, geometry, keybindings, commands, Hyprland configuration, or plugin/dependency declarations.

Fresh imports embed these profiles in canonical Schema 1 JSON (`assets.upstream_apps_version = 3`). Older Omarchy imports self-heal through the daemonless `theme-upstream-apps hydrate <theme>` helper: a blobless Git tree scan fetches only the small supported text files into `~/.local/share/theme/upstream-apps/<theme>.json`, outside the theme-switch critical path, and conditionally reapplies only if that theme is still active. Generated fallback remains immediate while this happens.

Supported authored runtime profiles are Alacritty, Kitty, btop, Cava, and Mako. Foot is the primary terminal adapter: when an Omarchy repository ships Alacritty and/or Kitty colors, `theme-set` translates them directly into Foot with `alacritty.toml` first, Kitty filling missing roles, and normalized generated colors as the per-value fallback. This preserves the author's background/foreground, cursor, selection, and ANSI 0-15 colors while keeping all Foot behavior local. Ghostty, Chromium frame color, and requested icon-theme metadata are also parsed/recorded for provenance, but are not forced when the local runtime has no safe adapter or required asset; for example a missing upstream-requested icon theme never replaces the installed workstation icon theme. Neovim continues to use the validated generated Base46 palette rather than executing untrusted upstream Lua.

The application targets are:

| Application | Configuration Target | Hot-Reload Mechanism | Latency |
| :--- | :--- | :--- | :--- |
| **Zed Editor** | `~/.config/zed/themes/nvchad-system.json` | `os.utime` touch on `settings.json` (inotify) | ~1ms |
| **Sway WM** | `client.*` borders & bar blocks | Batched `swaymsg` IPC commands | ~8ms |
| **Alacritty** | `~/.local/state/theme/alacritty.toml` | Inotify file watch on symlink target | Instant |
| **Kitty** | `~/.config/kitty/kitty-colors.conf` | Native config reload signal from `theme-set` | Instant |
| **Foot** | `~/.config/foot/foot-colors.ini` | Author Alacritty/Kitty palette -> Foot conversion + targeted OSC hot reload | Instant |
| **Cava** | `~/.config/cava/config` (`[color]` section) | `SIGUSR2` POSIX signal to running PIDs | ~2ms |
| **btop** | `~/.config/btop/themes/nvchad.theme` | `SIGUSR2` POSIX signal to running PIDs | ~2ms |
| **Neovim** | Highlights via NvChad Base46 | Verified Unix Domain Socket RPC (`nvim --server ...`), with normal-startup headless cache repair when no live socket succeeds | Bounded |

| **Yazi** | `~/.config/yazi/theme.toml` | Data Distribution Service (`ya emit-to 0 app:theme`) | ~4ms |
| **Mako / Dunst** | `~/.config/mako/config` | `makoctl reload` / `dunstctl reload` | ~5ms |
| **GTK 3 / 4** | `~/.config/gtk-3.0/gtk.css` | GSettings D-Bus broadcast | ~10ms |

Neovim presentation follows theme polarity rather than hardcoded editor state. Dark themes keep the existing transparent-terminal presentation, while light themes force Base46 `transparency = false` so `Normal` receives the theme's light background instead of exposing an older/darker terminal surface. `lua/options.lua` does not force `background=dark`; Base46's compiled `defaults` cache owns that option. `theme-set` applies the same polarity through live NvChad RPC and headless cache refresh, so dark/light switches do not require restarting Neovim.

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
- **Author profile first:** if an Omarchy repository ships `cava_theme`/`cava.conf`, its validated ordered gradient colors, gradient count, foreground, and background are preserved. Aetheria is the regression reference: its original 8-color gradient is rendered exactly.
- **Generated fallback:** when no upstream Cava profile exists, the visualizer keeps the previous clean single-accent behavior (`gradient = 0`, `background = 'default'`). Cobalt2 currently follows this fallback because its repository does not ship a Cava file.
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
7. **Btop:** `btop.theme` (complete safe `theme[...]` color map, including graph gradients).

For Omarchy repositories, recognized application files are also retained as structured `apps.*` profiles: Alacritty ANSI/cursor/selection colors, Kitty ANSI plus tabs/borders/marks, Ghostty palette metadata, btop's authored graph/box colors, Cava gradients, unambiguous Mako colors, Chromium frame color, and requested icon-theme name. This is data parsing only; executable/configuration behavior is not copied from the repository.

### Cross-Source Semantic Enrichment and Gallery Reconciliation:
When an author distributes a theme without a master `colors.toml`, the engine extracts the strongest available terminal/TUI palette and cross-enriches missing cursor, selection, foreground, accent, wallpaper, and preview data. When `colors.toml` exists, its semantic background/foreground levels, accent, selection, muted color, and `active_border_color` take precedence. Wallpaper discovery treats conventional `backgrounds/`, `wallpapers/`, and `bg/` paths as authoritative and preserves every image in those sets with no numeric cap. Non-UI images elsewhere in the repository are considered only when no conventional wallpaper path exists, so lock-screen/README/support artwork is never mixed into a valid background set. All selected images are preserved locally before the temporary clone is removed.

`omarchy-import --catalog` prefers Omarchy's published validated registry catalog and checks out each registry-pinned commit when that endpoint is reachable. If the registry CDN is unavailable, it falls back to the current `omarchy.org/themes` gallery and repository HEAD, then to legacy endpoints only as a last resort. The importer canonicalizes one local JSON file per repository, removes imports no longer listed, and mirrors the resulting imported directory back into chezmoi. A dead catalog link is reported as unreachable and is not silently replaced by a third-party mirror. During the 2026-11-01 live reconciliation the registry hostname did not resolve from this machine, so the gallery fallback was used: 233 entries were listed, 232 were reachable/imported, and `ankur311sudo/gruvu` returned repository-not-found.

### Centralized Theme Wallpaper Library

The persistent wallpaper root is `~/.local/share/theme/wallpapers/`: shared matched assets live under `assets/`, repository-authored Omarchy backgrounds live under `upstream/<theme>/`, and `manifest.json` records provenance plus shared-library mappings. The former `~/.cache/theme/wallpapers/` tree is no longer active.

Wallpaper source precedence is repository- and semantic-scoped. Repository-backed Omarchy themes (community imports plus official built-ins that point at GitHub) use **only images shipped by their own theme scope**. For standalone repositories that is normally the repository's `backgrounds/`/`wallpapers/` directory; for shared monorepos such as `omacom/omarchy`, discovery version 3 restricts the set to the canonical root declared by that built-in theme (for example `themes/everforest/backgrounds/`), never sibling theme directories. Non-Omarchy palettes never use the global Wallhaven mapping at runtime. `theme_engine.wallpaper_policy` resolves exact normalized name/display matches and explicit aliases from `~/.config/theme/wallpaper-aliases.json` first; if neither exists, `~/.config/theme/wallpaper-preferences.json` classifies the palette into artistic oil/illustration, light artistic, natural art, terminal technical, blueprint technical, or synth technical and chooses only from a curated Omarchy donor pool. Donor ranking keeps light/dark polarity, scores actual theme palette colors, and uses the configured artistic preference only as a ranking bias. The selected palette/theme never changes; only wallpaper ownership is borrowed. Import/update preserves every relevant deterministic repository image it discovers with no numeric count cap. If first use finds the resolved Omarchy repository uncached, or finds a legacy manifest without repository discovery version 3, `theme-set` starts one detached `theme-wallpaper hydrate <theme>` job; network I/O stays outside the theme-switch critical path. Legacy five-item caches are re-discovered from a blobless Git tree, existing matching files are reused, and only newly discovered backgrounds are downloaded. A completed wallpaper is applied only if that theme is still active. Solid `Sway` background remains the permanent fallback only when no usable donor exists.

`theme-wallpaper-library` remains an explicit one-shot maintenance/audit command for the historical shared matched pool. Its 327-theme Wallhaven mapping and 63 local assets can remain in `manifest.json`/`assets/` for provenance and experiments, but neither `theme-set` nor `theme-wallpaper` reads those mappings as a runtime wallpaper source.

Automated shared-library selection remains conservative about generative-AI provenance: General/SFW results only, at least 1920x1200, 16:9 or 16:10, favorites-first, explicit `AI art` search exclusion, metadata rejection for known AI tags/source domains, and an upload cutoff before 2022-01-01. Repository-authored Omarchy images are trusted as part of the selected upstream theme repository rather than replaced by unrelated palette matches.

`theme-wallpaper next|prev|random|set` persists the selected file through `~/.config/current_wallpaper`. Image binaries remain local data outside Git; source/provenance and candidate paths remain in chezmoi. Full policy, storage, recovery, and rebuild details are in [`wallpaper-library.md`](wallpaper-library.md).

Sway controls remain daemonless:
- `Alt + Shift + M` or `Ctrl + Shift + M`: open the theme picker.
- `Win + Shift + W` or `Win + Ctrl + W`: next wallpaper from the active theme's allowed source set.
- `Win + Ctrl + Shift + W`: previous wallpaper.
- The retired `ds3-wallpaper` helper is not used by the theme system; the old static DS3 image pack may remain on disk as ordinary images.

---

## 6. Operational CLI Reference

### Switching Themes:
```bash
# Read-only preflight before applying anything
theme-set --check drac
theme-set --check-all

# Apply a theme by name
theme-set drac
theme-set tokyonight
theme-set forest-green

# Launch the interactive Rofi theme picker (Native Script Mode)
# Menu rows come from ~/.cache/theme/picker-index.json, so normal open never scans sources or reparses 327 JSON files.
# Enter closes immediately and queues the validated theme-set transaction; Ctrl+R is the explicit cache refresh.
rofi-theme                          # Keys: Enter (Apply), Ctrl+D (Delete), Ctrl+R (Sync), Ctrl+I (Info)

Launcher UI outside the theme picker remains source-owned as well. The Alt+g Fuzzel game menu in `~/.local/bin/rofi-games` uses descriptive labels only; its Elden Ring row currently advertises the verified `LSFG 2x (stable)` profile and dispatches to `eldenring-lsfg`. Similarly, the `Caps + w` process killer menu in `~/.local/bin/rofi-pkill` uses native Wayland Fuzzel dmenu mode styled with the active theme border and Papirus icons, displaying clean single-line entries (`Application Name — Window Title`) with zero metric or divider bloat.

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

### Theme Wallpapers:
```bash
# Normal local cycling for the active theme
theme-wallpaper next
theme-wallpaper prev
theme-wallpaper random

# Inspect the theme's wallpaper policy, repository candidates and local files
theme-wallpaper list japan-night

# Select a specific local slot from the theme's full discovered repository set
theme-wallpaper set 2 japan-night

# Historical shared-library maintenance/audit only; not used by runtime switching
theme-wallpaper-library plan
theme-wallpaper-library status
theme-wallpaper-library audit

# Inspect a non-Omarchy palette donor mapping
theme-wallpaper list gruvchad
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

## 7. Current Verification Metrics

Verified on 2026-11-01 after gallery reconciliation and full recompilation:

```text
Source files present:         351
  Omarchy community imports: 232 reachable repositories
  Base46 source themes:       97
  Built-in/custom themes:     22
Canonical inputs compiled:    350
Pre-dedupe cache names:       347

Exposed unique themes:        327
Suppressed exact/near copies: 20
Schema/contrast validation:   327 passed, 0 warnings, 0 failures
Resident theming daemons:     0
```

A full mathematical audit over every exposed theme measured these worst-case ratios:

```text
Body foreground:       4.513:1  (required >= 4.5)
Syntax roles:           3.002:1  (required >= 3.0)
Semantic/focused border:3.001:1  (required >= 3.0)
Inactive border:        1.700:1  (required >= 1.7)
```

Synthwave '84 is a regression reference for palette identity: accent `#ff00ff`, its nominal Base16 green role remains purple (`#8f00ff`), and its purple role remains `#ff00ff`; the engine does not inject a generic green hue.

---

## 8. Duplicate Policy

The picker/cache exposes only unique or materially distinct themes; source definitions remain available for provenance and reproducible recompilation. `theme-sync` writes the suppression manifest to `~/.cache/theme/dedup.json`, and `theme-dup-audit` reports both suppressed entries and the closest surviving same-family pairs.

A theme is suppressed when either condition holds:

1. **Exact duplicate:** same full Base16 palette and same light/dark type.
2. **Near duplicate:** same normalized theme family and light/dark type with mean per-color RGB distance `<= 70`. Cosmetic family suffixes such as `-pro`, `-moon`, and `-oled` are normalized; meaningful identities such as `gruvbox-material` and `kanagawa-dragon` are not collapsed into their base families.

The 2026-11-01 fleet suppresses 20 exact/near copies. Remaining same-family pairs that exceed the threshold stay visible as real variants. The source files are not destructively deleted merely because the generated picker hides a duplicate; this prevents upstream Base46 or community sources from being damaged and makes the decision fully reversible from the manifest.

---

## 9. Future Plans & Extension Roadmaps

Planned expansions to the theme architecture are documented in detail within the implementation specification:

- **TUI Daily-Driver Expansion:** See [theme-implementation.md#8-tui-daily-driver-expansion-roadmap](file:///home/onyx/.local/share/chezmoi/docs/theme/theme-implementation.md#L241) for CAVA, FZF, Bat, Delta, Lazygit, and Zellij integrations.
- **Dynamic Browser UI Retheming (Brave / Chromium):** See [theme-implementation.md#9-future-plans-dynamic-browser-ui-retheming-brave--chromium](file:///home/onyx/.local/share/chezmoi/docs/theme/theme-implementation.md#L257) for engineering analysis, trade-off evaluations between Matugen unpacked extensions vs Omarchy enterprise managed policies (`BrowserThemeColor`), and technical hooks for browser frame theming.
