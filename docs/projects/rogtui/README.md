# rogtui: ASUS ROG & TUF Hardware Control Center

**Lightweight, keyboard-driven hardware control center for ASUS ROG and TUF gaming laptops on Linux.**

- **Project Path:** [`/home/onyx/Projects/rogtui`](file:///home/onyx/Projects/rogtui)
- **Version:** `0.1.3` ([crates.io](https://crates.io/crates/rogtui/0.1.3), [GitHub Release](https://github.com/kmanisk/rogtui/releases/tag/v0.1.3))
- **Installed Binary:** `~/.local/bin/rogtui`
- **System Service:** Communicates via system D-Bus with `asusd` and `supergfxd`.

---

## 1. Overview

`rogtui` provides full hardware telemetry and control without running bulky electron background processes or desktop applets:
- **Instant Launch:** Initializes in under 2ms with zero daemon overhead.
- **Minimal Footprint:** 0.0% idle CPU and ~4 MB resident memory.
- **Direct System D-Bus Integration:** Speaks directly to `org.asuslinux.Daemon` and `org.supergfxd.Daemon`.

---

## 2. Capabilities

### Performance Profiles & Fan Curve Studio
- **Profile Cycling (`p`):** Instant switching between *Quiet*, *Balanced*, and *Performance* modes.
- **8-Point Custom Curves (`f`):** Interactive calibration of temperature-to-PWM fan curves for CPU and GPU fans with live thermal marker tracking (`◆`).

### Dynamic GPU Switching (Rule 2 Integration)
- **`Integrated`:** Desktop runs on Intel UHD Graphics, dGPU powered down.
- **`Hybrid`:** Desktop on Intel iGPU, 3D/CUDA offloads to RTX 5050 Mobile via `prime-run`.
- **`AsusMuxDgpu`:** Direct hardware MUX connection from RTX 5050 Mobile to the internal panel, bypassing the iGPU completely for lowest latency.

### Power & Battery Care
- **Battery Charge Thresholds:** Configures hardware charge stops (60%, 80%, 100%) to preserve battery longevity.
- **CPU Power Envelopes (SPL / sPPT / fPPT):** Adjusts sustained and burst TDP limits.
- **Panel Overdrive:** Toggles panel response overdrive on 165Hz displays.

---

## 3. Keyboard Workflows

| Keybinding | Action |
| :--- | :--- |
| `p` | Cycle performance profile (Quiet / Balanced / Performance) |
| `g` | Toggle GPU mode (Integrated / Hybrid / AsusMuxDgpu) |
| `f` | Open fan curve studio |
| `b` | Cycle battery charge limit (60% / 80% / 100%) |
| `o` | Toggle panel overdrive |
| `r` | Refresh hardware telemetry |
| `q` | Quit application |

---

## 4. Key References & Documentation

- [Upstream Repository README](./source-README.md)
- [ASUS Architecture, DBus Services, and Software Effects](./architecture.md)
- [System Philosophy & Hardware Control](file:///home/onyx/docs/system/rogtui-hardware-control.md)
- [Dynamic GPU Architecture](file:///home/onyx/docs/display/dgpu-mode.md)
- [Source Code Directory](file:///home/onyx/Projects/rogtui)
