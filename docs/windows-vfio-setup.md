# Windows 10 VFIO & Virtualization Infrastructure — Comprehensive Report & Retrospective

**Target Machine:** ASUS TUF Gaming F16 (FX608JH)  
**Host Environment:** CachyOS rolling (Linux 7.2.7-1-cachyos) · Sway 1.12 / wlroots 0.20 (Wayland @ 1920x1200 165Hz, Intel UHD iGPU)  
**Target dGPU:** NVIDIA GeForce RTX 5050 Laptop GPU (Blackwell GB207M [10de:2dd8])  
**Target Audio:** NVIDIA GB207 High Definition Audio Controller ([10de:22ec])  
**Baseline Snapshot:** Snapper Root `#631` (`pre-vfio-toolchain-install`)  
**Date:** September 2026

---

## 1. Executive Summary & Goals

The objective of this engineering initiative was to achieve a **dynamic, hot-swappable dual-GPU passthrough architecture** without rebooting, logging out, or restarting the host Sway Wayland compositor:
* **Linux State:** Intel iGPU drives the display panel (`eDP-1`). The RTX 5050 Mobile dGPU is managed by the host proprietary `nvidia` driver and stays in D3cold runtime suspend, dynamically available on-demand for CUDA, Blender, Linux gaming (`prime-run`), or rendering.
* **Windows VM State:** The dGPU and its paired HD audio controller unbind cleanly from host drivers (`nvidia` and `snd_hda_intel`), bind to `vfio-pci`, and pass through to a Windows 10 QEMU/KVM virtual machine.
* **Return State:** Upon VM shutdown, the GPU/audio devices detach from `vfio-pci` and seamlessly rebind to the host drivers, restoring full Linux PRIME functionality.

---

## 2. What Was Tried, What Worked, & What Didn't

### What Worked (100% Success)

1. **Virtualization Toolchain & Environment:**
   * Installed `qemu-desktop`, `qemu-system-x86`, `qemu-img` (11.1.1), `libvirt` (12.7.0), `virt-manager`, `virt-viewer`, `edk2-ovmf`, `swtpm`, and `libvirt-python`.
   * Activated `libvirtd.socket`, `virtlogd.socket`, and the default NAT network bridge (`virbr0`, `192.168.122.0/24`).
   * Configured user permissions (`libvirt` group + polkit) and filesystem ACL (`setfacl -m u:libvirt-qemu:rx /home/manisk`) so QEMU can read install media safely.

2. **Windows 10 Guest Provisioning & Driver Integration:**
   * Disk created at `/mnt/Games/Others/windows10.qcow2` (64 GiB, `preallocation=metadata`) on the NTFS3 partition.
   * VM `windows10-vfio` created with Q35, UEFI (`OVMF_CODE.4m.fd` + private NVRAM), TPM 2.0 emulator (`swtpm`), 8 vCPUs (`host-passthrough`), and 8 GiB RAM.
   * Installed Windows 10 IoT Enterprise LTSC 2021 and Fedora upstream VirtIO drivers (`viostor`, `NetKVM`, `balloon`, `qemu-guest-agent`).
   * Guest reached a pristine state: clean Device Manager with zero missing drivers, static IP acquisition on `virbr0`, and clean ACPI shutdown/reboot behavior.

3. **Client App Guardrails (Intel iGPU Isolation):**
   * Identified that Chromium/Brave browsers probe `/dev/nvidiactl` and `/dev/dri/renderD129` when launched under standard environment variables.
   * Implemented wrapper guardrails setting `__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json`, `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/intel_icd.x86_64.json`, and `--render-node-override=/dev/dri/renderD128`.
   * **Result:** Brave ran natively on the Intel iGPU with zero open NVIDIA file descriptors.

---

### What Encountered Bottlenecks & What Didn't Work

1. **Direct Sysfs PCI Driver Unbind with Loaded NVIDIA Drivers (Failed):**
   * **Attempted:** Writing PCI address `0000:01:00.0` to `/sys/bus/pci/devices/0000:01:00.0/driver/unbind` while the `nvidia` kernel module was still loaded.
   * **Result:** The unbind hung indefinitely in kernel space (`os_delay` inside `nv_pci_remove_helper`), triggering `NVRM: Attempting to remove device 0000:01:00.0 with non-zero usage count!`. This locked the kernel PCI bus `device_lock` mutex, freezing any subsequent bind/unbind operations until a hard system reboot.
   * **Root Cause:** Proprietary NVIDIA drivers (`nvidia_drm` -> `nvidia_modeset` -> `nvidia`) strictly require the kernel module stack to be unloaded before removing/unbinding the PCI device.

2. **Daemon Locking (`nvidia-powerd`):**
   * The `nvidia-powerd.service` daemon actively holds open `/dev/nvidia0` and `/dev/nvidiactl` to manage dynamic boost power profiles on mobile RTX GPUs.
   * **Fix:** `nvidia-powerd` must be explicitly stopped (`systemctl stop nvidia-powerd`) before module unloads and restarted after re-attachment.

3. **Sway / wlroots EGL Device Enumeration (Core Hot-Swap Architectural Blocker):**
   * **Problem:** Even when `WLR_DRM_DEVICES=/dev/dri/card1` is configured, Sway 1.12 (`libwlroots-0.20.so`) links against `libEGL.so.1` (GLVND). During compositor initialization, GLVND executes `eglQueryDevicesEXT` (`EGL_EXT_device_enumeration`), which queries every provider in `/usr/share/glvnd/egl_vendor.d/` (`10_nvidia.json` and `50_mesa.json`).
   * The NVIDIA driver (`libnvidia-eglcore.so`, `libnvidia-gpucomp.so`) opened file descriptors to `/dev/nvidia0`, `/dev/nvidiactl`, and `/dev/dri/renderD129` (FDs 13-17, 19 in PID 1005).
   * Because wlroots holds these descriptors for its entire process lifetime, `modprobe -r nvidia` fails with `Module nvidia is in use`.
   * **Solution Researched & Validated:** Launching Sway with `__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json` restricts wlroots EGL discovery exclusively to Mesa/Intel, completely eliminating NVIDIA FDs from the compositor. However, applying this to Sway requires restarting the desktop session.

---

## 3. Inventory of Changes Made

### A. System Packages (Pacman)
* `qemu-desktop` (11.1.1-4)
* `qemu-system-x86` (11.1.1-4)
* `qemu-img` (11.1.1-4)
* `libvirt` (1:12.7.0-1.1)
* `virt-manager` (5.1.0-4)
* `virt-viewer` (11.0-4.1)
* `edk2-ovmf` (202608-1)
* `swtpm` (0.10.2-1.1)
* `libvirt-python` (1:12.7.0-1.1)

### B. System Configuration & Privileged Files
1. **`/etc/sudoers.d/99-vfio-gpu-helpers`**:
   Allowed user `manisk` passwordless execution of `/usr/local/bin/vfio-gpu-bind` and `/usr/local/bin/vfio-gpu-unbind`.
2. **`/usr/local/bin/vfio-gpu-bind`**:
   Privileged script to verify handles, stop `nvidia-powerd`, unload `nvidia_*` modules, set `driver_override=vfio-pci`, and bind IOMMU group 14.
3. **`/usr/local/bin/vfio-gpu-unbind`**:
   Privileged script to unbind from `vfio-pci`, reload `nvidia_*` modules, rebind to host drivers, and restart `nvidia-powerd`.
4. **Systemd & Polkit:**
   * `libvirtd.socket`, `virtlogd.socket`, and libvirt `default` network enabled.
   * User `manisk` added to `libvirt` group.
   * ACL set on `/home/manisk` (`u:libvirt-qemu:rx`).

### C. User Scripts & Configurations
1. **`~/.local/bin/windows-vm-start`**: Wrapper for pre-flight, GPU bind, hostdev attachment, and domain start.
2. **`~/.local/bin/windows-vm-stop`**: Wrapper for ACPI shutdown, hostdev detach, and GPU unbind/verification.
3. **`~/.local/bin/windows-vm-status`**: Comprehensive diagnostic status viewer.
4. **`~/.config/libvirt/hostdevs/rtx5050-gpu.xml` & `rtx5050-audio.xml`**: Libvirt hostdev templates (`managed='no'`).
5. **`~/.local/bin/brave-igpu` & `~/.local/bin/firefox-igpu`**: Browser wrappers restricting execution to Intel Mesa.

### D. VM Disk & Media Storage
1. **`/mnt/Games/Others/windows10.qcow2`**: 64 GiB QCOW2 virtual disk.
2. **`/mnt/Games/Others`**: Directory on NTFS3 partition.
3. **`/home/manisk/.local/share/libvirt/images/virtio-win.iso`**: VirtIO driver ISO (837 MiB).
4. **`/var/lib/libvirt/qemu/nvram/windows10-vfio_VARS.fd`**: Private UEFI NVRAM vars file.

---

## 4. Teardown & Clean Reversion Steps

To return the host to its exact pre-virtualization baseline:

1. **Undefine and Destroy Virtual Machine:**
   ```bash
   virsh -c qemu:///system undefine windows10-vfio --nvram --keep-nvram=false
   ```
2. **Stop and Disable Libvirt Daemons & Networks:**
   ```bash
   sudo systemctl stop libvirtd.service libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket virtlogd.socket virtlogd-admin.socket virtlockd.socket
   sudo systemctl disable libvirtd.socket virtlogd.socket
   virsh -c qemu:///system net-destroy default
   virsh -c qemu:///system net-autostart default --disable
   ```
3. **Delete Virtual Disks and Storage Media:**
   ```bash
   rm -f /mnt/Games/Others/windows10.qcow2
   rmdir /mnt/Games/Others
   rm -rf /home/manisk/.local/share/libvirt
   ```
4. **Remove Automation Scripts & Configurations:**
   ```bash
   sudo rm -f /usr/local/bin/vfio-gpu-bind /usr/local/bin/vfio-gpu-unbind
   sudo rm -f /etc/sudoers.d/99-vfio-gpu-helpers
   rm -f ~/.local/bin/windows-vm-start ~/.local/bin/windows-vm-stop ~/.local/bin/windows-vm-status
   rm -rf ~/.config/libvirt
   rm -f ~/.local/bin/brave-igpu ~/.local/bin/firefox-igpu
   ```
5. **Revert Browser Changes & Home ACLs:**
   * Restore `~/.local/bin/brave-origin` to chezmoi tracking.
   * `setfacl -x u:libvirt-qemu /home/manisk`
   * Remove `manisk` from `libvirt` group: `sudo gpasswd -d manisk libvirt`.
6. **Remove Virtualization Packages:**
   ```bash
   sudo pacman -Rsun qemu-desktop qemu-system-x86 qemu-img libvirt virt-manager virt-viewer edk2-ovmf swtpm libvirt-python
   ```

---

## 5. Blueprint for Future Hot-Swappable VFIO Implementation

Should hot-swappable VFIO be revisited on this machine, implement the following verified architecture:

1. **Compositor Startup Invariant:**
   In `~/.local/bin/sway-run`, restrict Sway EGL initialization to Mesa before starting Sway:
   ```bash
   export WLR_DRM_DEVICES=/dev/dri/card1
   export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
   exec sway "$@"
   ```
   *In Sway's startup configuration (`~/.config/sway/config`), unset `__EGL_VENDOR_LIBRARY_FILENAMES` for spawned desktop applications, or let `prime-run` explicitly provide `10_nvidia.json` so host CUDA/games are completely unaffected.*

2. **Automate Daemon Pausing in Helper:**
   Ensure `vfio-gpu-bind` executes `systemctl stop nvidia-powerd` before `modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia`, and `systemctl start nvidia-powerd` upon unbind.

3. **Hook-Based or Wrapper-Based Attachment:**
   Keep PCI `0000:01:00.0` and `0000:01:00.1` defined as `managed='no'` hostdevs so libvirt never attempts default sysfs unbinds, leaving full control to the module-safe helpers.
