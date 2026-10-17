---
name: waydroid-cachyos-root
description: Operational knowledge, architecture invariants, Magisk Delta overlay root mechanics, hybrid GPU power handling, and recovery procedures for Waydroid on CachyOS Sway/Wayland.
---

# Waydroid + Root Architecture & Operational Standards

## 1. System Topology & Hardware Offload Rules

- **Host Session**: CachyOS rolling, Sway / Wayland (`wayland-1`).
- **GPU Invariant**: 
  - Waydroid UI & Android hardware acceleration run exclusively on the **Intel UHD iGPU** (`/dev/dri/renderD128` via `minigbm_gbm_mesa` and `mesa` EGL / Intel Vulkan).
  - The discrete NVIDIA RTX 5050 Mobile (`/dev/dri/renderD129`) remains managed for offload. Waydroid itself never attaches to the NVIDIA render node.
- **Binder IPC**: Uses native CachyOS kernel binderfs (`CONFIG_ANDROID_BINDERFS=y`). Mountpoint is `/dev/binderfs` with devices `binder`, `hwbinder`, and `vndbinder`. No out-of-tree DKMS binder modules.
- **Container Freeze Handling**: `suspend_action = none` in `/var/lib/waydroid/waydroid.cfg` to prevent cgroup freezer deadlocks when switching windows.

---

## 2. Root, GAPPS & LSPosed Architecture

```
/var/lib/waydroid/images/
├── system.img        <-- Official LineageOS 20 GAPPS system image (read-only)
└── vendor.img        <-- CLEAN mainline vendor image (read-only)

/var/lib/waydroid/overlay/
└── system/etc/init/
    ├── bootanim.rc       <-- Injects early boot post-fs-data hooks
    ├── media_mounts.rc   <-- Binds /data/media/0/* into /storage/emulated/0/*
    └── magisk/           <-- Magisk Delta binary engine (magiskpolicy, magisk64, su)

/mnt/Games/AndroidMedia/  <-- Dedicated media storage on 300GB NTFS disk
├── Pictures/             <-- Bound into Android /sdcard/Pictures
├── Movies/               <-- Bound into Android /sdcard/Movies
├── Download/             <-- Bound into Android /sdcard/Download
└── Documents/            <-- Bound into Android /sdcard/Documents

~/.local/share/waydroid/data/
├── adb/
│   ├── magisk/           <-- Persistent Magisk runtime components
│   ├── magisk.db         <-- Policy SQLite DB (root_access, zygisk=1)
│   ├── modules/
│   │   └── zygisk_lsposed <-- LSPosed v1.9.3_mod Zygisk module
│   └── lspd/             <-- LSPosed runtime config, bridge, and logs
└── misc/adb/adb_keys     <-- Host ADB authorization key
```

- **Root Engine**: **Magisk Delta (HuskyDG fork) / MAGISKSU** (`0fe46c5a-delta:MAGISKSU`).
- **Zygisk Implementation**: Magisk Delta ptrace/ptraced-based Zygisk injection (`zygisk=1`).
- **Xposed Framework**: **LSPosed v1.9.3_mod (7244) Zygisk release** (`mywalkb/LSPosed_mod`).
- **LSPosed Manager**: `org.lsposed.manager` installed as a native app and rendered in Sway (`app_id`: `waydroid.org.lsposed.manager`).

---

## 3. Operational Commands & ADB Workflow

### Session Management & Helper
```bash
# Launch full UI or app with automatic session-check
waydroid-launcher                           # full Android UI
waydroid-launcher org.lsposed.manager       # LSPosed Manager
waydroid-launcher com.android.vending       # Google Play Store
waydroid-launcher com.android.settings      # Settings
```

### ADB Connection & Module Management
```bash
# Connect ADB over container bridge
adb connect 192.168.240.112:5555

# Verify Android userspace root (UID 0 via MagiskSU)
adb -s 192.168.240.112:5555 shell "su -c id"

# If a bad Xposed module causes issues, disable all modules:
touch ~/.local/share/waydroid/data/adb/modules/.disable
# Or remove:
adb -s 192.168.240.112:5555 shell "su -c 'magisk --remove-modules'"

---

## 4. UI & Navigation Bar Standards

- **Layout**: 3-button navigation overlay (`com.android.internal.systemui.navbar.threebutton`) is enabled by default to ensure Back (`<`), Home (`○`), and Recents (`▢`) appear properly formatted on wide landscape desktop resolutions (e.g. 1920x1170).
- **Command to verify/restore**:
  ```bash
  adb -s 192.168.240.112:5555 shell cmd overlay enable com.android.internal.systemui.navbar.threebutton
  ```
