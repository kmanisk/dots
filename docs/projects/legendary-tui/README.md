# legendary-tui: Epic Games Store TUI for Linux

**Fast, keyboard-driven Ratatui terminal frontend for the Legendary Epic Games Store CLI.**

- **Project Path:** `/home/onyx/.local/src/egs`
- **Installed Binary:** `~/.local/bin/legendary-tui`
- **Package:** `legendary-tui` (AUR)

---

## 1. Overview

`legendary-tui` provides a terminal native interface for Epic Games Store management on Linux gaming laptops and handhelds. It wraps the `legendary` CLI engine, replacing bloated Electron launchers (such as Heroic or the official Epic launcher under Wine) with an asynchronous Rust application consuming under 15 MB of RAM.

---

## 2. Feature Matrix

### Library Operations
- **Fuzzy Search & Fast Filter:** Instant library filtering across *All*, *Installed*, and *Available* titles.
- **Terminal Poster Art:** Inline box art rendering using `ratatui-image` with automatic DEC Sixel and Kitty protocol negotiation.
- **Game Launch Integration:** Direct launch via Proton SLR or native wine runners, passing game-specific environment variables (e.g. Gamescope, MangoHud, DXVK).

### Download & Maintenance Pipeline
- **Background Downloads:** Non-blocking multi-game download queue displaying downloaded bytes, percentage, active transfer rate, and dynamic ETA.
- **Safe Cancellation Dialog:** Immediate task cancellation without manifest corruption.
- **File Verification:** Manifest checksum validation (`legendary verify`) reporting corrupted chunks and missing files.
- **Import Existing Installations:** Interactive directory import (`fzf` assisted) for games already stored on disk.
- **Cache Pruning:** Clean chunk cache directories and stale manifests via safe cleanup routine (`legendary cleanup`).

### Cloud Save Synchronization
- **Manifest Listing:** Inspect remote cloud save timestamps and versions (`[l]`).
- **Two-Way Synchronization:** Bidirectional sync (`legendary sync-saves`) resolving conflict resolution safely (`[s]`).
- **Targeted Download:** Force download latest remote saves (`[d]`).

---

## 3. Keyboard Navigation

| Keybinding | Action |
| :--- | :--- |
| `j` / `k` | Move cursor down / up |
| `g` / `G` | Jump to top / bottom |
| `/` | Open fuzzy search filter |
| `Tab` | Cycle view (*All* -> *Installed* -> *Available*) |
| `Enter` | Launch selected game |
| `i` | Install selected game |
| `u` | Uninstall selected game |
| `v` | Verify installation integrity |
| `s` | Synchronize cloud saves |
| `d` | View active downloads queue |
| `c` | Run cache cleanup |
| `q` | Quit application |

---

## 4. Key References

- [Gaming Documentation Hub](file:///home/onyx/docs/gaming/README.md)
- [Proton Prefix Management](file:///home/onyx/docs/gaming/proton-prefix-dependency-management.md)
- [Source Code](file:///home/onyx/.local/src/egs)
