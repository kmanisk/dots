# Waydroid Environment & Integration Guide

This document is the technical reference for configuring, running, maintaining, and integrating the Waydroid Android container on this workstation. It covers container runtime architecture, Magisk root, the Google Photos Pixel XL tier configuration, host storage integration, and APK management.

---

## 1. Executive Summary & Verified Live State

- **Container Status**: Operates strictly on-demand via `waydroid-launcher` / `waydroid-stop`.
- **GPU Acceleration**: NVIDIA RTX 5050 Mobile via `waydroid-nvidia-bin` (`nvidia-prolapse` vendor image with SurfaceFlinger ANGLE over Mesa NVK Vulkan).
- **ARM Translation**: `libhoudini` translation layer enabled for ARM64/ARMv7 binaries.
- **Root Management**: Kitsune Mask (Magisk Delta) `v27.2-Waydroid:MAGISKSU` integrated systemlessly.
- **Google Photos Configuration**: Google Pixel XL (2016) device profile spoofing active, granting Google Photos original-quality backup exemption without quota consumption.
- **Quota Exemption Status**: Active and persistent across container restarts. Google Photos displays the badge: *"This Pixel can back up unlimited photos & videos at no charge."*
- **Host Integration**: POSIX ACLs configured for host file manager access to emulated `/sdcard/`, and double-click APK installation bound via `.desktop` entry.

---

## 2. Workstation Architecture & Components

### Host System
- **OS**: CachyOS Linux x86_64 (`linux-cachyos`).
- **Desktop**: Sway 1.12 Wayland (`wayland-1`).
- **GPU Path**: Dual GPU (Intel UHD iGPU + NVIDIA RTX 5050 Mobile 8GB). Waydroid runs on the RTX 5050 via `waydroid-nvidia-bin` 0.2.0-1.
- **Dotfiles & Config Authority**: Chezmoi (`~/.local/share/chezmoi`).

### Android Guest Environment
- **Waydroid Version**: 1.6.3 (`waydroid-nvidia-bin` 0.2.0-1).
- **Android Image**: LineageOS 20 GAPPS (Android 13, `x86_64`), build `TQ3A.230901.001`.
- **ARM Translation**: `libhoudini` installed via audited `casualsnek/waydroid_script`.

### Root & Spoofing Framework
- **Root Manager**: Kitsune Mask (Magisk Delta) `v27.2-Waydroid:MAGISKSU` (package `io.github.huskydg.magisk`).
  - Deployed systemlessly into `/var/lib/waydroid/overlay/system/etc/init/magisk/` and initialized via `bootanim.rc`.
  - Configuration (`/data/adb/magisk.db`): `zygisk=1`, `magiskhide=1`, `denylist=0`. Google Photos is excluded from `hidelist`.
- **Target Application**: Google Photos (`com.google.android.apps.photos`), target `versionCode=49953386`, `versionName=7.24.0.747539053`.
- **Active Magisk Module**: Hardened `gphotos-unlimited` (`id=gphotos-unlimited`, `version=v49953386`) located at `~/.local/share/waydroid/data/adb/modules/gphotos-unlimited/`.

---

## 3. Google Photos Pixel XL Tier Mechanism

The storage quota exemption uses five coordinated layers to ensure Google Photos and Google Play Services (GMS) consistently detect the environment as a genuine 2016 Pixel XL:

### Layer 1: Patched Application Binary
- The module provides a patched `Photos.apk` located at `~/.local/share/waydroid/data/adb/modules/gphotos-unlimited/Photos.apk`.
- This APK is bind-mounted directly over the installed application's base binary (`/data/app/*/com.google.android.apps.photos*/base.apk`).
- It unlocks the internal Pixel storage entitlement routines and Pixel-exclusive editing tools.

### Layer 2: Early Boot Mount (post-fs-data)
- Rather than deferring the mount to late boot, `post-fs-data.sh` executes during early initialization before Zygote or application processes start:
  ```bash
  target=$(find /data/app -path "*/com.google.android.apps.photos*/base.apk" 2>/dev/null | head -n 1)
  chcon u:object_r:apk_data_file:s0 "$MODDIR/Photos.apk"
  mount -o bind "$MODDIR/Photos.apk" "$target"
  ```
- This prevents Google Photos from launching with the unmodified base APK during system startup.

### Layer 3: System Property Injection (system.prop)
- The module provides `/data/adb/modules/gphotos-unlimited/system.prop` containing:
  ```properties
  ro.product.model=Pixel XL
  ro.product.brand=google
  ro.product.manufacturer=Google
  ro.product.device=marlin
  ro.product.name=marlin
  ```
- Magisk loads these properties at early boot via `resetprop`, ensuring `Build.MODEL`, `Build.MANUFACTURER`, and `Build.BRAND` report as Google Pixel XL to any framework query.

### Layer 4: System Feature Declarations (pixel_2016_exclusive.xml)
- The module injects `/system/etc/sysconfig/pixel_2016_exclusive.xml` into Android's framework configuration:
  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <config>
      <feature name="com.google.android.apps.photos.NEXUS_PRELOAD" />
      <feature name="com.google.android.apps.photos.nexus_preload" />
  </config>
  ```
- Android's Package Manager exposes these flags (`pm list features`), satisfying Google Photos' entitlement check for preloaded Pixel hardware.

### Layer 5: Store Detachment (gphotos-detach)
- The module ships `/system/bin/gphotos-detach`, executed during `service.sh`.
- It removes `com.google.android.apps.photos` from Google Play Store's local SQLite database (`Finsky`), preventing Google Play Store or Aurora Store from automatically overwriting the patched APK with upstream releases.

---

## 4. Boot Persistence & Regression Fix

### Root Cause of Initial Reboot Loss
In unhardened module setups:
1. `post-fs-data.sh` called `umount -l` without remounting during early boot.
2. `service.sh` waited through a boot-complete polling loop and sleep interval before running `bind_apk`.
3. Early background start of Google Photos executed against the unmodified base APK.
4. Google Play Services detected default container identity (`ro.product.model = WayDroid x86_64 Device`) without `NEXUS_PRELOAD` feature declarations, revoked the tier, and wrote `unlimited_reason = -1` into `accounts.xml`.
5. Once `service.sh` eventually mounted `Photos.apk`, the unpatched code remained resident in memory because `service.sh` did not kill the running process.

### Hardening Implementation
1. **Immediate Mount**: `post-fs-data.sh` mounts `Photos.apk` at early boot prior to Zygote initialization.
2. **Property Injection**: Added `system.prop` with Pixel XL properties to satisfy early GMS check-ins.
3. **Feature Injection**: Added `pixel_2016_exclusive.xml` under `/system/etc/sysconfig/`.
4. **Process Cleanup**: `service.sh` runs `am force-stop com.google.android.apps.photos` following detachment checks, ensuring any transient process restarts with the spoofed tier.

---

## 5. Host & Desktop Integration

### A. Host Media Storage Permissions
Waydroid maps `/sdcard/` to `~/.local/share/waydroid/data/media/0/` on the Linux host. Android creates this directory under UID/GID `1023:1023` (`media_rw`) with mode `0770`, leading to host permission errors in non-root tools (e.g. Yazi, Thunar).

Recursive POSIX ACLs provide the host user access without altering Android internal file ownership:
```bash
sudo setfacl -R -m u:onyx:rwx,d:u:onyx:rwx ~/.local/share/waydroid/data/media
```

### B. Double-Click & Drag-Drop APK Installation
1. **Direct Window Drag-and-Drop**: Waydroid Wayland client surfaces do not implement data-device drag-and-drop from the host compositor. Dropping files onto the Waydroid window has no effect.
2. **Terminal Drag-and-Drop**: Run `waydroid app install ` in a terminal and drag the `.apk` file into the terminal window to populate the path, then press Enter.
3. **Double-Click Handler**:
   - Helper script: `~/.local/bin/waydroid-apk-install` (staged in chezmoi at `~/.local/share/chezmoi/dot_local/bin/executable_waydroid-apk-install`). Checks container and session status, starts Waydroid in the background if stopped, waits for the client bridge, runs `waydroid app install`, and dispatches desktop notifications.
   - Desktop entry: `~/.local/share/applications/waydroid-apk-install.desktop` registers MIME type `application/vnd.android.package-archive`.
   - MIME default: `application/vnd.android.package-archive=waydroid-apk-install.desktop` set in `~/.config/mimeapps.list` and chezmoi.
   - Thunar context menu: Registered `Install in Waydroid` custom action in `~/.config/Thunar/uca.xml`.

### C. Host-to-Guest Media Directories
Host media directories map directly to Android emulated storage:
- `~/.local/share/waydroid/data/media/0/DCIM/Camera/` -> `/sdcard/DCIM/Camera/` (Scanned and backed up by default).
- `~/.local/share/waydroid/data/media/0/Pictures/` -> `/sdcard/Pictures/` (Configured under "Back up device folders" in Google Photos settings).
- `~/.local/share/waydroid/data/media/0/Download/` -> `/sdcard/Download/`.

To force an immediate media library indexing scan for a newly copied file:
```bash
sudo waydroid shell -- am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/DCIM/Camera/<filename>
```

---

## 6. Container Lifecycle Commands

Waydroid operates strictly on-demand on this workstation. Do not enable `waydroid-container.service` at system boot.

- **Launch Full UI**:
  ```bash
  waydroid-launcher       # or fish alias: wd
  ```
- **Stop Session & Container**:
  ```bash
  waydroid-stop           # or fish alias: wds
  ```
- **Clean Full Restart**:
  ```bash
  waydroid-restart        # or fish alias: wdr
  ```
- **Launch Google Photos Directly**:
  ```bash
  waydroid app launch com.google.android.apps.photos
  ```

---

## 7. Maintenance & Operation Contracts

1. **Do NOT update Google Photos via Play Store or Aurora Store**:
   An update will install the upstream unmodified release, overwriting `Photos.apk` and breaking the device tier spoof.
2. **Do NOT disable or remove the Magisk module**:
   The module `gphotos-unlimited` in Kitsune Mask must remain enabled.
3. **Do NOT execute `waydroid init -f`**:
   Overwriting the container destroys `/data` and systemless overlays. Host package updates (`pacman -Syu` / `paru`) and NVIDIA setup reruns (`waydroid-nvidia-setup`) do not touch `/data` and are safe.
4. **Preserve Overlay Architecture**:
   Root and system customizations are contained in `/data/adb/modules/` and `/var/lib/waydroid/overlay/system/`. Base system images (`system.img`, `vendor.img`) remain pristine.

---

## 8. Verification & Diagnostic Checklist

Run these commands to verify the complete runtime chain:

```bash
# 1. Verify container and session status
waydroid status

# 2. Verify Pixel XL model spoof
sudo waydroid shell getprop ro.product.model
# Expected output: Pixel XL

# 3. Verify NEXUS_PRELOAD system features
sudo waydroid shell pm list features | grep -i nexus
# Expected output: feature:com.google.android.apps.photos.NEXUS_PRELOAD

# 4. Verify base.apk bind-mount
sudo waydroid shell grep photos /proc/mounts
# Expected output: /dev/... /data/app/.../com.google.android.apps.photos.../base.apk

# 5. Verify Google Photos package version
sudo waydroid shell dumpsys package com.google.android.apps.photos | grep versionCode
# Expected output: versionCode=49953386

# 6. Verify non-root host media directory access
ls -la ~/.local/share/waydroid/data/media/0/Download/
# Expected: listings without 'Permission denied'
```
