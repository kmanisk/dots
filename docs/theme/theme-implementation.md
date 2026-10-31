# Desktop Theme Orchestration & Live-Reload Architecture

> **Target System:** CachyOS (x86-64-v3) · Sway / Wayland (with i3/X11 compatibility) · Fish / Zsh · Alacritty  
> **Philosophy:** Zero resident daemons, zero background polling watchers, atomic compilation, and bounded ordered IPC/RPC hot-reloading.

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
                    theme-set <name>
                              │
                    fcntl mutation lock
                              │
        ┌─────────────────────┴─────────────────────┐
        ▼                                           ▼
  STAGE COMPILATION (.next/)              ORDERED RUNTIME DISPATCH
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

Located at: [`~/.local/bin/omarchy-import`](file:///home/onyx/.local/bin/omarchy-import)

Omarchy themes (designed for Hyprland/Arch) provide canonical palettes in `colors.toml`. The importer maps them directly into our native Base16 and Base30 schemas.

### What it does:
1. **Source Ingestion:** Accepts a local directory or GitHub repository URL (e.g. `https://github.com/omarchy/omarchy-batman`).
2. **Palette Normalization:** Converts `colors.toml` into:
   - Full Base16 mapping (`base00`–`base0F`).
   - Extended Base30 mapping (`black`, `white`, `folder_bg`, `grey_fg`, `one_bg`, etc.).
   - Explicit signature accent resolution (`folder_bg` / `base0D` priority).
3. **Asset Handling:** Extracts a preview for launchers and records at most five deterministic wallpaper candidates from the repository, preferring its primary `backgrounds/` directory. Wallpaper bytes are not retained from the import clone.
4. **Neovim Lua Generator:** Writes `~/.config/nvim/lua/themes/<name>.lua` containing dual-cased Base16 keys (`base0A` and `base0a`) to ensure complete compatibility with NvChad's Base46 compiler.
5. **Theme Cache Update:** Writes the compiled JSON directly into `~/.cache/theme/themes/<name>.json`.

### `theme-sync` cache and uniqueness discipline
- Canonical JSON is emitted with deterministic key ordering and atomic write-if-changed semantics, so semantically unchanged themes keep their mtimes.
- Removed/renamed source themes are pruned from the canonical JSON cache, generated preview cache, and only those Neovim Lua files carrying the `theme-sync` generated header.
- Preview PNGs are regenerated only when canonical content changes; byte-identical previews are not rewritten repeatedly.
- `theme_engine.dedupe` suppresses exact duplicate palettes and same-family/light-dark near duplicates with mean Base16 RGB distance `<= 70`. The decision manifest is `~/.cache/theme/dedup.json`; source definitions remain intact for provenance and reproducibility.
- The 2026-11-01 reconciled fleet has 351 source files; provider/name reconciliation compiles 350 canonical inputs into 347 pre-dedupe cache names, and the picker exposes 327 unique themes after suppressing 20 exact/near copies. A no-change full `theme-sync --force` remains sub-second on this workstation, including dedupe and preview freshness checks.

### Omarchy catalog reconciliation
- `omarchy-import --catalog` prefers Omarchy's published validated registry catalog. Registry entries may pin a validated Git commit; the importer treats failure to fetch/check out that commit as an error rather than silently falling back to repository HEAD.
- If the registry CDN cannot be reached, the importer falls back to the current `omarchy.org/themes` gallery, then legacy catalog endpoints only as a final compatibility path.
- Each reachable catalog entry is refreshed from its Git repository with a shallow passive clone; one canonical JSON file is kept per repository and the resulting live import set is mirrored into chezmoi.
- Catalog names/provenance replace unreliable README title heuristics. Imports no longer listed are removed, except that an active-theme safeguard prevents deleting the live selection mid-run.
- During the 2026-11-01 live reconciliation, the registry hostname did not resolve from this machine, so the gallery fallback was used. It exposed 233 repositories; 232 were reachable. `https://github.com/ankur311sudo/gruvu` returned repository-not-found and is intentionally not replaced from an unofficial mirror.

### On-demand wallpaper cache (`theme-wallpaper`)
- Every reachable imported community theme currently exposes between one and five repository-relative wallpaper candidates; future imports use the same hard cap of five. Twenty-one of the 22 locally maintained official Omarchy built-ins are also mapped to the matching `omacom/omarchy/themes/<name>/backgrounds/` directory. Legacy `omarchy-osaka-jade` has no exact current upstream theme directory and remains intentionally unmapped rather than borrowing wallpapers from the distinct current `jade-horse` theme.
- Candidate ranking prefers the primary `backgrounds/` directory and natural filename order. Old/alternate/vertical/portrait archives are fallback-only, preventing a theme with dozens of historical images from bloating metadata or local storage.
- `theme-wallpaper fetch <theme>` downloads only that theme's selected candidates from `raw.githubusercontent.com` at the source commit recorded by the importer. PNG/JPEG/WebP magic is validated and each image is capped at 50 MiB.
- First-use fetching is still strictly explicit/lazy: importing or applying a theme does not download wallpapers. When the user invokes `theme-wallpaper`, up to five files are transferred concurrently through libcurl's parallel path; a per-theme `flock` prevents repeated hotkeys from launching duplicate fetches, and the validated Python downloader is retained only as a per-file fallback. On 2026-11-01 the old serial Aetheria path measured 35.1s; the libcurl path fetched five Ayaka images (~32 MiB) in 2.33s inside the real helper on the same workstation, while network/CDN conditions remain variable.
- Downloaded images live only in `~/.cache/theme/wallpapers/<theme>/`; the persistent source-of-truth stores paths/provenance, not image binaries. Selection state is one filename under `~/.local/state/theme/wallpaper/<theme>`.
- `theme-wallpaper next|prev|random|set` uses the existing `wset` helper so `~/.config/current_wallpaper` and Sway stay synchronized. `theme-set` only restores an already-cached selection and never performs network access during an ordinary theme switch.
- Sway binds `Win + Shift + W`, `Alt + Shift + W`, and `Win + Ctrl + W` to next, with `Win + Ctrl + Shift + W` for previous. The obsolete `ds3-wallpaper` helper has been removed; the first theme-wallpaper press may fetch the current theme's <=5-image set and subsequent presses are local.

---

## 3. Serialized Atomic Rethemer (`theme-set`)

Located at: [`~/.local/bin/theme-set`](file:///home/onyx/.local/bin/theme-set)

Correct ordering is preferred over detached fire-and-forget reloads. On the live F16 workload measured 2026-11-01, repeated same-theme applications averaged about **169ms with `--no-nvim`** and **247ms with the ordered Base46 refresh enabled**.

### Guarantees:
- **Single-Writer Mutation Lock:** `~/.local/state/theme/.lock` is held with `fcntl.flock()` across relative-theme resolution, staged compilation, atomic promotion, and live dispatch. Rapid or concurrent invocations serialize instead of sharing `.next/` concurrently.
- **Two-Phase Staged Compilation:** All templates are rendered into `~/.local/state/theme/.next/` and validated for non-zero size before promotion. If any template fails, zero live files are modified.
- **Atomic Promotion:** Promotes files using `os.replace` directly into target paths and symlink targets.
- **Single-Pass `/proc` Process Discovery:** Scans `/proc` once for the supported live applications rather than spawning repeated `pgrep` / `pkill` processes.
- **Ordered Bounded IPC:** Short-lived Sway, Mako/Dunst, Yazi, GTK, wallpaper, and custom-hook reload commands are waited on with short timeouts while the mutation lock is held. A previous theme can no longer finish its IPC after a newer switch.
- **Reliable Neovim Reload:** Live RPC calls now surface Base46 errors instead of swallowing them inside `pcall`, clear cached theme modules before recompilation, and run to completion instead of daemon threads that could be terminated at interpreter exit. A successful live RPC is also the disk-cache compile, so the old redundant headless compile is skipped. If no live socket succeeds, `theme-set` uses normal headless NvChad startup to rebuild the cache. `~/.local/share/nvim/base46/current_theme` is advanced only after a verified compile; on failure it is deliberately left stale so the next Neovim startup retries instead of trusting stale colors.

---

## 4. Live Hot-Reload Mechanisms

| Application | Hot-Reload Mechanism | Latency | Details |
| :--- | :--- | :--- | :--- |
| **Sway** | Batched `swaymsg` IPC | ~8ms | Updates `client.focused`, `focused_inactive`, `unfocused`, `urgent` borders and swaybar statusline/workspaces without reloading the window manager. |
| **Alacritty** | File Watcher / Inotify | Instant | `~/.config/alacritty/alacritty.toml` symlinks to `~/.local/state/theme/alacritty.toml`. Atomic replacement triggers native reload. |
| **Foot** | OSC palette update + per-client generated include | Instant | `theme-set` writes OSC 10/11/12/17/19 and OSC 4 palette updates only to PTYs owned by live Foot windows. It deliberately does not send SIGUSR1/SIGUSR2 because Foot 1.28 uses those signals only to select the server's already-cached `[colors-dark]` / `[colors-light]` sections. A zero-resident `~/.local/bin/footclient` exec wrapper adds `-o include=~/.config/foot/foot-colors.ini` so every newly created server client reads the current generated palette without restarting the long-lived Foot server. |
| **Neovim (NvChad)** | Verified RPC via Unix Domain Sockets | Bounded | Queries live sockets in `$XDG_RUNTIME_DIR/nvim.*`, clears the selected theme module from Lua's cache, reloads Base46 with `vim.g.system_theme_sync = true`, and treats the resulting shared Base46 disk cache as current only after RPC/headless compilation succeeds. |
| **Zed** | Atomic file + `os.utime` touch | Instant | Atomic rewrite of `~/.config/zed/themes/nvchad-system.json` followed by an `os.utime` touch on `~/.config/zed/settings.json`. |
| **btop** | Direct POSIX signal | ~2ms | Sends `SIGUSR2` directly to discovered `btop` PIDs via `os.kill`. |
| **Mako / Dunst** | Daemon Control CLI | ~5ms | Dispatches `makoctl reload` or `dunstctl reload`. Updates notifications, OSD sliders, and system alerts. |
| **Yazi** | Data Distribution Service (DDS) | ~4ms | Broadcasts `app:theme` to all active instances using `ya emit-to 0 app:theme`. |
| **GTK 3 / 4** | GSettings IPC / On-Launch | ~10ms | Updates GSettings `color-scheme` and `gtk-theme` over D-Bus for newly launched apps. Running GTK3 file managers (Thunar/Nemo) do not hot-reload in-place without a resident settings daemon (see Section 6). |

---

## 5. Legibility, Contrast & Styling Invariants

### 1. Palette Fidelity and Global Contrast Invariants
- Schema normalization never replaces authored syntax hues with generic target hues. Current Omarchy semantic colors are retained separately as `authored.semantic` / `authored.base_30`, so generated compatibility aliases cannot feed back into later normalization and drift the palette.
- Contrast correction changes HSL lightness only. Required minima are body foreground `4.5:1`, syntax roles `3.0:1`, semantic/focused Sway border `3.0:1`, and inactive/floating border `1.7:1` against the theme background.
- Background luminance overrides incorrect upstream light/dark metadata when the palette is clearly light or dark; this prevents runtime correction from moving colors in the wrong direction.
- Full-fleet verification on 2026-11-01 covered all 327 exposed themes with zero failures. Runtime `theme-set` normalization now reapplies the 3.0:1 non-text floor after selecting authored `base_30` syntax aliases, so those aliases cannot undo Schema 1 contrast correction; observed minima are `4.513`, `3.002`, `3.001`, and `1.700` respectively.
- Synthwave '84 is a regression reference: accent `#ff00ff`, Base16 green role `#8f00ff`, purple role `#ff00ff`. Its nominal role labels do not force green/blue hues into the authored purple palette.

### 2. Yazi Light & Dark Hot-Reload Contrast
- **The Problem:** In `~/.config/theme/templates/yazi.toml`, unstyled files previously had `{ mime = "*", fg = "{{white}}" }`. In light mode, this resulted in white-on-white unreadable text on running instances.
- **The Fix:** Changed fallback rules to dynamic `{{fg}}` (`{ mime = "*", fg = "{{fg}}" }`) and inverted bars to `{ fg = "{{bg}}", bg = "{{fg}}" }`.
- **DDS Reload:** `theme-set` broadcasts `ya emit-to 0 app:theme` on every switch so running Yazi sessions adapt immediately without restarting.
- **Manual Keybind:** Bound `<F5>` in `~/.config/yazi/keymap.toml` to `app:theme` for on-demand reload.

### 3. Compact Theme Picker UI (Rofi)
- **Typography:** `Iosevka Nerd Font Mono` matches the current system UI/terminal family. The picker uses 12pt body/prompt text and a 10pt hint row so theme names, `[ACTIVE]`, and spectrum swatches stay aligned without oversized chrome.
- **Spectrum Swatches:** Shows the 8 syntax spectrum colors (`base08`–`base0F`) in aligned monospace columns (`● ● ● ● ● ● ● ●`).
- **Selection:** Selected items use the active theme accent while the search/hint rows stay flat and sharp-cornered.
- **Dynamic Active Badge:** The current theme receives an explicit `[ACTIVE]` badge.
- **Geometry:** The current picker is 600px wide with a 1px accent border and compact 5-10px paddings. `network-menu.rasi` follows the same Iosevka/sharp-corner language at 420px wide, while the bottom `tsoding.rasi` launcher remains full-width and intentionally compact.

### 4. Notification & OSD Styling (Mako)
- **Contrast Fix:** Replaced solid opaque background accents with translucent alpha fills (`progress-color=over {{accent}}45`) to prevent unreadable white text on bright yellow/gold accents.
- **Dynamic Theming:** Volume, Brightness, Screenshot alerts, and Night Light notifications dynamically inherit the active theme accent.

### 5. Sway Tabbed & Border Accents
- Focused borders use the theme's authored semantic border/accent hue, lightness-adjusted only when needed to reach `3.0:1` against the window background.
- Focused-inactive and unfocused borders use a background/accent blend adjusted to at least `1.7:1`, keeping scratchpad and floating-window edges visible without turning every theme into the same grey outline.
- Both the live batched `swaymsg` update and generated `80-theme-colors.conf` use the same derived `border_focus` / `border_muted` values.
  ```text
  client.focused          {{border_focus}} {{bg2}} {{fg}} {{border_focus}} {{border_focus}}
  client.focused_inactive {{border_muted}} {{black}} {{base05}} {{border_muted}} {{border_muted}}
  client.unfocused        {{border_muted}} {{black}} {{grey_fg}} {{border_muted}} {{border_muted}}
  ```

### 6. btop Upstream Cache Bypass & Terminal Canvas Theming
- **The Problem:** 
  1. When switching from dark to light themes, `0.00W` retained a hardcoded black background block, and the CPU graph area showed a temporary dark block before its next collection tick.
  2. In upstream btop ([`src/btop_draw.cpp`](https://github.com/aristocratos/btop/blob/main/src/btop_draw.cpp)), `bat_meter` is declared as a function-local static variable: `static Draw::Meter bat_meter {10, "cpu", true};`. Unlike `cpu_meter` or `mem_meter`, `bat_meter` is never re-instantiated on reload or resize; its internal `cache` array permanently retains the first-rendered ANSI sequence ending in `Fx::reset`.
  3. When `theme_background = true`, `Fx::reset` bakes the dark 24-bit RGB background (`\x1b[48;2;...m`) into the cache. When drawing `0.00W` (which specifies only foreground color via `Theme::c("title")`), the text inherits the cached dark background. On AC power, watts and battery percentages are constant, keeping the stale block visible indefinitely.
- **The Fix:**
  - Configured `theme_background = false` in `~/.config/btop/btop.conf`.
  - Configured `theme[main_bg]=""` in `~/.config/theme/templates/btop.theme`.
  - When `theme_background = false` and `main_bg` is empty, btop outputs `\x1b[49m` (the ANSI sequence for "terminal default background").
  - This delegates background rasterization directly to Alacritty's active theme. `Fx::reset` caches `\x1b[49m` rather than a hardcoded dark RGB background, completely eliminating the dark block behind `0.00W` and preventing graph transition artifacts.
  - Live reloads continue via `SIGUSR2` dispatch in `theme-set`.

### 7. Mathematical WCAG Contrast Enforcement Engine
- **The Problem:** In monochrome or low-contrast imported themes, graph curves and box borders collapsed into visually identical or illegible shades against the background.
- **The Engine:** Implemented WCAG 2.1 relative luminance and contrast ratio calculations inside `~/.local/bin/theme-set`:
  - Enforces a minimum contrast ratio of `4.0:1` against the active background (`bg`) for all graph gradients and box borders.
  - If a color fails the threshold, the engine iteratively adjusts lightness in HSL color space until the target contrast ratio is met.
  - Distinct, dedicated color tokens are computed automatically across every theme (CPU: blue→yellow→red, Download: teal→cyan→blue, Upload: magenta→purple→orange, Memory/Disks: distinct dedicated gradients, Box borders: accent/teal/orange/purple) without manually editing individual theme JSON files.

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

---

## 8. TUI Daily-Driver Expansion Roadmap

Candidate terminal applications for integration into the `theme-set` compiler pipeline, evaluated for daily utility, resource efficiency, and hot-reload mechanism:

| Application | Category | Hot-Reload Mechanism | Integration Feasibility | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **CAVA** | Audio Visualizer | POSIX Signal (`SIGUSR1`) | **Immediate / Native** | `pkill -USR1 cava` instantly reloads `~/.config/cava/config` with active theme gradients without stopping audio capture. Template already exists. |
| **FZF** | Interactive Fuzzy Finder | Shell Env File / Hook | **Instant** | Writes `~/.local/state/theme/fzf.sh` (or `fzf.fish`) setting `$FZF_DEFAULT_OPTS="--color=..."`. Sourced on shell prompt or subshell invocation; no restart required. |
| **BAT & DELTA** | Pager / Git Diff Viewer | Environment variable / Theme file | **Instant on invocation** | Generates dynamic tmTheme or passes `--theme` / sets `BAT_THEME` / `DELTA_FEATURES` dynamically based on dark/light mode. |
| **Lazygit** | Git TUI Client | Atomic config write (`config.yml`) | **On-focus / Launch** | Configures `gui.theme` palette dynamically. Light and responsive. |
| **Zellij** | Terminal Multiplexer | CLI Action IPC | **Instant** | Dispatches `zellij action switch-theme <name>` over runtime IPC socket to switch all panes and tabs live. |
| **Fastfetch** | System Information Fetch | Config generation (`config.jsonc`) | **Instant on invocation** | Injects theme primary accent into logo and key colors. |
| **Spotify-Player / NCspot** | Music Player TUI | Config rewrite + IPC | **Fast** | Generates TOML theme file; can be reloaded via IPC command. |


