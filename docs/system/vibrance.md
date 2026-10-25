# Digital Vibrance & Color Saturation Reference (Linux vs Windows)

This document provides the mathematical conversion formulas and complete 1-to-1 calibration chart between the **Windows NVIDIA Control Panel (Digital Vibrance)**, **Linux NVIDIA NVKMS (`nvibrant-ctl`)**, and **Linux Intel DRM CTM (`vibrance-ctl`)** values.

---

## Active Architecture

- **Active GPU Mode:** `AsusMuxDgpu` (direct hardware MUX scanout on `eDP-1`).
- **Active Controller:** `nvibrant-ctl` (NVKMS direct ioctl via `nvibrant`). Range: `-1024..1023` (`0` = neutral 50%).
- **Fallback / Hybrid Mode:** `vibrance-ctl` (Intel CRTC CTM matrix via `ctm-test`). Range: `0.00..2.00` (`1.00` = neutral 50%).
- **Unified Applicator:** `~/.local/bin/apply-vibrance` automatically detects the GPU mode via `supergfxctl` and applies the authoritative config (`~/.config/nvibrant` or `~/.config/vibrance`) on Sway startup and reload without background daemons.

---

## 80% Windows Counterpart (Active System Setting)

- **Windows NVIDIA Control Panel:** `+ 80%`
- **Linux NVIDIA (`nvibrant-ctl`):** **`614`** (or directly `nvibrant-ctl set 80%`)
- **Linux Intel CTM (`vibrance-ctl`):** **`1.60`**
- **Config Storage:** `~/.config/nvibrant` (contains `614`), `~/.config/vibrance` (contains `1.40` or `1.60`)
- **Profile:** High Vibrance (Aggressive player silhouette separation for competitive esports like CS2).

---

## Mathematical Conversion Formulas

### 1. NVIDIA NVKMS (`nvibrant-ctl`, AsusMuxDgpu Mode)

$$\text{nvibrant Value} = \frac{\text{Windows \%} - 50}{50} \times 1023$$

$$\text{Windows \%} = 50 + \left(\frac{\text{nvibrant Value}}{1023} \times 50\right)$$

*Note: `nvibrant-ctl` automatically accepts percentage notation, e.g. `nvibrant-ctl set 75%` or `nvibrant-ctl set 80%`.*

### 2. Intel DRM CTM (`vibrance-ctl`, Hybrid Mode)

$$\text{Linux Scalar} = 1.0 + \frac{\text{Windows \%} - 50}{50}$$

$$\text{Windows \%} = 50 + \left[(\text{Linux Scalar} - 1.0) \times 50\right]$$

---

## Complete 0% to 100% Calibration Chart (5% Increments)

| Windows Control Panel | NVIDIA dGPU (`nvibrant-ctl set <val>`) | Intel Hybrid (`vibrance-ctl set <val>`) | Visual Profile & Use-Case |
| :---: | :---: | :---: | :--- |
| **0%** | `-1023` | `0.00` | Full Grayscale / Monochrome |
| **5%** | `-921` | `0.10` | Heavy Desaturation |
| **10%** | `-818` | `0.20` | Strong Desaturation |
| **15%** | `-716` | `0.30` | Muted / Bleached Look |
| **20%** | `-614` | `0.40` | Low Saturation |
| **25%** | `-512` | `0.50` | Half-neutral Desaturation |
| **30%** | `-409` | `0.60` | Pale / Washed Tone |
| **35%** | `-307` | `0.70` | Noticeably Subdued Colors |
| **40%** | `-205` | `0.80` | Slight Desaturation |
| **45%** | `-102` | `0.90` | Nearly Neutral (Gentle Cool Mute) |
| **50%** | **`0`** | **`1.00`** | **Factory Default sRGB (Untouched neutral standard)** |
| **55%** | `102` | `1.10` | Subtle Warmth / Slight Enhancement |
| **60%** | `205` | `1.20` | Gentle Pop (Comfortable Desktop / Web / Reading) |
| **65%** | `307` | `1.30` | Natural Vividness |
| **70%** | `409` | `1.40` | Standard Gaming Saturation |
| **75%** | `512` | `1.50` | Competitive Esports Sweet Spot |
| **80%** | **`614`** | **`1.60`** | **Active System Setting (High Target Separation)** |
| **85%** | `716` | `1.70` | Intense Stylized Colors |
| **90%** | `818` | `1.80` | Hyper-saturated Esports |
| **95%** | `921` | `1.90` | Extreme Saturation |
| **100%** | `1023` | `2.00` | **Maximum Hardware Saturation** (Color clipping threshold) |

---

## Quick Reference CLI Commands

### NVIDIA dGPU Mode (`nvibrant-ctl`):
```bash
# View active configured value
nvibrant-ctl get

# Set by percentage (recommended)
nvibrant-ctl set 80%

# Set by integer raw value
nvibrant-ctl set 614

# Step up or down by 5%
nvibrant-ctl up
nvibrant-ctl down

# Reset to neutral stock (50% on Windows)
nvibrant-ctl off
```

### Hybrid Intel CTM Mode (`vibrance-ctl`):
```bash
# View active level
vibrance-ctl get

# Set to match Windows 80%
vibrance-ctl set 1.60

# Reset to neutral stock (50% on Windows)
vibrance-ctl off
```

### Universal Applicator (`apply-vibrance`):
```bash
# Run one-shot mode-aware enforcement (called by sway-run and sway reload hook)
apply-vibrance
```
