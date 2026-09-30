# Future System Improvements & Curated Utilities

Evaluation and roadmap of portable, zero-daemon, bloat-free tools audited from community projects (**dusklinux/dusky** and **omacom/omarchy**) for this CachyOS + i3/Sway gaming setup.

---

## 1. Selected Utilities for Future Implementation

### A. Screen QR Code Decoder (`qr-scan`)
* **Source:** `omarchy-capture-qr`
* **Purpose:** Select any region on screen with `slurp` to scan and decode a QR code (such as 2FA secret setups, web links, or device pairings) and copy the result directly to the system clipboard without pulling out a phone.
* **Pipeline:** `slurp` -> `grim` -> `zbarimg` -> `wl-copy --sensitive`
* **Dependencies:** `zbar` (official Arch repo, lightweight library).
* **Footprint:** Ephemeral; exits immediately (< 0.2s runtime, 0 MB idle RAM).

### B. Screen Text OCR Grabber (`ocr-grab`)
* **Source:** `omarchy-capture-text`
* **Purpose:** Select any region containing unselectable text (error modals, gameplay UI, images, video subtitles) and extract text straight to the clipboard.
* **Pipeline:** `slurp` -> `grim` -> `tesseract` -> `wl-copy`
* **Dependencies:** `tesseract`, `tesseract-data-eng`.
* **Footprint:** Zero background daemons.

### C. Active Wi-Fi Sharing via Terminal QR (`wifi-qr`)
* **Source:** `omarchy-network-qr`
* **Purpose:** Extracts current NetworkManager Wi-Fi credentials via `nmcli` and renders a scannable ASCII QR code in your terminal. Friends can point their phones at your screen to connect instantly.
* **Pipeline:** `nmcli` -> string escape -> `qrencode --type ASCII`
* **Dependencies:** `qrencode` (already commonly installed).
* **Footprint:** Pure Bash script, zero daemon overhead.

### D. Direct I/O NVMe Benchmark (`disk-benchmark`)
* **Source:** `omarchy-disk-speedtest`
* **Purpose:** Measures real NVMe sequential read and write speeds.
* **Features:**
  - Uses `O_DIRECT` and sets `chattr +C` on temporary test chunks on Btrfs, ensuring filesystem compression and page cache do not skew real throughput measurements.
  - Samples kernel block device I/O counters directly from `/sys/class/block/*/stat`.
  - Automatically cleans up all test chunks on exit.
* **Dependencies:** Coreutils (`dd`, `awk`, `findmnt`).

---

## 2. Already Adopted & Verified Tools (Installed)

| Tool | Location | Function |
| :--- | :--- | :--- |
| **`antigravity-accounts`** | `~/.local/bin/antigravity-accounts` | Multi-profile account switcher for Antigravity with secure `keyring` storage, token validation, and quota checks. |
| **`btrfs-stats`** | `~/.local/bin/btrfs-stats` | Atomic `compsize -x` analyzer showing exact uncompressed vs compressed disk usage and GBs saved on Btrfs. |
| **`btrfs-enospc-rescue`** | `~/.local/bin/btrfs-enospc-rescue` | Loop-device recovery automation for Btrfs metadata exhaustion deadlocks. |
| **`screenshot-region`** | `~/.local/bin/screenshot-region` | Screenshot tool with atomic `flock` (prevents hotkey spam) and Wayland frame freeze before `slurp`. |

---

## 3. Discarded Components (Anti-Bloat Policy)

* **Distribution Package Managers / Agents (`omarchy-agent-*`):** Specific to Omarchy's remote channel deployments; redundant on rolling CachyOS.
* **Gaming Runners (`dusky/gaming/runner`):** Heavyweight overlayfs/container setups; direct Steam + `prime-run` / `gamemoderun` is cleaner and faster.
* **GPU ACPI Disablers (`gpu_disable_toggle.py`):** Conflicts with hybrid laptop workflow (Optimus RTX 5050 Mobile runtime D3cold offloading).
* **Background daemons (`screentime`, `keylogger`, `wayclick`):** Continuous CPU cycle drain with no operational benefit.

---

## 4. Storage & Partitioning: Linux Btrfs Expansion (150 GB → 210+ GB)

### Objective
Expand the primary Linux Btrfs root partition (`/dev/nvme0n1p6`, currently 150 GiB) to **210 GiB – 250 GiB** by taking unallocated space from the 682 GiB NTFS Games drive (`/dev/nvme0n1p5`).

### Current Partition Layout (`/dev/nvme0n1`)
* `nvme0n1p1` — EFI System (FAT32, 2.0 GiB)
* `nvme0n1p3` — Windows C: (NTFS, 120 GiB)
* `nvme0n1p5` — Games Partition (NTFS, 682 GiB, ~266 GiB free)  `[Source of space]`
* `nvme0n1p6` — Linux Root (Btrfs, 150 GiB, ~115 GiB free)      `[Target to expand]`

### Execution Strategy (Offline via CachyOS Live USB)
Because `nvme0n1p6` starts immediately where `nvme0n1p5` ends, expanding Partition 6 requires moving its beginning boundary to the left. This cannot be done on a mounted live root filesystem and must be performed from a live installer environment.

1. **Safety Pre-check:** Ensure fresh Snapper baseline snapshots exist (`#530` / `#8`) before booting live media.
2. **Boot Live USB:** Boot into the CachyOS Live USB environment (UEFI).
3. **Shrink Games Drive (`nvme0n1p5`):**
   * Open **GParted** (`sudo gparted`).
   * Select `/dev/nvme0n1p5` -> **Resize/Move**.
   * Shrink by **60 GiB** (or 100 GiB) from the end (right side), creating 60+ GiB of unallocated space between Partition 5 and Partition 6.
4. **Grow Linux Partition (`nvme0n1p6`):**
   * Select `/dev/nvme0n1p6` -> **Resize/Move**.
   * Expand the left boundary into the preceding unallocated space to occupy the full contiguous region (bringing size to 210–250 GiB).
5. **Apply Operations:** Click **Apply All Operations**.
6. **Reboot & Verify:**
   * Reboot back into installed CachyOS.
   * Verify online expansion: `sudo btrfs filesystem resize max /` and `df -hT /`.

