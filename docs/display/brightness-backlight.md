# Brightness Control — AsusMuxDgpu (nvidia_wmi_ec_backlight)

**Status:** Working. Hardware backlight (0–100% physical nits) + sub-zero software
dimming (below 0%) fully functional after kernel ACPI and NVIDIA registry fix.

**Date resolved:** 2026-10-03

---

## Problem Summary

In `AsusMuxDgpu` mode the kernel registers the `nvidia_wmi_ec_backlight` sysfs node,
and `brightnessctl set X%` changes the number in
`/sys/class/backlight/nvidia_wmi_ec_backlight/brightness` — but **without the right
kernel parameters the ASUS Embedded Controller never wires that value to the physical
panel PWM pins**. The OSD showed 100% while the screen stayed physically dim (~45% nits
max), because:

1. The ACPI backlight call was silently dropped — panel PWM never received the command.
2. `wl-gammarelay-rs Brightness` had been left at `0.42` from earlier sub-zero dimming
   sessions, capping perceived brightness to 42% in software on top of the hardware gap.

---

## Root Cause

| Layer | Issue |
|---|---|
| Kernel ACPI | `nvidia_wmi_ec_backlight` driver not wired to EC panel PWM without `acpi_backlight=native` |
| NVIDIA driver | `EnableBrightnessControl` registry key disabled by default — driver ignores backlight requests |
| Software gamma | `wl-gammarelay-rs Brightness` had drifted to `0.42` from old sub-zero sessions |

---

## Fix Applied

### 1. Kernel Boot Parameters

Added to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`:

```
acpi_backlight=native nvidia.NVreg_RegistryDwords=EnableBrightnessControl=1
```

- `acpi_backlight=native` — forces the kernel to use native ACPI panel backlight
  control, correctly mapping EC writes to the eDP-1 PWM hardware.
- `nvidia.NVreg_RegistryDwords=EnableBrightnessControl=1` — enables the NVIDIA driver's
  internal brightness control handler so it forwards backlight requests to the panel.

**Regenerated grub.cfg:**

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

**Verified in `/boot/grub/grub.cfg`:**

```
linux /@/boot/vmlinuz-linux-cachyos ... i915.enable_psr=0 \
  acpi_backlight=native nvidia.NVreg_RegistryDwords=EnableBrightnessControl=1
```

### 2. Failsafes Taken Before Edit

- Snapper root snapshot **#712** (`pre-backlight-kernel-params`, agent=antigravity)
- File backups: `/etc/default/grub.bak-backlight`, `/boot/grub/grub.cfg.bak-backlight`
- `GRUB_TIMEOUT` raised from `1` → `3` seconds to allow menu access if needed
- `grub-btrfsd` service enabled — auto-populates snapshot boot entries in GRUB menu on
  each new snapshot, providing in-GRUB rollback without a live USB

---

## Current Brightness Stack (`AsusMuxDgpu`)

```
Brightness key down:
  HW% > 0  →  brightnessctl set X%-      (EC → nvidia_wmi_ec_backlight → panel PWM)
               wl-gammarelay Brightness = 1.0  (lock software at full)
  HW% == 0 →  wl-gammarelay Brightness -= 0.05  (sub-zero gamma dim, floor 0.15)
               OSD: "🌙 Sub-Zero: -N%"

Brightness key up:
  SW% < 100 →  wl-gammarelay Brightness += 0.05  (recover sub-zero first)
  SW% == 100 → brightnessctl set +X%     (EC → panel PWM, up to 300 nits)
               wl-gammarelay Brightness = 1.0  (ensure no gamma cap)
```

Script: `~/.local/bin/change-brightness`

---

## Rollback Instructions

If backlight breaks after future kernel/BIOS updates:

```bash
# Option A: restore grub config from file backup
sudo cp /etc/default/grub.bak-backlight /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Option B: reboot and select Btrfs snapshot #712 from GRUB snapshot submenu
# (grub-btrfsd auto-populates it in the GRUB boot menu)
```

---

## Devices & Tools

| Item | Value |
|---|---|
| Backlight sysfs | `/sys/class/backlight/nvidia_wmi_ec_backlight` |
| Max brightness | `100` (maps to ~300 nits on AU Optronics B160UAN07.K) |
| HW control | `brightnessctl` |
| Software gamma | `wl-gammarelay-rs` via D-Bus (`rs.wl-gammarelay`) |
| Panel | `AU Optronics B160UAN07.K` (1920×1200 @ 165Hz, eDP-1) |
