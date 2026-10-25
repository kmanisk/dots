# steam-add-game — FUTURE PLAN (not implemented)

One-command CLI to add non-Steam Windows games to Steam with Proton + LSFG 2.0
preconfigured. No daemon; one-shot script around SteamTinkerLaunch.

## Why SteamTinkerLaunch, not hand-editing shortcuts.vdf

Non-Steam shortcuts live in binary `shortcuts.vdf`; Steam must be closed
while it's modified. SteamTinkerLaunch already exposes a CLI for adding
entries with compatibility tool + launch options:

```bash
steamtinkerlaunch addnonsteamgame \
  --appname="SomeGame" \
  --exepath="/mnt/Games/SomeGame/Game.exe" \
  --startdir="/mnt/Games/SomeGame" \
  --compatibilitytool="GE-Proton" \
  --launchoptions='gamemoderun ~/lsfg %command%'
```

Client needs a restart after adding shortcuts.

## Target UX

```bash
steam-add-game /mnt/Games/SomeGame/Game.exe [--profile gta]
```

Script responsibilities: verify Steam closed → locate exe → derive name +
startdir → detect installed Proton (prefer GE-Proton) → add shortcut → set
launch options (`gamemoderun`, `~/lsfg` wrapper) → backup `shortcuts.vdf` →
tell user to restart Steam.

## Profiles

| Profile | Proton | Extra |
|---------|--------|-------|
| `default` | GE-Proton | `gamemoderun`, `~/lsfg` |
| `gta` | GE-Proton | + GTA IV-specific env |
| `no-lsfg` | GE-Proton | `gamemoderun` only |

## LSFG variables (for reference, if not using the wrapper)

```bash
ENABLE_LSFG=1 LSFG_MULTIPLIER=2 LSFG_FLOW_SCALE=0.8 LSFG_PERF_MODE=1
```

Prefer the existing `~/lsfg %command%` wrapper over per-game variables.

## Open questions before implementing

- Installed? `command -v steamtinkerlaunch` — not yet verified on this machine.
- Which GE-Proton versions are installed (compat tool name must match exactly)?
- Artwork/icons: SteamGridDB API vs manual (needs API key — do NOT commit it).
- Non-Steam AppID ↔ compat-tool mapping in `config.vdf` — verify after first add.
