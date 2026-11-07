# ArtCraft Suite Architecture & Wayland Integration

Standards, environment integration, display scaling, and Wayland window management for the ArtCraft application suite (GridCraft, WordCraft, PhotoCraft, FilmCraft, FigCraft, PdfCraft) on Sway (Wayland) with CachyOS.

---

## 1. Application Architecture & Window Backends

The ArtCraft application suite consists of native creative and office productivity tools built primarily in Rust with `egui` and `winit`:

| Application | Identifier / Binary | Default Backend | Wayland Flag | Primary Config |
| :--- | :--- | :--- | :--- | :--- |
| **GridCraft** | `ai.storyteller.gridcraft` / `gridcraft` | X11 (without env flag) | `GRIDCRAFT_WAYLAND=1` | `~/.config/gridcraft/ui.json` |
| **WordCraft** | `ai.storyteller.wordcraft` / `wordcraft` | X11 (without env flag) | `WORDCRAFT_WAYLAND=1` | `~/.config/wordcraft/ui.json` |
| **FilmCraft** | `ai.storyteller.filmcraft` / `filmcraft` | X11 (without env flag) | `FILMCRAFT_WAYLAND=1` | `~/.config/filmcraft/preferences.json` |
| **PhotoCraft** | `ai.storyteller.photocraft` / `photocraft` | Xwayland (tablet fallback) | `PHOTOCRAFT_NATIVE_WAYLAND=1` | `~/.config/photocraft/preferences.json` |
| **PdfCraft** | `ai.storyteller.pdfcraft` / `pdfcraft` | Native Wayland | Built-in | `~/.config/pdfcraft/app.ron` |
| **FigCraft** | `figcraft` / `figcraft` | Native Wayland | Built-in | `~/.config/FigCraft/state.json` |

When launched under a Wayland compositor without explicit Wayland enablement variables, GridCraft, WordCraft, and FilmCraft detect the active `DISPLAY=:0` variable and initialize their X11 backend through Xwayland.

---

## 2. Scaling Diagnostics & Root Cause Analysis

### Symptoms
In GridCraft on high-DPI or fractionally scaled displays (such as 1920x1200 at 1.30x scale on the ASUS TUF Gaming F16):
- Window rendered with massive, bloated UI chrome: the ribbon and formula bar consumed over 530 vertical pixels (almost half the display).
- Only 13 rows were visible on an entire 1200p screen, and columns truncated at column O.
- Text, icon edges, and grid cell borders were visibly blurry and low-resolution.

### Root Cause
The issue was caused by a compounding multiplication of three distinct scaling factors:
1. **Xwayland Compositor Upscaling:** Sway runs at fractional output scale `1.30` (`output eDP-1 scale 1.30`). Xwayland surfaces cannot negotiate native fractional scaling directly without compositor bilinear upscaling, introducing text blur.
2. **Xft DPI Pre-scaling:** Under X11, `winit` queries `Xft.dpi: 120` (`120 / 96 = 1.25x`), pre-scaling egui layout coordinates before presentation.
3. **Internal `interfaceScale` Over-multiplication:** `~/.config/gridcraft/ui.json` had `"interfaceScale": 150` (150% UI zoom).

The compound scale factor was:
$$\text{Scale} = 1.25 \times 1.50 \times 1.30 \approx 2.44\times$$

This caused the 2.44x oversized interface and severe blur seen in user screenshots.

---

## 3. Resolution & Persistent Configuration

### A. Session Environment Integration
Native Wayland flags are exported so that all launcher methods (ArtCraft Launcher AppImage, Fuzzel/Rofi application menus, or terminal CLI) launch the applications as native Wayland `xdg_shell` toplevels:

1. **`~/.config/environment.d/40-craft-apps.conf` (systemd user session):**
   ```ini
   GRIDCRAFT_WAYLAND=1
   WORDCRAFT_WAYLAND=1
   FILMCRAFT_WAYLAND=1
   PHOTOCRAFT_NATIVE_WAYLAND=1
   ```

2. **`~/.local/bin/sway-run` (Sway session startup wrapper):**
   ```bash
   export GRIDCRAFT_WAYLAND=1
   export WORDCRAFT_WAYLAND=1
   export FILMCRAFT_WAYLAND=1
   export PHOTOCRAFT_NATIVE_WAYLAND=1
   ```

### B. Executable Wrapper (`~/.local/bin/gridcraft`)
A wrapper at `~/.local/bin/gridcraft` (managed in chezmoi) guarantees that direct shell executions or PATH lookups unconditionally export `GRIDCRAFT_WAYLAND=1` when `WAYLAND_DISPLAY` is active:
```bash
#!/usr/bin/env bash
if [ -n "$WAYLAND_DISPLAY" ]; then
    export GRIDCRAFT_WAYLAND=1
fi
exec /usr/bin/gridcraft "$@"
```

### C. Application UI Scale (`ui.json`)
`~/.config/gridcraft/ui.json` sets `"interfaceScale": 110` (110% / 1.1x scaling):
- GridCraft's internal egui scaling directly honors Wayland compositor scale with a slight 1.1x zoom for comfortable readability.
- Visible grid area fits 34 rows comfortably (compared to 13 rows at 150%).
- Rendering remains pixel-perfect and sharp with zero interpolation artifacts.

### D. Suite Scaling Utility (`craft-scale`)
The helper `craft-scale` (`~/.local/bin/craft-scale`) manages scaling across the ArtCraft suite:
```bash
craft-scale                     # View current scaling across all Craft applications
craft-scale 100                 # Set 100% (standard) across all Craft applications
craft-scale gridcraft 100       # Target GridCraft specifically
craft-scale gridcraft auto      # Reset GridCraft to auto (100%)
```

---

## 4. Verification Baseline

Verification performed live on 2026-11-05:
1. `swaymsg -t get_tree` confirms `ai.storyteller.gridcraft` maps as `shell: "xdg_shell"` with `window: null` (native Wayland).
2. OCR and pixel measurement on `1920x1200` output scale `1.30`:
   - Ribbon height reduced from 557px to 310px (including Sway title chrome).
   - Visible spreadsheet rows increased from 13 to 39.
   - Text rendering matches crisp native panel resolution.
