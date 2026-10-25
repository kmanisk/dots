# Linux Filesystem Hierarchy & Btrfs Subvolumes Guide

A technical reference breakdown of the Linux Root Filesystem, Filesystem Hierarchy Standard (FHS), and Btrfs Subvolume architecture configured on CachyOS.

---

## 1. Filesystem Hierarchy Standard (FHS) Quick Reference

### `/etc` — Host Configuration
- **Purpose:** System-wide, host-specific configuration files.
- **Type:** Plain text configuration files only (no binaries).
- **Examples:** `/etc/fstab`, `/etc/pacman.conf`, `/etc/sudoers`, `/etc/security/`.

### `/dev` — Device Nodes
- **Purpose:** Hardware endpoints exposing driver interfaces via `devtmpfs`.
- **Character Devices:** Stream bytes sequentially without buffering (`/dev/tty`, `/dev/urandom`, `/dev/null`).
- **Block Devices:** Transfer fixed-size data blocks with random access (`/dev/nvme0n1`, `/dev/sda`).

### `/sys` — Sysfs Device Model
- **Purpose:** Virtual filesystem created in RAM by the Linux kernel exposing runtime driver states, power profiles, device buses, and hardware telemetry.
- **Examples:** `/sys/class/power_supply/BAT0/`, thermal zones, GPU power limits, CPU frequency governors.

### `/proc` — Procfs Process & Kernel State
- **Purpose:** In-memory filesystem exposing running processes and live kernel configurations.
- **Numbered Folders (`/proc/<PID>`):** Each directory corresponds to an active Process ID.
  - `fd/`: File descriptors (all open files, sockets, and pipes held by the process).
  - `cwd`: Symlink to the current working directory of the process.
  - `cmdline`: The full command string used to launch the process.
  - `status` / `stat`: Process memory usage, thread count, state, and UID/GID permissions.
  - `maps` / `smaps`: Detailed virtual address memory map.

### `/tmp` vs `/run` vs `/var`
| Directory | Storage Backing | Persistence | Core Use Case |
| :--- | :--- | :--- | :--- |
| **`/tmp`** | `tmpfs` (RAM) | Wiped on reboot | Ephemeral scratchpad for applications, temporary archives. |
| **`/run`** | `tmpfs` (RAM) | Wiped on reboot | Live daemon runtime states, PID files, Wayland and PipeWire UNIX sockets. |
| **`/var`** | NVMe (SSD) | **Persistent** | Variable operational state that must survive reboots: pacman package cache (`/var/cache/pacman/pkg`), systemd journal logs (`/var/log`), Flatpak/VM containers (`/var/lib`). |

### `/usr` & The UsrMerge
- **`/usr`:** Stands for **Unix System Resources**. Managed strictly by the package manager (`pacman`).
- **`/usr/local/bin`:** Reserved for the local system administrator. `pacman` will never touch or overwrite custom scripts placed here.
- **UsrMerge:** `/bin -> usr/bin`, `/sbin -> usr/bin`, and `/lib64 -> usr/lib` are symlinks that consolidate all distribution binaries and shared libraries into `/usr` while preserving legacy compatibility.

### `/mnt` vs `/boot`
- **`/mnt`:** Administrator-defined mount targets for secondary drives configured in `/etc/fstab` (e.g. `/mnt/Games`, `/mnt/windows`).
- **`/boot`:** Contains kernel images (`vmlinuz-linux-cachyos`), initramfs (`initramfs-linux-cachyos.img`), CPU microcode, and the EFI system partition (`/boot/efi`).

---

## 2. Btrfs Subvolumes & Snapshots Demystified

### What is a Btrfs Subvolume?
A subvolume is **not** a physical disk partition. It is an independently mountable root tree inside a single shared storage pool. 

On this laptop, physical partition `/dev/nvme0n1p6` holds your single Btrfs pool. Inside it, independent subvolumes share the same unallocated NVMe storage space without artificial size boundaries.

### Actual Subvolume Layout on this Machine (`findmnt`)

```text
/dev/nvme0n1p6 (Single NVMe Btrfs Pool)
├── [/@]               -> Mounted at /               (Root system OS)
├── [/@snapshots]      -> Mounted at /.snapshots     (Root system rollback points)
├── [/@home]           -> Mounted at /home           (User data: /home/onyx)
├── [/@home_snapshots] -> Mounted at /home/.snapshots(Home personal rollbacks)
├── [/@root]           -> Mounted at /root           (Root user home folder)
├── [/@srv]            -> Mounted at /srv            (Server data)
├── [/@cache]          -> Mounted at /var/cache      (Pacman package cache)
├── [/@log]            -> Mounted at /var/log        (Systemd journal logs)
└── [/@tmp]            -> Mounted at /var/tmp        (Preserved temp storage)
```

### Is Root the Same as `/dev` and `/mnt`?
**No.** Here is the distinction:
1. **The Root Subvolume (`/@` mounted at `/`):**
   - Contains the operating system binaries, system libraries, and core configuration (`/usr`, `/etc`, `/bin`).
   - Does **not** contain `/dev` or `/proc` on disk. Those are virtual filesystems generated dynamically in RAM by the kernel.
   - Does **not** contain `/mnt/Games` or `/mnt/windows`. Those are separate NTFS partitions (`nvme0n1p5`, `nvme0n1p3`) mounted on top of empty directory anchor points.

2. **The Home Subvolume (`/@home` mounted at `/home`):**
   - Contains all user personal directories, including `/home/onyx`.
   - Your configurations (`/home/onyx/.config`), desktop files, code, and downloads live exclusively inside `@home`.

### Why Are `@` and `@home` Separated in Snapshots?
Because `@` and `@home` are distinct subvolumes, **snapshots taken in `/.snapshots` only snapshot the system OS (`/@`)**:
- **Scenario:** A CachyOS kernel or graphics driver update breaks your system.
- **Rollback:** You restore a snapshot from `/.snapshots` back to yesterday.
- **Result:** The system files in `/usr` and `/etc` revert to the working state, but your personal files, browser tabs, documents, and game saves in `/home/onyx` remain completely untouched.
