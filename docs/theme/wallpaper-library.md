# Central Theme Wallpaper Library

This document owns wallpaper source selection for the system theme engine. Palette compilation remains separate and no resident downloader exists. Runtime wallpaper selection is Omarchy-repository-only: repository-backed Omarchy themes use their own artwork, while non-Omarchy palettes use exact/alias identity first and then an artistic/technical semantic Omarchy donor. The older shared curated library remains maintenance/audit data and is not consumed by runtime switching.

## Goals

- Repository-backed Omarchy themes use only artwork from their own theme scope. Discovery version 3 derives canonical wallpaper roots from recorded candidates, so shared-monorepo built-ins cannot see sibling themes' backgrounds.
- Non-Omarchy palettes may borrow wallpapers only from Omarchy repositories; their colors/theme identity remain unchanged.
- Exact normalized name/display matches are automatic, known naming differences live in `~/.config/theme/wallpaper-aliases.json`, and unmatched palettes use `~/.config/theme/wallpaper-preferences.json` for artistic/technical semantic donor selection.
- Semantic ranking is artistic-first, preserves light/dark polarity, and scores theme accent/background/Base16 colors inside the chosen style pool. Solid palette background is only the final fallback, never a generic or stale image.
- Wallpapers remain suitable for the 1920x1200 panel; shared-library automated selection remains conservative about generative-AI provenance.
- Source/provenance metadata is durable in chezmoi; image binaries are not committed to Git.
- No resident service, watcher, polling loop, or background downloader is introduced.

## Central layout

```text
~/.local/share/theme/wallpapers/
├── manifest.json       # theme mapping + source/provenance metadata; chezmoi-managed
├── assets/             # curated shared WebP assets for explicit matched-library use
└── upstream/           # repository-authoritative per-theme images (Omarchy/GitHub)
```

The former `~/.cache/theme/wallpapers/` tree was migrated into `upstream/` and is no longer
the active storage location. `~/.local/state/theme/wallpaper/<theme>` still stores the
selected filename and `~/.config/current_wallpaper` remains the session-persistence pointer.

## Runtime source precedence

**Explicit opt-out takes precedence:** For a curated color-only theme with `assets.background_mode="solid"`, `theme_engine.wallpaper_policy` returns `kind=none` before any own/alias/identity/semantic image matching. `theme-set` applies the theme's own `BASE00` as a Sway solid background instead of downloading or showing wallpaper imagery. Existing themes without this marker continue to use the precedence rules below; see [`curated-solid-palettes.md`](curated-solid-palettes.md).

1. If the theme is a GitHub-backed Omarchy community import or official Omarchy built-in, `upstream/<theme>/` is authoritative. Runtime cycling additionally filters manifest entries through the theme's canonical wallpaper roots; for a shared monorepo such as `omacom/omarchy`, `omarchy-everforest` therefore sees only `themes/everforest/backgrounds/`, never sibling theme directories. The global curated mapping is ignored even if legacy `manifest.json` entries exist.
2. Import/update treats conventional `backgrounds/`, `wallpapers/`, or `bg/` paths as authoritative and preserves every image in those sets before deleting the temporary clone; Omarchy repository wallpapers have no numeric count cap. Non-UI images elsewhere in the repository are used only when no conventional wallpaper path exists, so lock-screen/README/support artwork is not mixed into a valid background set.
3. Older imports and caches are repaired lazily from that exact GitHub repository by an on-demand detached one-shot worker. A manifest without repository discovery version 3 triggers a blobless Git tree scan, reuses matching local images, and fetches only newly discovered backgrounds; this upgrades retired five-item caches without a fleet-wide blocking refresh. `theme-set` never waits for network I/O, repeated workers for the same palette are deduplicated, and a completed result is applied only if the same theme is still active. There is no resident fetcher or polling daemon.
4. For a non-Omarchy palette, `theme_engine.wallpaper_policy` resolves exact normalized theme/display identity and explicit aliases first. Unmatched palettes are classified by name plus palette characteristics into `artistic_oil`, `light_artistic`, `natural_art`, `terminal_technical`, `technical_blueprint`, or `synth_technical`; the donor pool and ranking bias are declared in `~/.config/theme/wallpaper-preferences.json`.
5. Semantic donor choice filters to repository-backed Omarchy themes with real wallpaper candidates, prefers the same light/dark polarity, then scores accent/background/Base16 color distance plus a small configured aesthetic rank. The donor's `upstream/<donor>/` images are used without replacing the active palette.
6. Shared `assets/` / Wallhaven mappings are ignored by `theme-set` and `theme-wallpaper`. They remain available only to `theme-wallpaper-library` maintenance/audit commands. If no usable Omarchy donor exists, `theme-set` uses the theme background as a Sway `solid_color` and removes the stale `current_wallpaper` pointer.

## Curated source policy

The **shared matched library only** uses Wallhaven's public API because it provides searchable resolution/aspect/color metadata plus per-wallpaper tags and source attribution. This policy does not replace artwork bundled by repository-authoritative Omarchy themes. The maintenance helper uses:

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

The shared-library maintenance manifest still uses Wallhaven's discrete color buckets for conservative source discovery, but bucket membership is not authoritative for assignment and the resulting mapping is ignored by repository-authoritative Omarchy themes. After assets are local, `theme-wallpaper-library sync` profiles the actual image pixels with a small
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

Wallpaper notifications are intentionally terse: normal wallpaper application shows only `Wallpaper changed`; implementation details such as source filename, image format, and Sway fill mode are not exposed in the desktop toast. Automatic first-use hydration is silent while downloading, so it does not add a progress toast; manual fetch operations and actionable failures remain diagnostic.

**No-op on singleton/solid wallpapers (2026-11-07):** The three interactive cycling commands (`theme-wallpaper next`, `prev`, `random`) return successfully and silently when the active theme explicitly declares `assets.background_mode="solid"`, when exactly one valid scoped cached image exists, or when no valid cache exists and the effective repository candidate set contains at most one image. These paths never start Git discovery, downloader, `wset`/Sway reapplication or a notification, and do not update the wallpaper pointer. Even if an incomplete multi-image fetch yields just one cached file, cycling leaves it alone. Explicit `theme-wallpaper fetch`/`refresh` still downloads on request, and themes with two or more images continue cycling normally; the normal `theme-set` hydration lifecycle is separate from this shortcut. This is a local fast-path guard, not a network check.

`theme-wallpaper` is semantic-identity-aware: Omarchy/GitHub themes use only `upstream/<theme>/`; non-Omarchy palettes use only `upstream/<donor>/` from exact/alias/identity or semantic Omarchy resolution. `theme-set` is always network-free on its critical path. If donor bytes are missing, it temporarily uses `solid_color` and launches `theme-wallpaper hydrate <theme>` as a detached one-shot job. That worker downloads outside the global lock and acquires the lock only to verify the theme is still active and apply the finished image. It never substitutes a shared-library image.

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

The shared-library audit above remains valid for its 327 historical mapping entries, but those entries are no longer runtime authority for any theme. Repository-authoritative behavior was separately verified on 2026-11-01: `windows-dark-mode` preserved all 6/6 files from `OldJobobo/omarchy-windows-dark-mode-theme`, ignored its legacy Wallhaven mapping, and applied `upstream/windows-dark-mode/01-01-midnight-ninja-cat.jpg`; an uncached `alberta` theme fetched exactly its four repository backgrounds and exposed no curated asset as local state.

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
- Omarchy/repository wallpapers under `upstream/` are authoritative for those themes; a shared curated asset is never substituted for them.

## Rebuild

After restoring the chezmoi repository on a new installation:

```bash
theme-sync
omarchy-import --catalog
theme-wallpaper-library sync
theme-wallpaper-library audit
```

`omarchy-import --catalog` reconstructs repository-authoritative Omarchy caches while each temporary clone is available. The shared-library commands rebuild/audit the historical curated pool; runtime theme switching does not consume it. Older imported metadata/cache state self-heals lazily on first use through the discovery-versioned repository manifest, so the runtime can expose the full current recorded repository background set without a bulk catalog download.
