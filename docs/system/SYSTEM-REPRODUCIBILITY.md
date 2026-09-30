# System Reproducibility & Provisioning Guide

This document specifies the exact environment requirements, hardware assumptions, storage layout, package reconciliation pipeline, and recovery procedures required to reproduce this system deterministically from a fresh Arch Linux / CachyOS installation.

---

## 1. Target Hardware & Kernel Specifications

The primary profile (`asus-tuf-f16`) targets the following hardware configuration:

* **Chassis / Model:** ASUS TUF Gaming F16 (FX608J)
* **Processor (CPU):** Intel Core i5-13450HX (6 Performance cores / 12 threads + 4 Efficient cores / 4 threads = 16 total threads)
  - Launch scripts isolate latency-critical titles (e.g. CS2) specifically to P-cores 0–11 via `taskset -c 0-11`.
* **Integrated GPU (iGPU):** Intel Raptor Lake-S UHD Graphics (`LIBVA_DRIVER_NAME=iHD`, `intel-media-driver`, `vulkan-intel`)
* **Discrete GPU (dGPU):** NVIDIA GeForce RTX 5050 Mobile (GB207M Blackwell, 8GB GDDR6, `nvidia-open-dkms`)
* **Display Panel:** Internal eDP-1 1920×1200 @ 165Hz (native aspect ratio 16:10, adaptive sync / VRR enabled, tearing allowed for reduced input latency)
* **Operating System:** CachyOS rolling (x86-64-v3, BORE scheduler) or vanilla Arch Linux

---

## 2. Storage & Filesystem Architecture

### A. Root & Home Layout (Btrfs)
* Root (`/`) and home (`/home`) reside on high-speed NVMe storage formatted as **Btrfs**.
* Periodic TRIM is active via `fstrim.timer`.
* Btrfs periodic snapshot cleanup is handled via `snapper-cleanup.timer`.

### B. Machine-Specific Invariant: `/mnt/Games`
* **Non-negotiable machine requirement:** Dedicated secondary drive/partition mounted at `/mnt/Games` formatted as Btrfs.
* **Distinction:**
  - **Required for this specific gaming machine:** Paths in launcher scripts (`eldenring-run`, `cs2-launch`, Steam libraries) assume `/mnt/Games/SteamLibrary`.
  - **NOT required for chezmoi itself:** Chezmoi dotfile management operates independently of `/mnt/Games`, but games and Proton prefixes will fail to resolve if the mount is absent.
* **No-CoW (`chattr +C`):** Steam library data and Wine prefixes (`/mnt/Games/SteamLibrary`) strictly enforce `nodatacow` attribute.
  > **Note on Btrfs CoW:** Setting `chattr +C` on an existing directory only affects newly written files. For newly created setups, verify with:
  > ```bash
  > lsattr -d /mnt/Games/SteamLibrary
  > ```
  > Do NOT recursively run `chattr +C` on existing files in a populated Btrfs filesystem without moving the data out first.

---

## 3. Filesystem & Snapshot Prerequisites (Snapper)

The chezmoi package reconciliation hook (`run_onchange_linux-00-reconcile-packages.sh.tmpl`) is designed to create a safety snapshot before modifying system packages:

```bash
sudo snapper -c root create -d "chezmoi package reconciliation" -t pre
```

### Detection vs. Automatic Creation
* **Safety Invariant:** The reconciliation hook checks whether the root Snapper configuration exists via:
  ```bash
  command -v snapper >/dev/null 2>&1 && sudo snapper list-configs 2>/dev/null | grep -qw root
  ```
  If `root` does not exist, the hook skips snapshot creation gracefully without failing the package installation.
* **Manual Setup Prerequisite (Only if Snapper was not pre-configured during OS install):**
  ```bash
  sudo snapper -c root create-config /
  sudo systemctl enable --now snapper-cleanup.timer
  ```
  Do NOT blindly run `create-config` if your distribution installer (e.g. CachyOS installer) has already created a Snapper root configuration or subvolume layout.

---

## 4. GPU Power Management & Offloading Strategy

* **Desktop Session:** Sway (Wayland) runs exclusively on the **Intel iGPU** (`intel-media-driver`). All 2D surfaces, browsers, terminals, and light desktop applications execute on the iGPU to preserve battery life and minimize thermal footprint.
* **dGPU Runtime D3cold:** The NVIDIA RTX 5050 remains in lowest power state (D3cold) with 0W consumption until explicitly invoked.
* **Explicit Prime Offload:** Applications and games offload to the NVIDIA card using `prime-run`:
  ```bash
  prime-run <command>
  # For Steam launch options:
  gamemoderun prime-run %command%
  ```
* **GOverlay Pipe Overflow Protection:**
  * GOverlay's Pascal/LCL backend overflows its internal pipe buffer when executing synchronous `lsmod` on kernels with >200 modules.
  * System uses `~/.local/bin/goverlay` wrapping `~/.local/lib/goverlay-bin/lsmod` (a filtered grep) and applying custom Qt scaling (`QT_SCALE_FACTOR=1.35`).

---

## 5. Package Reconciliation Pipeline

The repository uses declarative package lists under `packages/` managed by `run_onchange_linux-00-reconcile-packages.sh.tmpl`:

| Manifest | Purpose | Provider / Source | Feature Flag |
|---|---|---|---|
| `common.txt` | Baseline terminal utilities (`git`, `ripgrep`, `btop`, `yazi`, `neovim`, `uv`, `age`) | Official (`pacman`) | Always |
| `linux-core.txt` | Core system stack (`base-devel`, `btrfs-progs`, `snapper`, `ufw`, `bluez`, `thunar`) | Official (`pacman`) | Linux |
| `gaming.txt` | Gaming tools (`steam`, `gamescope`, `gamemode`, `mangohud`, `goverlay`) | Official (`pacman`) | `features.gaming = true` |
| `nvidia.txt` | NVIDIA utilities and 32-bit Vulkan/OpenCL drivers | Official (`pacman`) | `gpu_strategy = "hybrid-optimus-d3cold"` |
| `asus.txt` | ASUS hardware management tools (`asusctl`, `supergfxctl`) | Official (`pacman`) | `features.asus_ctl = true` |
| `sway.txt` | Sway Wayland desktop stack (`sway`, `mako`, `fuzzel`, `grim`, `slurp`, `brave-origin-bin`) | Official (`pacman` / `cachyos`) | `features.sway = true` |
| `audio.txt` | PipeWire, WirePlumber, and neural RNNoise DSP stack | Official (`pacman`) | `providers.audio = "pipewire-standard"` |
| `development.txt` | Runtimes and build accelerators (`nodejs`, `python`, `mold`, `ccache`) | Official (`pacman`) | `features.development = true` |
| `aur-explicit.txt` | Explicit foreign/AUR packages (`antigravity-cli`, `bibata-cursor`, `xremap`, `vkbasalt`, `lib32-vkbasalt`) | AUR (`paru`) | AUR helper present |

* On change to any manifest, chezmoi automatically calculates hashes, takes a pre-reconciliation Snapper snapshot if packages need installing, and executes non-conflicting package installation.

---

## 6. System & User Services

### System Daemons (Systemd)
Managed and reconciled via `run_onchange_linux-20-reconcile-services.sh.tmpl`:
* `ananicy-cpp.service`: Community rule-based auto-nice daemon for CPU process prioritization.
* `supergfxd.service` & `asusd.service`: ASUS hardware fan curves, battery charging thresholds (capped at 60%), and hybrid GPU controls.
* `bluetooth.service`: Bluetooth daemon.
* `fstrim.timer`: Weekly NVMe TRIM.
* `snapper-cleanup.timer`: Routine snapshot pruning.

### User Units (Systemd User)
* `xremap.service`: High-performance hardware keyboard remapping daemon running under user session.
* `cliphist.service`: Wayland + XWayland persistent clipboard history watcher and auto-pruner (`cliphist-prune`).
* `dusky-audio-dsp.service`: Real-time PipeWire RNNoise microphone filter and DSP studio daemon.
* `sway-session-save.service`: Sway window state persistence on session shutdown.
* `nightlight-auto.timer`: Automated wlsunset circadian color temperature shifting.

---

## 7. Cold-Start Provisioning Procedure (Step-by-Step)

To bootstrap a new machine identically from bare metal:

### Step 1: Base System Installation & Drive Mounts
1. Install CachyOS or Arch Linux using Btrfs filesystem.
2. Ensure `/mnt/Games` is formatted with Btrfs, configured with `chattr +C`, and mounted in `/etc/fstab`.
3. Configure user `manisk` (or adjust machine profile in `chezmoi.toml`).

### Step 2: Secret Key Setup (age)
The age private key is an **external secret prerequisite** that MUST NEVER be committed to Git or stored in plaintext in the repository.

1. Install age if not present: `sudo pacman -S --needed age`
2. Securely provision your private age key from an external vault / secure backup:
   ```bash
   mkdir -p ~/.config/chezmoi
   # Copy private key to ~/.config/chezmoi/key.txt
   chmod 600 ~/.config/chezmoi/key.txt
   ```
3. Verify that the key exists before running chezmoi apply.

### Step 3: Run Bootstrap Script
```bash
curl -sL https://raw.githubusercontent.com/kmanisk/tufdots/master/install.sh | bash -s -- --apply
```

The bootstrap script will:
1. Verify system is Arch/CachyOS.
2. Install `git` and `base-devel`.
3. Build and install `paru`.
4. Install `chezmoi` and `age`.
5. Pre-seed `~/.config/chezmoi/chezmoi.toml` with `asus-tuf-f16` and age encryption parameters.
6. Verify that `~/.config/chezmoi/key.txt` exists before triggering `chezmoi init --apply`. If missing, it halts with a clear error prompt rather than crashing on decrypt.
7. Execute package reconciliation (`pacman` for official, `paru` for AUR).
8. Enable required system and user services.

### Step 4: Verification
Verify that the deployed configuration matches the repository perfectly:
```bash
chezmoi status
# Expected: empty (0 file drift)

chezmoi verify
# Expected: exit code 0

sway -c ~/.config/sway/config -C
# Expected: exit code 0 (valid syntax)
```
