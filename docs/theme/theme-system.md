# Omarchy-Style Theme System for Vanilla Sway — Design Doc

> Goal: one-command, whole-desktop theme switching (`theme-switch <name>`)
> on vanilla Sway. No daemon, no desktop shell, no wallpaper-driven colors.

## Architecture (ported from Omarchy)

Omarchy (Hyprland-based) implements theming as orchestration, not magic:

```text
theme name
    ↓
canonical colors.toml
    ↓
generate application configs
    ↓
apply compositor colors
    ↓
change wallpaper
    ↓
run application-specific retheming hooks
```

Reference: `omarchy-theme-set` stages a theme into a temp dir, generates
configs, atomically swaps into the current theme, then runs per-app
post-theme commands. `omarchy-theme-set-templates` expands theme colors
into config files.

Key insight: **this is not Hyprland-specific.** The Sway equivalent of
Omarchy's compositor reload is simply `swaymsg reload`.

## Sway port sketch

```text
              theme-switch gruvbox-dark
                        │
                        ▼
               ~/.config/themes/
                        │
           ┌────────────┴────────────┐
           │                         │
        palette                  wallpaper
           │
  ┌────────┼─────────┬────────┐
  ▼        ▼         ▼        ▼
Sway     GTK3      GTK4     Qt5/Qt6
  │        │         │         │
  └────────┴─────────┴─────────┘
               │
        application hooks
               │
    ┌──────────┼───────────┐
    ▼          ▼           ▼
 Fuzzel      btop       Alacritty
    │
    ▼
 Neovim / Brave / etc.
```

## Fixed palettes, not Matugen

Unlike Matugen (`wallpaper → colors → apps`), this system uses:

```text
theme directory → fixed palette → applications
```

```text
~/.config/themes/
├── gruvbox-dark/
│   ├── colors.toml
│   └── wallpaper.jpg
├── gruvbox-light/
│   ├── colors.toml
│   └── wallpaper.jpg
└── tokyo-night/
    ├── colors.toml
    └── wallpaper.jpg
```

`theme-switch <name>` generates/applies: Sway colors, GTK3, GTK4, Qt5,
Qt6, Fuzzel, btop, Alacritty, Neovim, Brave, etc. The switcher is a small
shell script — single entry point, no daemon.

## Coverage reality

Reproducible via config generation:

```text
GTK3/GTK4 → yes
Qt5/Qt6   → yes (already demonstrated: gruvbox-dark.conf for qt5ct+qt6ct)
Sway      → yes (colors block + swaymsg reload)
Fuzzel    → yes
btop      → yes
terminal  → yes
Neovim    → yes
```

Some apps need a restart or a dedicated hook — same as Omarchy, which
handles those with explicit post-theme commands.

## Status on this machine

- Fixed-Gruvbox-everywhere already implemented manually (GTK2/3/4,
  qt5ct/qt6ct palettes, Noto Sans, Brave scale, Alacritty, mako-adjacent).
- Qt configs historically pointed at generated `matugen.conf` paths —
  evidence the config layout already anticipates generated palettes.
- Not yet built: the `theme-switch` script, `~/.config/themes/` palettes,
  per-app templates/hooks. This doc is the spec for that future work.
