# System & Architecture Documentation Index

Welcome to the documentation tree for this CachyOS + i3wm/Sway ASUS TUF Gaming F16 setup.

---

## Directory Structure

```
docs/
├── display/             # Display pipeline, hardware CTM vibrance, Wayland architecture
├── gaming/              # Native Proton configurations, game guides, modpacks
│   ├── cs2/
│   ├── elden-ring/
│   └── gta-iv/
├── system/              # Philosophy, reproducibility, baselines, future roadmaps
├── theme/               # Dynamic base46 theming engine & template implementations
└── virtualization/      # Waydroid container root & Windows VFIO GPU passthrough
```

---

## Category Overview

### 1. [Display (`docs/display/`)](file:///home/manisk/docs/display)
- [`intel-hardware-vibrance.md`](file:///home/manisk/docs/display/intel-hardware-vibrance.md) — Hardware-accelerated DRM CTM saturation on Intel Xe-LP (0% shader cost, 0 FPS drop).
- [`wayland.md`](file:///home/manisk/docs/display/wayland.md) — Wayland compositor baseline, env variables, toolkit configuration.

### 2. [Gaming (`docs/gaming/`)](file:///home/manisk/docs/gaming)
- [`README.md`](file:///home/manisk/docs/gaming/README.md) — Hybrid GPU gaming strategy (`prime-run`), Btrfs CoW rules, MangoHud protection.
- **CS2 (`gaming/cs2/`)**: Performance benchmarks, launch options, network tuning.
- **Elden Ring (`gaming/elden-ring/`)**: Proton prefix configuration, Wayland troubleshooting.
- **GTA IV (`gaming/gta-iv/`)**: Complete Edition modpack, FusionFix, DXVK configuration, Gillian's Guide reference.

### 3. [System (`docs/system/`)](file:///home/manisk/docs/system)
- [`system-philosophy.md`](file:///home/manisk/docs/system/system-philosophy.md) — Anti-bloat, performance invariants, headless-first design principles.
- [`SYSTEM-REPRODUCIBILITY.md`](file:///home/manisk/docs/system/SYSTEM-REPRODUCIBILITY.md) — Clean reinstall guide, Snapper snapshots, package list.
- [`reference.md`](file:///home/manisk/docs/system/reference.md) — Fast command reference and hardware specs.
- [`future-plans.md`](file:///home/manisk/docs/system/future-plans.md) — Upcoming system optimizations and features.

### 4. [Theme (`docs/theme/`)](file:///home/manisk/docs/theme)
- [`theme-system.md`](file:///home/manisk/docs/theme/theme-system.md) — Architecture of the dynamic Base46 theme sync engine.
- [`theme-implementation.md`](file:///home/manisk/docs/theme/theme-implementation.md) — Application templates (Alacritty, Sway, Dunst, Rofi, Waybar, etc.).

### 5. [Virtualization (`docs/virtualization/`)](file:///home/manisk/docs/virtualization)
- [`waydroid-guide.md`](file:///home/manisk/docs/virtualization/waydroid-guide.md) — Magisk Delta overlay root, hybrid GPU power handling, recovery.
- [`windows-vfio-setup.md`](file:///home/manisk/docs/virtualization/windows-vfio-setup.md) — KVM/QEMU GPU passthrough setup and IOMMU configuration.
