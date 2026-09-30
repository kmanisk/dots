# Waydroid on CachyOS (Sway / Intel iGPU + RTX 5050 Mobile) — Implementation & Architecture Guide

A complete, battle-tested reference for setting up, rooting, configuring, and maintaining Waydroid on CachyOS rolling with Sway (Wayland), Magisk Delta root, Zygisk, LSPosed, and hybrid Intel/NVIDIA laptop architecture.

---

## 1. System Topology & Core Invariants

- **Host Environment**: CachyOS rolling (Linux BORE/EEVDF), Sway / Wayland (`wayland-1`).
- **Display Resolution & Density**: 1920×1200 @ 165 Hz (typical Waydroid surface 1920×1170 at 180 DPI).
- **GPU Invariant (Critical)**:
  - Waydroid UI, EGL, and Android hardware acceleration MUST run on the **Intel UHD iGPU** (`/dev/dri/renderD128` using `minigbm_gbm_mesa` and Mesa Intel Vulkan).
  - The discrete NVIDIA RTX 5050 Mobile (`/dev/dri/renderD129`) MUST remain in runtime power management (`auto`, D3cold `suspended`). Waydroid must never be bound to the NVIDIA render node (doing so causes EGL surface crashes and burns ~15–20W battery idle).
- **Binder IPC**: Uses native CachyOS kernel binderfs (`CONFIG_ANDROID_BINDERFS=y`). Binder devices exist at `/dev/binderfs/{binder, hwbinder, vndbinder}`. Do not install out-of-tree DKMS binder packages.
- **Container Freeze Deadlock Fix**: In `/var/lib/waydroid/waydroid.cfg`, ensure:
  ```ini
  [waydroid]
  suspend_action = none
  ```
  Without `suspend_action = none`, the container enters cgroup freezer when switching workspaces or focusing another window in Sway, causing session deadlocks and unresponsiveness.

---

## 2. Directory Layout & Storage Architecture

```text
/var/lib/waydroid/
├── images/
│   ├── system.img          <-- LineageOS 20 GAPPS image (read-only base, ~1.5 GB)
│   └── vendor.img          <-- LineageOS 20 Mainline vendor image (read-only base, ~800 MB)
├── overlay/                <-- Persistent system modifications via tmpfs overlay
│   └── system/etc/init/
│       ├── bootanim.rc     <-- Magisk Delta early-boot post-fs-data hooks
│       ├── media_mounts.rc <-- Mounts /data/media/0/* into /storage/emulated/0/*
│       └── magisk/         <-- Magisk binaries (magisk64, magiskpolicy, su)
└── waydroid.cfg            <-- Main Waydroid container configuration

~/.local/share/waydroid/
└── data/                   <-- Android /data partition (user apps, settings, Magisk DB)
    ├── adb/
    │   ├── magisk/         <-- Persistent Magisk runtime modules and scripts
    │   ├── magisk.db       <-- Magisk SQLite database (Zygisk=1, superuser permissions)
    │   ├── modules/
    │   │   └── zygisk_lsposed  <-- LSPosed v1.9.3_mod Zygisk framework
    │   └── lspd/           <-- LSPosed runtime config, daemon bridge, logs
    └── misc/adb/adb_keys   <-- Authorized host ADB public key
```

---

## 3. What Worked: Step-by-Step Reconstruction

### A. Base Installation
1. Install Waydroid package:
   ```bash
   sudo pacman -Syu waydroid
   ```
2. Initialize Waydroid with official LineageOS GAPPS (Android 13 / lineage-20):
   ```bash
   sudo waydroid init -s GAPPS -f
   ```
3. Prevent window freeze in `/var/lib/waydroid/waydroid.cfg`:
   ```ini
   suspend_action = none
   ```

### B. Magisk Delta Root & Zygisk Injection
Standard upstream Magisk cannot hook zygote on LXC containers natively. **Magisk Delta (HuskyDG fork)** works by leveraging ptrace-based zygote interception:

1. **Overlay Placement**:
   Place Magisk Delta binaries (`magisk64`, `magiskpolicy`, `su`) under `/var/lib/waydroid/overlay/system/etc/init/magisk/`.
2. **Init Hook (`bootanim.rc`)**:
   Add early boot hooks to `/var/lib/waydroid/overlay/system/etc/init/bootanim.rc`:
   ```rc
   service bootanim /system/bin/bootanimation
       class core animation
       user graphics
       group graphics audio
       disabled
       oneshot
       ioprio rt 0
       task_profiles MaxPerformance

   on post-fs-data
       start logd
       exec u:r:su:s0 root root -- /system/etc/init/magisk/magiskpolicy --live --magisk
       exec u:r:magisk:s0 root root -- /system/etc/init/magisk/magiskpolicy --live --magisk
       exec u:r:update_engine:s0 root root -- /system/etc/init/magisk/magiskpolicy --live --magisk
       mkdir /dev/magisk_iqeoVo2mDrO 700
       exec u:r:su:s0 root root -- /system/etc/init/magisk/magisk64 --auto-selinux --setup-sbin /system/etc/init/magisk /dev/magisk_iqeoVo2mDrO
       exec u:r:su:s0 root root -- /dev/magisk_iqeoVo2mDrO/magisk --auto-selinux --post-fs-data

   on nonencrypted
       exec u:r:su:s0 root root -- /dev/magisk_iqeoVo2mDrO/magisk --auto-selinux --service

   on property:vold.decrypt=trigger_restart_framework
       exec u:r:su:s0 root root -- /dev/magisk_iqeoVo2mDrO/magisk --auto-selinux --service

   on property:sys.boot_completed=1
       mkdir /data/adb/magisk 755
       exec u:r:su:s0 root root -- /dev/magisk_iqeoVo2mDrO/magisk --auto-selinux --boot-complete

   on property:init.svc.zygote=restarting
       exec u:r:su:s0 root root -- /dev/magisk_iqeoVo2mDrO/magisk --auto-selinux --zygote-restart

   on property:init.svc.zygote=stopped
       exec u:r:su:s0 root root -- /dev/magisk_iqeoVo2mDrO/magisk --auto-selinux --zygote-restart
   ```
3. **Database Configuration**:
   Enable Zygisk in SQLite (`~/.local/share/waydroid/data/adb/magisk.db`):
   - Table `settings`: `key='zygisk'`, `value='1'`.
   - Table `policies`: `uid=2000` (shell) or root authorized.

### C. LSPosed Framework Integration
1. Module: **LSPosed v1.9.3_mod (7244) Zygisk release** (`mywalkb/LSPosed_mod`).
2. Placed in `~/.local/share/waydroid/data/adb/modules/zygisk_lsposed/`.
3. Install companion APK: `org.lsposed.manager` (APK version matches framework).
4. Verify via ADB:
   ```bash
   adb -s 192.168.240.112:5555 shell "su -c ls -la /data/adb/lspd"
   ```

### D. Navigation Bar Alignment on Desktop Resolutions (Wide Landscape)
On 1920×1170 landscape displays at 180 DPI, Android 13 SystemUI by default glitches button insets, hiding Home and Recents into the corner.
- **The Permanent Fix**:
  ```bash
  adb -s 192.168.240.112:5555 shell cmd overlay enable com.android.internal.systemui.navbar.threebutton
  ```
  This restores standard 3-button layout: Back (`<`), Home (`○`) on bottom-left, Recents (`▢`) on bottom-right.

### E. Google Certified Device & Play Store Registration
GAPPS builds require device registration against Google Play Protect:
```bash
# Retrieve Android Google Service Framework (GSF) ID
adb -s 192.168.240.112:5555 shell 'sqlite3 /data/data/com.google.android.gsf/databases/gservices.db "SELECT value FROM main WHERE name=\"android_id\";"'
```
Register the retrieved decimal ID at: `https://www.google.com/android/uncertified/`.

### F. Host Media Storage Offloading (Preventing Root Partition Bloat)
Android media folders (`Pictures`, `Movies`, `Download`, `Documents`) can be mapped directly to a large auxiliary partition (e.g. `/mnt/Games` or secondary NVMe):
1. In `/var/lib/waydroid/overlay/system/etc/init/media_mounts.rc`:
   ```rc
   on property:sys.boot_completed=1
       mount none /data/media/0/Pictures /storage/emulated/0/Pictures bind
       mount none /data/media/0/Movies /storage/emulated/0/Movies bind
       mount none /data/media/0/Download /storage/emulated/0/Download bind
       mount none /data/media/0/Documents /storage/emulated/0/Documents bind
   ```
2. Host bind mounts external drive directories into `~/.local/share/waydroid/data/media/0/Pictures`.

---

## 4. Session & Process Control Commands

```bash
# Start container systemd service
sudo systemctl start waydroid-container.service

# Start user session (Wayland display wayland-1)
waydroid session start

# Launch full UI window
waydroid show-full-ui

# Launch specific Android package
waydroid app launch com.android.settings
waydroid app launch org.lsposed.manager

# Stop session cleanly
waydroid session stop
sudo systemctl stop waydroid-container.service

# ADB connectivity (container default bridge IP)
adb connect 192.168.240.112:5555
```

---

## 5. Troubleshooting & Invariants Checklist

| Symptom | Root Cause | Working Solution |
| :--- | :--- | :--- |
| **Black screen or crash on launch** | NVIDIA dGPU intercepted Wayland/EGL | Ensure `waydroid` runs without `prime-run`; keep RTX 5050 in `auto`/`suspended`. |
| **Window hangs when unfocused** | Cgroup freezer suspended container | Set `suspend_action = none` in `/var/lib/waydroid/waydroid.cfg`. |
| **Only back `<` visible on navbar** | Landscape insets displaced 3-button bar | Run `adb shell cmd overlay enable com.android.internal.systemui.navbar.threebutton`. |
| **Zygisk fails to activate** | Standard Magisk lacks LXC ptrace hook | Use Magisk Delta with the custom `bootanim.rc` post-fs-data injection. |
| **Boot loop after bad LSPosed module** | Faulty Xposed hook | `touch ~/.local/share/waydroid/data/adb/modules/.disable` to boot in safe mode. |
