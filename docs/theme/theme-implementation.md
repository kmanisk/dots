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
3. **Asset Handling:** Extracts a preview for launchers and records all relevant deterministic wallpaper candidates it discovers. Conventional `backgrounds/`, `wallpapers/`, and `bg/` paths are authoritative: every image in those sets is retained with no numeric cap. Non-UI images elsewhere are used only when no conventional wallpaper path exists, preventing lock-screen/README/support artwork from being mixed into a valid wallpaper set. Selected image bytes are transactionally preserved under `~/.local/share/theme/wallpapers/upstream/<theme>/` before the temporary clone is deleted.
4. **Authored App Profiles:** Recognized Omarchy app files are parsed as inert structured color data and preserved under `apps.*` with their `source_file`. Exact profiles drive Alacritty, Kitty, btop, Cava, and Mako. Foot is intentionally an adapter over those author terminal profiles: `alacritty.toml` has first priority, `kitty.conf` fills missing color roles, and the normalized generated palette is the final per-value fallback. The port covers Foot background/foreground, cursor, selection, URL color where available, and ANSI 0-15; fonts, sizing, padding, keybindings and behavior remain locally owned. Ghostty, Chromium frame color, and icon-theme requests are retained for safe adapters/provenance. No commands, Hyprland configuration, arbitrary CSS behavior, or upstream Lua execution is imported. Fresh canonical imports carry `assets.upstream_apps_version = 3`; legacy imports hydrate the same small text profiles lazily through `theme-upstream-apps`.
5. **Neovim Lua Generator:** Writes `~/.config/nvim/lua/themes/<name>.lua` containing dual-cased Base16 keys (`base0A` and `base0a`) to ensure complete compatibility with NvChad's Base46 compiler.
6. **Theme Cache Update:** Writes the compiled JSON directly into `~/.cache/theme/themes/<name>.json`.

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

### Wallpaper source policy (`theme-wallpaper-library` + `theme-wallpaper`)
- Repository discovery version 3 is theme-scope-aware: standalone repositories use their normal background directory, while themes inside shared monorepos are restricted to the canonical wallpaper root declared by that theme. Cached cycling applies the same filter, so even a legacy polluted manifest cannot expose sibling-theme images.
- The persistent root is `~/.local/share/theme/wallpapers/`. `assets/` is the shared matched/curated pool; `upstream/<theme>/` contains exact images shipped by repository-backed themes; `manifest.json` retains shared-library provenance/mappings.
- **Repository-backed Omarchy themes are repository-authoritative.** Community imports (`source.provider=omarchy`) and official GitHub-backed built-ins ignore the shared Wallhaven mapping at runtime and cycle only their own `upstream/<theme>/` images. Import/update now preserves those selected files before deleting the clone.
- First use remains daemonless but is now nonblocking: if the exact resolved Omarchy source lacks its local `upstream/` cache, or if its manifest predates repository discovery version 3, `theme-set` launches one detached `theme-wallpaper hydrate <theme>` worker and continues the local theme transaction. Legacy manifests are repaired with a blobless Git tree scan of the exact repository/ref; matching cached files are reused and only newly discovered backgrounds are downloaded. The worker runs network I/O outside the global theme lock, deduplicates concurrent hydration for the same selected palette, then takes `~/.local/state/theme/.lock` only for a required final wallpaper apply and re-checks active theme identity. A stale download can never overwrite a newer theme.
- Non-Omarchy palettes do not use generic matched assets. `theme_engine.wallpaper_policy` first resolves exact normalized name/display identity and explicit aliases from `~/.config/theme/wallpaper-aliases.json`; unmatched palettes then use `~/.config/theme/wallpaper-preferences.json` to select a semantic Omarchy donor. The configured pools are artistic-first and include artistic oil/illustration, light artistic, natural art, terminal technical, blueprint technical, and synth technical styles. Within a style, donor choice preserves light/dark polarity and scores accent/background/Base16 color distance so the artwork remains compatible with the selected palette. Only wallpaper ownership is borrowed; the active palette/theme remains unchanged.
- If no usable Omarchy source survives exact, alias, identity, and semantic resolution, `theme-set` applies the theme's own background color with Sway `solid_color` and clears the stale wallpaper pointer. The existing shared Wallhaven library and actual-pixel matcher remain explicit maintenance/audit tooling only; `theme-set` and `theme-wallpaper` never consume those mappings at runtime.
- Wallpaper binaries are local data and are not committed to Git. Repository candidate paths and theme source provenance remain in the managed theme JSON; shared-library source metadata remains in `manifest.json`.
- `wset` keeps wallpaper-change notifications intentionally minimal: successful image changes show only `Wallpaper changed`; raw filenames, extensions, and placement modes such as `webp (fill)` are not exposed in the notification UI.
- Sway bindings: `Alt + Shift + M` and `Ctrl + Shift + M` open `rofi-theme`; `Win + Shift + W` and `Win + Ctrl + W` advance; `Win + Ctrl + Shift + W` goes backward.
- Full storage policy, commands, rebuild procedure, and verification are documented in [`wallpaper-library.md`](wallpaper-library.md).

---

## 3. Serialized Atomic Rethemer (`theme-set`)

Located at: [`~/.local/bin/theme-set`](file:///home/onyx/.local/bin/theme-set)

Correct ordering is preferred over detached fire-and-forget reloads. After change-aware promotion and reload gating, a verified same-theme no-op reapply on the live F16 took about **178ms** and changed no theme-state, Neovim-marker, or wallpaper mtimes. The verified dark -> light -> original round trip with two live Neovim instances took roughly **418-528ms per real switch**, while preserving Sway scale 1.30.

### Guarantees:
- **Single-Writer Mutation Lock:** `~/.local/state/theme/.lock` is held with `fcntl.flock()` across relative-theme resolution, staged compilation, atomic promotion, and live dispatch. Rapid or concurrent invocations serialize instead of sharing `.next/` concurrently.
- **Read-Only Preflight:** `theme-set --check <name>` and `theme-set --check-all` normalize palettes and render every template in memory without mutating live state. They reject invalid colors, unresolved template tokens, empty renders, or contrast-floor violations.
- **Author-App-Profile Precedence:** Per-app colors from the selected Omarchy repository override only that application's generated tokens; missing values fall back to the normalized palette. Workstation behavior remains authoritative. In particular, btop always keeps `theme_background=false` / `theme[main_bg]=""` even if upstream specifies a solid `main_bg`, preventing the known cached-background artifact.
- **Nonblocking Legacy Profile Hydration:** old imports without profile schema version 3 queue the one-shot `theme-upstream-apps hydrate <theme>` helper. It uses a blobless Git tree plus selected small blobs, runs outside the mutation lock, caches to `~/.local/share/theme/upstream-apps/`, and reapplies through normal serialized `theme-set` only when the same theme remains active. A measured legacy `all-hallows-eve` first switch completed in about 463 ms while its original app files hydrated afterward.
- **Two-Phase Staged Compilation:** All templates are rendered into the private, lock-protected `~/.local/state/theme/.next/` directory and validated before promotion. Private staging writes intentionally skip fsync because they are not live state; live targets still change only through the transactional promotion/rollback path. If any compile/preflight check fails, zero live files are modified.
- **Transactional Change-Aware Promotion:** Byte-identical targets are left untouched. Changed targets are promoted with `os.replace`, with private rollback copies retained in `.next/` until the whole promotion completes; a mid-promotion failure restores already-changed targets.
- **Scale-Ownership Preservation:** `theme-set` preserves the scale-derived Mako geometry, Swaybar font, and GTK font-size fields owned by `ui-sync`, so applying a theme changes colors without entering a template -> rescale -> template rewrite loop.
- **Change-Gated `/proc` Discovery:** Real theme changes scan `/proc` once for supported live applications; byte-identical same-theme reapplies skip the process walk entirely.
- **Payload-Aware IPC:** Commands that carry explicit theme values (Sway colors/wallpaper and GTK polarity/theme toggles) remain ordered under the mutation lock. Reload-current-config commands for Mako, Dunst, and Yazi are detached one-shots after atomic promotion because they contain no old theme payload; even if they finish later they reload the newest file. Generated-file consumers are dispatched only when their target changed. The expensive Gruvbox folder-icon recolor is likewise detached, but protected by its own file lock plus active-theme/accent checks so rapid switches converge to the newest theme.
- **Reliable Neovim Reload:** Live RPC calls surface Base46 errors, clear cached theme modules, and run to completion. A successful live RPC is also the disk-cache compile. When no Neovim socket exists, `theme-set` performs no invisible headless editor startup and intentionally leaves `~/.local/share/nvim/base46/current_theme` stale; `init.lua` already detects that mismatch and recompiles on the next editor launch. If live sockets exist but RPC cannot produce a valid cache, the bounded headless repair remains the fallback.
- **Cache-First Instant Picker:** `theme-sync` precompiles `~/.cache/theme/picker-index.json`; normal `rofi-theme` startup reads that compact row snapshot instead of reparsing 327 JSON files or scanning source trees for freshness. Existing cache is shown immediately; a missing cache is the only automatic recovery sync, while Ctrl+R is the explicit refresh. Enter emits no replacement rows and returns immediately, so the Rofi overlay disappears before application IPC begins. A detached one-shot `--apply-worker` runs the validated `theme-set` transaction; failures raise a notification and are persisted in `~/.local/state/theme/last-picker-apply.log`. A latest-request token drops stale not-yet-started workers and the mutation lock orders already-running transactions.

Live profiling on 2026-11-03 measured the picker backend at about 25-42 ms typical (30 ms median, 57 ms worst in the sample), same-theme no-op apply at about 58-70 ms after GTK/no-op gating, and a real Blackgold <-> Cobalt2 round trip at about 84 ms per direction after moving the 300+ ms icon-tree recolor off the critical path.

---

## 4. Live Hot-Reload Mechanisms

| Application | Hot-Reload Mechanism | Latency | Details |
| :--- | :--- | :--- | :--- |
| **Sway** | Batched `swaymsg` IPC | ~8ms | Updates `client.focused`, `focused_inactive`, `unfocused`, `urgent` borders and swaybar statusline/workspaces without reloading the window manager. |
| **Alacritty** | File Watcher / Inotify | Instant | `~/.config/alacritty/alacritty.toml` imports `~/.local/state/theme/alacritty.toml`. Authored Omarchy ANSI/cursor/selection colors win when present; font/keybindings remain local. |
| **Kitty** | Config include + signal | Instant | `~/.config/kitty/kitty.conf` includes generated `kitty-colors.conf`; upstream ANSI, cursor/selection, tab, border, URL, and mark colors are preserved without importing font/window/keybinding settings. |
| **Foot** | Authored profile -> Foot config + server-owned PTY OSC broadcast | Instant terminal palette; TUI redraw app-dependent | `theme-set` ports authored Alacritty/Kitty colors into generated `foot-colors.ini`, then discovers the live session PTYs from **immediate child processes of `foot`**, not `footclient` (an IPC process with no PTY child). OSC 10/11/12/17/19 and all 16 OSC 4 entries update each live terminal before Neovim's RPC redraw. A source/live test delivered OSC to 2/2 Foot terminals; a single payload per PTY avoids resets and per-command relaunches. Foot's SIGUSR1/SIGUSR2 only select cached dark/light sections, not reload the generated include; the `footclient` wrapper includes current colors for new windows. Explicit RGB cells inside Codex/OpenCode/other TUIs still require that app to redraw. |
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
- Full-fleet verification on 2026-11-01 covered all 327 exposed themes with zero preflight failures. Runtime `theme-set` now reapplies the contrast floors after merging authored `base_30` aliases, so aliases such as `red`, `green`, `nord_blue`, `dark_purple`, and `baby_pink` cannot overwrite a previously corrected role with a low-contrast value. Body/white/base06 remain at least 4.5:1, chromatic/muted/base04/focused-border roles at least 3.0:1, and inactive borders at least 1.7:1.
- Synthwave '84 is a regression reference: accent `#ff00ff`, Base16 green role `#8f00ff`, purple role `#ff00ff`. Its nominal role labels do not force green/blue hues into the authored purple palette.

### 2. Yazi Light & Dark Hot-Reload Contrast
- **The Problem:** In `~/.config/theme/templates/yazi.toml`, unstyled files previously had `{ mime = "*", fg = "{{white}}" }`. In light mode, this resulted in white-on-white unreadable text on running instances.
- **The Fix:** Changed fallback rules to dynamic `{{fg}}` (`{ mime = "*", fg = "{{fg}}" }`) and inverted bars to `{ fg = "{{bg}}", bg = "{{fg}}" }`.
- **DDS Reload:** `theme-set` broadcasts `ya emit-to 0 app:theme` on every switch so running Yazi sessions adapt immediately without restarting.
- **Manual Keybind:** Bound `<F5>` in `~/.config/yazi/keymap.toml` to `app:theme` for on-demand reload.
- **Square Geometry:** Yazi 26.9.1 separates indicator bar padding from styles. The shared template sets `[indicator].padding` to `▐` and `▌` for hard, rectangular selection ends and zero-width status separators via `[status].sep_left` / `sep_right`. `full-border` uses `ui.Border.PLAIN` in managed `init.lua`; it is applied on the next Yazi launch, independent of theme color updates. The old rounded glyphs `` / `` are no longer generated. On 2026-11-07 the **live** template was found out of sync despite the correct chezmoi source; theme switches thus restored the old glyphs. Synced source to `~/.config/theme/templates/yazi.toml`, explicitly cleared `[tabs].sep_inner` and `sep_outer`, then used `theme-set <current>` to regenerate the active theme without changing the selected palette. Verified `[indicator].padding`, `[tabs]` separators, `[status]` separators, and no rounded glyphs in the regenerated file. When the live template is stale, editing only the generated `~/.local/state/theme/yazi.toml` is not durable.

### 3. Compact Theme Picker UI (Rofi)
- **Typography:** `Iosevka Nerd Font Mono` matches the current system UI/terminal family. The picker uses 12pt body/prompt text and a 10pt hint row so theme names, `[ACTIVE]`, and spectrum swatches stay aligned without oversized chrome.
- **Spectrum Swatches:** Shows the 8 syntax spectrum colors (`base08`–`base0F`) in aligned monospace columns (`● ● ● ● ● ● ● ●`).
- **Selection:** Selected items use the active theme accent while the search/hint rows stay flat and sharp-cornered.
- **Dynamic Active Badge:** The current theme receives an explicit `[ACTIVE]` badge.
- **Friendly Picker Names:** The visible picker label strips only the leading `omarchy-` provider prefix (`omarchy-everforest` displays as `everforest`). The Rofi row value, `info` metadata, index keys, active-theme identity, swatches, and apply/delete/HUD targets retain the canonical name. This is done in `rofi-theme` at display-render time so cache regeneration does not undo it and theme sources are never renamed.
- **Geometry:** The current picker is 600px wide with a 1px accent border and compact 5-10px paddings. `network-menu.rasi` follows the same Iosevka/sharp-corner language at 420px wide, while the bottom `tsoding.rasi` launcher remains full-width and intentionally compact.

### 3a. Compact Fuzzel App Launcher
- The `Alt + Space` application launcher keeps its compact 36-character width, 10-row list, sharp border, and scale-derived row/icon sizing.
- `image-size-ratio=0.58` enables Fuzzel's native large selected-application preview only when filtering down to a few matches, so a single result can show a larger application/logo preview without making the normal full app list bulky.
- Generated web favorites use explicit icon assets; for example, `GitHub Profile: kmanisk` resolves to the managed `github.svg`, so the GitHub logo is available to both the list row and the large preview.

### 3b. Shared Windows VM menu (2026-11-07)

`rofi-windows` retains its existing native Fuzzel/Rofi styling and keyboard navigation. State rows always identify both Windows 10/workspace 5 and Windows 11/workspace 10, explaining shared-VF unavailability. Windows 10 shows paused/source-unavailable recovery states, move/focus, client-only reconnect and requested FPS overlay controls; healthy menus omit hard reset. Nano11 retains its existing lifecycle/recovery actions, with a menu-only client reconnect and Right Ctrl+D FPS/UPS instructions. No theme template, font, color or persistent service changed. Six isolated render states passed; physical acceptance and VM stability are tracked in `docs/virtualization/win10-xlite-experiment.md`.

### 4. Notification & OSD Styling (Mako)
- **Contrast Fix:** Replaced solid opaque background accents with translucent alpha fills (`progress-color=over {{accent}}45`) to prevent unreadable white text on bright yellow/gold accents.
- **Dynamic Theming:** Volume, Brightness, Screenshot alerts, and Night Light notifications dynamically inherit the active theme accent.

### 5. Sway Tabbed & Border Accents
- **Calm tab surfaces across all 339 themes (2026-11-07):** Base16 `BASE01` is sometimes a saturated palette color rather than a usable window-title background. Rebecca's original `#663399` tab with `#9a8ea7` text had only `2.72:1` contrast; Moonlight's `#403c64` tab with `#ef43fa` text had `3.35:1`, using a neon-pink `base_30.white` alias rather than intended `BASE05`. Six active-tab text combinations failed a `4.5:1` audit. Some themes (e.g. Gold Rush) also had overly bright/chromatic tabs despite adequate contrast.
- Sway-only `tab_active_bg` and `tab_inactive_bg` now blend the authored `BASE00` background with neutral white (dark themes: 12%/2.5%) or black (light themes: 8%/1.5%), keeping the original theme undertone but avoiding full-strength purple/gold/cyan surfaces. Selected titles use palette `BASE05` rather than aliased `white`/`BASE07`, and selected, inactive and urgent tab text is adjusted for at least `4.5:1` contrast against its **actual tab background**. Inactive titles use a dimmed `BASE05` rather than imported `grey_fg` aliases that could themselves be saturated gold/pink syntax accents. Application colors and original palette JSON are not changed.
- Focused borders retain the theme's authored accent hue and `3.0:1` contrast against the window background. Inactive borders retain the background/accent blend at `1.7:1`; the accent therefore appears as a narrow focus line rather than a saturated full-width tab. Swaybar focused/active/inactive workspace labels share these same legible text and surface roles.
- Live batched `swaymsg`, managed templates (`sway.conf`, `swaybar.conf`) and generated `80-theme-colors.conf` use matching roles and survive Sway reloads. `theme-set --check-all` and independent per-theme active/inactive/urgent text and surface tests passed **339/339**, including light themes, Rebecca and Moonlight. Applying the already-active theme regenerated the templates; the remote shell lacked `SWAYSOCK` during its first live-IPC attempt, so the matching 11 Sway color commands were applied directly under the existing theme lock with the verified socket. Live `get_bar_config` values then matched source tokens; `sway-check` passed with zero errors/warnings. This is a quantified contrast/consistency check, not a visual inspection of all 339 themes.
  ```text
  client.focused          {{border_focus}} {{tab_active_bg}} {{tab_active_fg}} {{border_focus}} {{border_focus}}
  client.focused_inactive {{border_muted}} {{tab_inactive_bg}} {{tab_inactive_fg}} {{border_muted}} {{border_muted}}
  client.unfocused        {{border_muted}} {{tab_inactive_bg}} {{tab_inactive_fg}} {{border_muted}} {{border_muted}}
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

### Thunar Compact Presentation, Sidebar Theming, and Xfconf Baseline

To match standard GTK file chooser ergonomics and avoid bloated visual metrics:

1. **Sidebar Color Invariant:** In `dot_config/theme/templates/gtk.css`, sidebar items inherit `color: {{white}}` (theme foreground) rather than `color: {{accent}}`. Only the selected shortcut (`treeview:selected`) and active hover states receive background pill highlighting (`{{one_bg2}}` / `{{one_bg}}`).
2. **Compact Details View:** `~/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml` enforces `last-details-view-zoom-level = THUNAR_ZOOM_LEVEL_25_PERCENT` (16px symbolic icons) and visible columns `THUNAR_COLUMN_NAME,THUNAR_COLUMN_SIZE,THUNAR_COLUMN_TYPE,THUNAR_COLUMN_DATE_MODIFIED`.
3. **Breadcrumb Pathbar:** `last-location-bar = ThunarLocationButtons` renders breadcrumb path buttons with subtle borders and theme-accented active path nodes. Both `.location-bar button:checked` and `:active` (along with nested `label` nodes) explicitly enforce `color: {{white}}` against `background-color: {{one_bg2}}` to prevent invisible text collisions in themes where `one_bg2` equals `accent` (such as `windows-dark-mode`).
4. **Clean Navigation Bar:** Toolbar items suppress new-tab, new-window, and split-view icons (`new-tab:0, new-window:0, toggle-split-view:0`), presenting only necessary navigation and search controls.
5. **Session Tab Hygiene:** `last-restore-tabs = false` prevents accumulated tabs from previous sessions from reopening upon launch.
6. **Dynamic Multi-Scale Folder Recolor Hook:** `dot_config/theme/hooks.d/executable_20-thunar-folder-color.py` iterates across all icon sizes in `~/.local/share/icons/Gruvbox-Plus-Dark/places/` (`16`, `22`, `24`, `32`, `48`, `scalable`), mapping `class="ColorScheme-Text"` paths on folders to `class="ColorScheme-Highlight"` and dynamically updating the highlight color to `target_accent`. This eliminates hardcoded Gruvbox cream/yellow icons (`#ebdbb2`) across compact list views.


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

---

## 9. Future Plans: Dynamic Browser UI Retheming (Brave / Chromium)

### 9.1 Feasibility & Trade-Off Analysis ("Is It Worth It?")

Harmonizing browser window chrome (tab strip, toolbar, URL bar, bookmark bar) with active system themes (Nord, Gruvbox, Dracula, etc.) is a common rice goal. However, an objective engineering assessment reveals specific trade-offs:

1. **Surface Area Disparity:** In daily usage, web content accounts for >90% of screen area. Web pages render their own independent styles (e.g., GitHub dark, YouTube, docs), leaving only the top 70-80px window chrome responsive to theme colors. Without page-level retheming (such as Dark Reader or `omarchy-web-retheme`), high-contrast discrepancies can occur between browser chrome and page content.
2. **Reload Friction vs Zero-Daemon Invariant:** Modern Chromium processes do not monitor arbitrary user configuration files on disk. Live color updates require either browser restart, policy reload, or extension reload.
3. **Verdict:** Full unpacked extension generation (Matugen model) introduces significant reload friction for minimal visual payoff. Conversely, the **Enterprise Managed Policy model (Omarchy approach)** and the **GTK+ surface bridge** provide clean, zero-friction candidates suitable for an on-demand hook if browser accent matching is desired.

### 9.2 Architecture Approaches Evaluated

| Feature | Option A: Enterprise Managed Policy (`BrowserThemeColor`) | Option B: Matugen Unpacked Extension | Option C: GTK+ Theme Bridge |
| :--- | :--- | :--- | :--- |
| **Origin / Precedent** | Omarchy system architecture | Hyprland / Matugen rices | Native Chromium Linux integration |
| **Target Path** | `/etc/brave/policies/managed/theme.json` | `~/.local/share/browser-theme/manifest.json` | `~/.config/gtk-3.0/gtk.css` |
| **Color Generation** | Internal GM3 Material You engine calculates tints from seed hex | Exact RGB arrays defined in Matugen manifest template | Window controls and accent borders derived from GTK |
| **Hot-Reload Trigger** | Automatic on launch; `brave://policy` reload button live | Requires manual extension reload in `brave://extensions` | Window recreate or relaunch |
| **Privilege Scope** | Requires directory permission in `/etc/brave/policies/managed` | Pure user space (`$HOME`) | Pure user space (`$HOME`) |
| **UI Artifacts** | Displays "Managed by your organization" in settings | Requires persistent Developer Mode toggle | Clean native appearance |

### 9.3 Technical Specifications for Future Implementation

#### Approach A: Managed Policy Hook (Recommended for Automation)

Chromium supports setting a centralized theme color via the `BrowserThemeColor` enterprise policy. The policy accepts any valid hex string (e.g. `"#81a1c1"`).

1. **One-Time Provisioning:**
   ```bash
   sudo mkdir -p /etc/brave/policies/managed
   sudo chown -R $USER:$USER /etc/brave/policies/managed
   ```
2. **Theme Hook Integration:**
   An executable hook `dot_config/theme/hooks.d/executable_60-browser-theme.sh` consumes `$THEME_ACCENT` (or `palette.accent` from `~/.local/state/theme/colors.sh`):
   ```bash
   #!/usr/bin/env bash
   POLICY_DIR="/etc/brave/policies/managed"
   if [ -d "$POLICY_DIR" ] && [ -w "$POLICY_DIR" ] && [ -n "${THEME_ACCENT:-}" ]; then
       cat > "$POLICY_DIR/theme.json" <<EOF
   {
     "BrowserThemeColor": "${THEME_ACCENT}"
   }
   EOF
   fi
   ```
3. **Execution Contract:** Runs synchronously as part of `theme-set` execution, maintaining zero background daemons.

#### Approach B: Unpacked Extension Template (Recommended for Standalone User Space)

If system directory modifications are disallowed, Matugen can output an unpacked theme extension:

1. **Manifest Template:** `~/.config/matugen/templates/browser-theme/manifest.json`
   ```json
   {
     "manifest_version": 3,
     "name": "Dynamic System Theme",
     "version": "1.0",
     "theme": {
       "colors": {
         "frame": [{{colors.surface.default.rgb | replace: "rgb(", "" | replace: ")", ""}}],
         "toolbar": [{{colors.surface_container.default.rgb | replace: "rgb(", "" | replace: ")", ""}}],
         "tab_text": [{{colors.on_surface.default.rgb | replace: "rgb(", "" | replace: ")", ""}}],
         "tab_background_text": [{{colors.on_surface_variant.default.rgb | replace: "rgb(", "" | replace: ")", ""}}],
         "button": [{{colors.primary.default.rgb | replace: "rgb(", "" | replace: ")", ""}}]
       }
     }
   }
   ```
2. **Usage Flow:** The folder `~/.local/share/browser-theme` is loaded once via `brave://extensions` under Developer Mode.
