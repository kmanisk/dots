# Central Theme Wallpaper Library

This document owns the curated wallpaper layer used by the system theme engine.
It is intentionally separate from palette compilation: `theme-set` stays network-free,
while wallpaper discovery and downloading are explicit maintenance operations.

## Goals

- Every exposed system theme has local wallpaper choices.
- Wallpapers are high resolution and suitable for the 1920x1200 panel.
- Automated selection is conservative about generative-AI provenance.
- Images are stored once and shared across themes instead of duplicated per theme.
- Source/provenance metadata is durable in chezmoi; image binaries are not committed to Git.
- No resident service, watcher, polling loop, or background downloader is introduced.

## Central layout

```text
~/.local/share/theme/wallpapers/
├── manifest.json       # theme mapping + source/provenance metadata; chezmoi-managed
├── assets/             # curated shared WebP assets
└── upstream/           # preserved Omarchy/repository wallpapers used as fallback
```

The former `~/.cache/theme/wallpapers/` tree was migrated into `upstream/` and is no longer
the active storage location. `~/.local/state/theme/wallpaper/<theme>` still stores the
selected filename and `~/.config/current_wallpaper` remains the session-persistence pointer.

## Curated source policy

Automated curation currently uses Wallhaven's public API because it provides searchable
resolution/aspect/color metadata plus per-wallpaper tags and source attribution.
The maintenance helper uses:

- category: General only;
- purity: SFW only;
- minimum source resolution: 1920x1200;
- aspect ratios: 16:9 or 16:10;
- ordering: favorites first;
- source discovery: nearest Wallhaven discrete color buckets are used only to build a conservative candidate pool;
- search exclusion: `AI art`;
- full metadata rejection for known AI-generation tags and known AI-generation source domains;
- conservative upload cutoff: only Wallhaven uploads dated before 2022-01-01 are eligible for automated selection.

The cutoff is deliberately conservative. Metadata and dates cannot mathematically prove human
authorship, but the combination avoids the modern generative-AI period and independently rejects
explicit AI metadata. Newer wallpapers can be added manually only after human review; automated
sync never selects them.

## Palette matching and deduplication

The 327-theme fleet still uses Wallhaven's discrete color buckets for conservative source
discovery, but bucket membership is no longer authoritative for theme assignment. After assets
are local, `theme-wallpaper-library sync` profiles the actual image pixels with a small
ImageMagick histogram and records dominant/chromatic colors, mean luminance, and mean saturation.
Each theme is then scored globally against all vetted assets using:

1. the theme accent against actual image colors;
2. several authored Base16 syntax/accent hues against the actual image colors;
3. theme-background versus image mean luminance;
4. theme-accent versus image mean saturation; and
5. only a small source-bucket prior.

The first wallpaper is always the absolute best visual score. The second and third choices stay
inside the strongest visual shortlist but receive a modest global reuse penalty so broadly
compatible images do not dominate hundreds of themes. Assets remain keyed by Wallhaven ID and
stored once globally. On the verified 2026-11-01 mapping all 63 curated assets are used; 48 appear
as at least one theme's first choice, and the maximum all-slot reuse is 35 assignments.

## Local image normalization

Source images are downloaded only by the explicit library maintenance helper and normalized with
ImageMagick to:

```text
format: WebP
quality: 92
maximum dimensions: 2560x1600
upscaling: disabled
```

The source search already requires at least 1920x1200. This retains enough detail for the native
1920x1200 panel while avoiding the disk cost of retaining 4K/8K originals. `imagemagick` is declared
in `packages/sway.txt`, so the `magick` conversion dependency is restored by normal package reconciliation.

## Commands

```bash
# Read-only fleet/color-bucket plan
theme-wallpaper-library plan

# Build/update source selection, local assets, and theme mappings
theme-wallpaper-library sync

# Force source re-selection for every used color bucket
theme-wallpaper-library sync --refresh

# Check coverage and local disk use
theme-wallpaper-library status

# Verify mappings, actual-pixel profiles, asset files, upload cutoff, and AI metadata policy
theme-wallpaper-library audit

# Hydrate mapped files already recorded in the manifest
theme-wallpaper-library fetch <theme>
theme-wallpaper-library fetch --all
```

Normal desktop use remains:

```bash
theme-wallpaper next
theme-wallpaper prev
theme-wallpaper random
theme-wallpaper set 1 <theme>
theme-wallpaper list <theme>
```

`theme-wallpaper` prefers the curated library. If a theme has no curated mapping, its repository
wallpapers under `upstream/` remain a compatibility fallback. `theme-set` only reads already-local
files and never invokes the network.

## Verified state, 2026-11-01

Live verification after the initial strict build:

```text
exposed themes:               327
mapped themes:                327
choices per theme:              3
used color buckets:            24
unique curated assets:         63
assets used by mappings:        63
unique first-choice assets:     48
maximum all-slot reuse:         35
curated asset size:          29.6 MiB
oldest selected upload:      2014-02-07
newest selected upload:      2021-10-11
minimum local width:         1920 px
minimum local height:        1200 px
maximum local dimensions:    2560x1600
audit:                       PASS
```

All 63 selected assets are pre-2022 and passed the stored explicit-AI tag/source check. The fleet
contains uploads from 2014 through 2021 only.

Live Sway cycling was verified on `waffle-cat`: `next` switched to curated slot 2/3 and `set 1`
returned to slot 1/3 with successful Sway IPC. `~/.config/current_wallpaper` points into
`~/.local/share/theme/wallpapers/assets/`, and the obsolete cache path was not recreated.

## Source of truth and Git policy

`manifest.json` is managed by chezmoi and records provider page, download URL, original source URL,
uploader, upload date, resolution, source palette metadata, actual-pixel visual profiles, tags,
source bucket, per-theme match scores, and the final theme mappings.

The image binaries under `assets/` and `upstream/` are local data and are not placed in Git. This
keeps the dotfiles repository small while preserving enough metadata to rebuild the library.

## Failure behavior

- Selection is completed before a replacement manifest becomes authoritative.
- Downloads use temporary files and only replace completed local assets.
- A failed hydration aborts the sync rather than publishing a partially available mapping.
- Obsolete curated assets are pruned only after all replacement assets have hydrated and the new
  manifest has been written.
- The currently displayed wallpaper is preserved during pruning even if a catalog refresh no
  longer references it, preventing a broken `current_wallpaper` path mid-session.
- Existing Omarchy/repository wallpapers remain under `upstream/` as a local fallback.

## Rebuild

After restoring the chezmoi repository on a new installation:

```bash
theme-sync
theme-wallpaper-library sync
theme-wallpaper-library audit
```

The first command reconstructs the theme fleet; the second reconstructs the central wallpaper
assets from the managed provenance manifest/source policy; the third verifies complete coverage.
