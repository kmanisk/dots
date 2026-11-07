# Curated Palette-Only Themes

Added 2026-11-07; verified on the live Sway/Wayland workstation. These are color themes, **not wallpaper packs**. They do not install additional executables, plugins, resident daemons, image assets, or user-facing services.

## Selection and provenance

Compared against the live `~/.cache/theme/picker-index.json` (327 unique themes before this change). These twelve palette variants were not previously available in the picker and remain visible after the engine's existing conservative duplicate filter:

| Theme ID | Appearance | Palette background | Why it adds variety |
| --- | --- | --- | --- |
| `catppuccin-frappe` | dark | `#303446` | Muted slate and lavender pastels |
| `catppuccin-macchiato` | dark | `#24273a` | Richer indigo pastel alternative |
| `ayu-mirage` | dark | `#1f2430` | Warm orange/cool blue on charcoal |
| `github-dark-dimmed` | dark | `#0d1117` | Reserved developer-oriented blue slate |
| `github-light-high-contrast` | light | `#ffffff` | Crisp, high-contrast white |
| `papercolor-light` | light | `#eeeeee` | Retro paper/ink styling |
| `edge-light` | light | `#fafafa` | Minimal light blue/gray |
| `moonlight` | dark | `#212337` | Deep cobalt and bright cyan |
| `rebecca` | dark | `#292a44` | Purple-night with emerald highlight |
| `snazzy` | dark | `#282a36` | Vivid terminal-style color accents |
| `zenbones` | dark | `#191919` | Sparse charcoal and orchid accent |
| `woodland` | dark | `#231e18` | Earthy brown/forest palette |

Upstream palettes are pinned to revision `05e6e6f7e53a2745345ba3658b0172831ff54e9b` of [`tinted-theming/schemes`](https://github.com/tinted-theming/schemes), branch `spec-0.11`. Each managed `dot_config/theme/custom/<theme>.json` stores all 16 authored Base16 colors, the original name/author, the pinned upstream `palette_url`, and a SHA-256 of that upstream YAML. The existing `theme-sync` generator normalizes syntax contrast and synthesizes application UI colors, without executing upstream scripts. No external theme source is required at runtime.

Two candidate names, `rose-pine-moon` and `tokyo-night-moon`, were tested but the engine suppressed them as near-duplicates of the already-installed `rose-pine-dark` and `omarchy-tokyo-night`. Their newly created source files were discarded; `zenbones` and `woodland` were imported instead. No pre-existing themes were deleted.

## Permanent solid-background override

Every new definition contains:

```json
"assets": {
  "background_mode": "solid",
  "wallpaper": null,
  "wallpapers": [],
  "preview": null
}
```

The `theme_engine.wallpaper_policy.resolve_omarchy_wallpaper_source_info()` function returns `kind=none` for an explicit `assets.background_mode == "solid"` **before** alias, repository, identity, or semantic donor matching. Existing themes without this marker retain their own wallpaper behavior. `theme-set` uses its existing `output * bg '<theme background>' solid_color` branch, does not queue wallpaper hydration, and clears a stale current-image pointer for these new themes. Color-swatch preview images generated locally for the picker are not wallpapers.

## Use and verification

- Open `Alt+Shift+M`, search one of the IDs above, and select it. The currently selected theme remains unchanged until you do so.
- Validate a candidate without changing the active theme: `theme-set --check catppuccin-frappe`.
- Rebuild the picker after editing managed palette sources: `theme-sync`.
- To remove one curated theme, remove its matching source file **and** live `~/.config/theme/custom/<id>.json` (or apply it through chezmoi when the full configuration graph is healthy), then run `theme-sync`; this will prune generated cache/previews. Avoid deleting unrelated source files.

Validated on 2026-11-07: all 12 pass `theme-set --check`, foreground/background contrast meets at least 4.5:1, 12/12 sources match their live copies, 12/12 resolve no wallpaper donors, all 12 have picker preview assets, and a no-change `theme-sync` reports manifest up to date. Picker count increased from 327 to 339; the active theme was preserved (`waffle-cat` at final validation). No global theme switch, service or package change was required.
