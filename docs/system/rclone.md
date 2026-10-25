# Rclone Cloud Storage Architecture & Google Drive Mount Reference

Comprehensive specification and operational guide for the on-demand, zero-idle-RAM Google Drive integration on CachyOS.

---

## 1. Architectural Overview & Philosophy

In accordance with system resource discipline (anti-bloat and zero unnecessary background daemons), cloud storage integration is configured strictly for **on-demand access**:

* **Zero Idle RAM Overhead:** No continuous background sync daemons or idle `rclone` processes consume memory. When not actively reading or writing, memory consumption is 0 MB.
* **Kernel-Level Automount:** Handled natively via systemd kernel automounting (`x-systemd.automount`).
* **Automatic Idle Eviction:** Mounts automatically disconnect and terminate their background process after 2 minutes (120 seconds) of inactivity (`x-systemd.idle-timeout=120`).
* **Btrfs Cache Protection:** The local VFS read/write cache directory is flagged with `chattr +C` (no-CoW) to eliminate filesystem fragmentation on Btrfs.
* **Fast Path Traversal:** Root folder ID caching in `rclone.conf` prevents redundant directory traversal calls to the Google Drive API.

---

## 2. Mount Point & Filesystem Configuration

### Mount Parameters (`/etc/fstab`)

The mount is defined in `/etc/fstab` with strict user mapping and timeouts:

```fstab
gdrive: /mnt/gdrive rclone rw,noauto,nofail,_netdev,x-systemd.automount,x-systemd.idle-timeout=120,allow_other,uid=1000,gid=1000,args2env,config=/home/onyx/.config/rclone/rclone.conf,cache_dir=/home/onyx/.cache/rclone,vfs_cache_mode=full,vfs_cache_max_size=5G,dir_cache_time=12h,poll_interval=0 0 0
```

### Key Options Explained

| Parameter | Purpose |
| :--- | :--- |
| `noauto,nofail` | Prevents boot hangs if offline; boot proceeds without waiting for network. |
| `_netdev` | Flags filesystem as requiring active network connectivity. |
| `x-systemd.automount` | Creates an on-demand virtual trigger on `/mnt/gdrive`. Accessing the directory instantly invokes the mount. |
| `x-systemd.idle-timeout=120` | Unmounts the filesystem and terminates the rclone process after 2 minutes of idle time. |
| `allow_other,uid=1000,gid=1000` | Ensures user ownership and standard file access permissions across graphical and CLI applications. |
| `vfs_cache_mode=full` | Supports random-access reads and writes, local file caching, and streaming. |
| `vfs_cache_max_size=5G` | Caps total local SSD disk cache consumption to 5 GB. |
| `dir_cache_time=12h` | Caches directory trees for 12 hours locally to avoid API rate limits. |

### Permissions Configuration (`/etc/fuse.conf`)

To allow regular user ownership mapping with `allow_other`, `/etc/fuse.conf` requires:

```conf
user_allow_other
```

---

## 3. Storage Hierarchy & Remote Organization

The Google Drive remote (`gdrive:`) is structured strictly into 5 top-level categories. No loose files or unsorted folders reside in the remote root directory.

```
/mnt/gdrive/ (gdrive:)
├── 1_Documents/
│   ├── Academics/                 # Practicals, course projects, research presentations
│   ├── Books to Read/             # Literature and reference epubs/documents
│   ├── Career/Resume/             # Resumes, CVs, and SheetsResume templates
│   ├── Identity/                  # Aadhar cards, certificates, transit receipts
│   ├── Notes_and_Configs/         # Documentation, guides, and text notes
│   └── Work/                      # Professional work archives
│
├── 2_Media/
│   ├── Camera_and_Photos/         # Phone captures, WhatsApp image archives
│   ├── Recorded Lectures/         # University semester lecture recordings
│   └── Screen_Recordings_OK/      # Video recordings and captures
│
├── 3_Gaming/
│   ├── BF1/                       # Battlefield 1 assets and configs
│   ├── BLOODBORNE/                # Bloodborne assets and archives
│   ├── CS 1.6/                    # Counter-Strike 1.6 portable configurations
│   ├── CSGO CONFIG BACKUP/        # Legacy CS:GO configs and autoexecs
│   ├── DS3/                       # Dark Souls III tools and references
│   ├── Mods/                      # General gaming mods
│   ├── Mods Folder IMP/           # Priority game mods archive
│   ├── MSI_and_RTSS_Profiles/     # Afterburner and RivaTuner telemetry profiles
│   ├── Old_PC_Game_Saves/         # Preserved historical game saves
│   ├── PUBG/                      # PUBG backup files
│   └── Steam_User_875656642/      # Steam user configuration and cloud data
│
├── 4_Backups/
│   ├── Backup/                    # Generic backup bundles
│   ├── Custom_OS_ISOs/            # Lightweight OS installation images
│   ├── Daily Drivers/             # Essential tools, scripts, and Goldberg emulator saves
│   ├── Everything/                # Preserved documents and cert archives
│   ├── Firefox Backup/            # Browser profile backups
│   ├── Linux/                     # Linux testing recordings and archives
│   ├── Loose_Files/               # Archived miscellaneous root files
│   ├── Misc_Archive_NNNNNNAANNA/  # Legacy MSI and compressed document archives
│   ├── OLD/                       # Historical data snapshots
│   ├── PC/                        # PC utilities and AutoHotkey scripts
│   ├── PC BACKUP/                 # Portable installers and app tools
│   ├── Ryzen5/                    # Hardware invoices and system profiles
│   ├── Safe_Contacts/             # Exported contacts (.vcf)
│   └── SmartTubeBackup/           # SmartTube configuration backups
│
└── 5_Inbox_Temp/
    └── Temp/                      # Consolidated staging directory for transfers
```

---

## 4. Helper Script Reference (`~/.local/bin/gdrive`)

A dedicated CLI script provides instant status inspection and manual control:

```bash
gdrive status    # Check if currently active (in use) or idle (unmounted, 0 MB RAM)
gdrive up        # Manually wake / trigger the mount
gdrive down      # Immediately unmount and release memory
```

### Implementation Details (`~/.local/bin/gdrive`)

```sh
#!/bin/sh
M=/mnt/gdrive

case "$1" in
  up)
    ls "$M" >/dev/null 2>&1
    if [ -d "$M/1_Documents" ]; then
      echo "Mounted gdrive on-demand at $M"
    else
      echo "Failed to access $M"
      exit 1
    fi
    ;;
  down)
    sudo systemctl stop mnt-gdrive.mount 2>/dev/null || true
    echo "Unmounted $M"
    ;;
  status)
    if systemctl is-active --quiet mnt-gdrive.mount 2>/dev/null; then
      echo "gdrive: ACTIVE (in use, idle auto-unmounts after 2 minutes)"
    else
      echo "gdrive: IDLE (unmounted, 0 MB RAM)"
    fi
    ;;
  *)
    echo "usage: gdrive up|down|status"
    exit 1
    ;;
esac
```

---

## 5. Security & Secret Handling

* **Credentials Location:** `~/.config/rclone/rclone.conf`.
* **Dotfile Exclusion:** Never track `~/.config/rclone/rclone.conf` in unencrypted Git or plain chezmoi commits (RULE 6).
* **Encryption Policy:** If synchronizing via chezmoi, encrypt the entire file using age:
  ```bash
  chezmoi add --encrypt ~/.config/rclone/rclone.conf
  ```
* **OAuth Safety:** Google Cloud client credentials used for rclone should be dedicated desktop application credentials with user rate quotas.

---

## 6. Technical Limitations & Gaming Policy

1. **Storage and Viewing Only:**
   * This integration is designated strictly for file storage, browsing, media playback, and backups.
2. **Proton / Steam Incompatibility:**
   * Running Windows games via Steam Proton directly from the cloud mount is unsupported. Proton requires creating POSIX symlinks inside `compatdata/<appid>/pfx/dosdevices/` (`c:`, `z:`). Google Drive FUSE does not support POSIX symlink creation, causing Proton to immediately abort upon execution.
   * Games must always be installed on local NVMe storage (`/mnt/Games/SteamLibrary`).
3. **Bulk Transfers:**
   * For large file transfers (>1 GB), prefer direct CLI copy operations rather than copying through GUI file managers:
     ```bash
     rclone copy /path/to/source gdrive:4_Backups/ -P
     ```
   * Use `--dry-run` when testing `rclone sync` operations to prevent accidental deletions.
