---
name: intel-drm-ctm-vibrance
description: Hardware-accelerated display vibrance and saturation via Intel CRTC CTM on Linux Wayland/X11 without shader or FPS overhead
---

## Authority and freshness

This skill is procedural guidance, not a current machine-state authority. Before using any machine-specific path, device name, GPU mode, desktop/session, filesystem, version, or service-state claim below, read `~/.local/share/chezmoi/AGENTS.md`, `~/.local/share/chezmoi/docs/system/SYSTEM_CONTEXT.md`, `~/.local/share/chezmoi/docs/system/SUBSYSTEM_MAP.md`, the owning subsystem documentation, and current repo source; verify live state when available. Higher-authority evidence overrides this skill. Treat dated verification blocks as historical evidence unless re-verified.

# Intel Hardware DRM CTM Vibrance Architecture (CachyOS / Wayland / X11)

## Overview
Achieves native hardware color saturation / vibrance (equivalent to NVIDIA Digital Vibrance) on hybrid GPU laptops where the Intel iGPU drives the internal display panel (`eDP-1`), with **0% shader cost**, **0 latency**, and **0 FPS drop**.

## Hardware Pipeline Invariants
- Intel Gen12+ (Xe-LP / Raptor Lake display engine):
  `DEGAMMA_LUT (33)` $\to$ `CTM (3x3 S31.32)` $\to$ `GAMMA_LUT (262145)` $\to$ Panel
- `CTM` operates at the CRTC hardware level (`CRTC 151` on ASUS TUF F16).
- `wl-gammarelay-rs` (night light / brightness) drives `GAMMA_LUT` independently; it does not overwrite or conflict with `CTM`.
- dGPU offloading (`prime-run %command%`) renders on RTX 5050 and scans out through the Intel CRTC, inheriting the hardware vibrance automatically.

## Key Kernel & libdrm Requirements
1. **DRM Atomic Client Capability**:
   Calling `drmModeAtomicCommit` requires user space to explicitly declare:
   ```c
   drmSetClientCap(fd, DRM_CLIENT_CAP_UNIVERSAL_PLANES, 1);
   drmSetClientCap(fd, DRM_CLIENT_CAP_ATOMIC, 1);
   ```
   Without `DRM_CLIENT_CAP_ATOMIC`, `drm_mode_atomic_ioctl()` immediately aborts with `-EINVAL` before reaching driver code (`intel_color_check`), keeping `dmesg` silent.
2. **Matrix Format**:
   DRM CTM uses **S31.32 sign-magnitude** format:
   - Bit 63 is the sign bit (`1ULL << 63`).
   - Bits 0-62 represent the magnitude scaled by $2^{32}$ (4294967296.0).
   - Rec.709 Luminance preserving coefficients: $(0.2126, 0.7152, 0.0722)$.

## DRM Master Latch Architecture
- Linux DRM strictly enforces single-master exclusivity. While Sway is running on TTY1, it owns DRM Master.
- Wlroots only queries and commits `GAMMA_LUT`; it does not touch or reset `CTM`.
- Therefore, setting CTM before Sway takes DRM Master (`launch-desktop` $\to$ `sway-run`) causes the hardware to latch the matrix into CRTC registers, which Sway and all workspaces inherit permanently.

## Tooling
- `ctm-test` (`~/.local/bin/ctm-test`): C + libdrm binary.
  - `--inspect`: Read-only dump of CRTC CTM matrix and LUT properties (safe under live Sway).
  - `--set <s>`: Commits saturation matrix permanently and exits immediately.
  - `--identity`: Resets CTM blob to NULL (identity passthrough).
- `vibrance-ctl` (`~/.local/bin/vibrance-ctl`): Unified management CLI.
  - `vibrance-ctl get`: View current config and live DRM matrix.
  - `vibrance-ctl set <val>`: Update `~/.config/vibrance`.
  - `vibrance-ctl set <val> -r`: Update and instantly reload Sway session preserving all windows.
  - `vibrance-ctl off`: Reset back to 1.0 stock.

## Linux (`vibrance-ctl`) vs. Windows (NVIDIA Control Panel) Comparison

On Windows, the NVIDIA Control Panel Digital Vibrance slider runs from **0% to 100%**, with **50%** representing neutral/unaltered sRGB saturation. On Linux, `vibrance-ctl` uses a scalar multiplier where **1.0** represents neutral.

### Mathematical Conversion Formulas

$$\text{Linux Scalar} = 1.0 + \frac{\text{NVIDIA \%} - 50}{50}$$

$$\text{NVIDIA \%} = 50 + \left[(\text{Linux Scalar} - 1.0) \times 50\right]$$

### 1-to-1 Scale & Calibration Chart

| NVIDIA Control Panel (Windows) | Linux Scalar (`vibrance-ctl set <val>`) | Visual Profile & Use-Case |
| :--- | :--- | :--- |
| **0%** | `0.00` | Full Grayscale / Monochrome |
| **50%** (Stock Neutral) | `1.00` | Factory Default sRGB (Untouched) |
| **55%** | `1.10` | Subtle Warmth |
| **60%** | `1.20` | Gentle Pop (Desktop / Web / Reading) |
| **65%** | `1.30` | Natural Vividness |
| **70%** | `1.40` | Standard Gaming Saturation |
| **75%** (**Current Sweet Spot**) | **`1.50`** | **Esports Sweet Spot (CS2, Apex, Valorant)** |
| **80%** | `1.60` | High Vibrance (Aggressive enemy separation) |
| **85%** | `1.70` | Intense Stylized Colors |
| **90%** | `1.80` | Hyper-saturated Esports |
| **100%** (Maximum) | `2.00` | Maximum Saturation (Highlights begin clipping) |

