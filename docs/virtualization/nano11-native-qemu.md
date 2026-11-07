# Nano11 native QEMU/KVM, Intel SR-IOV and Looking Glass

**Current implementation:** 2026-11-05. **Source of truth:** this chezmoi repository, primarily `dot_local/bin/executable_nano11`. Read `AGENTS.md`, `docs/system/SYSTEM_CONTEXT.md`, `docs/system/system-philosophy.md`, and the virtualization entry in `docs/system/SUBSYSTEM_MAP.md` before modifying the workstation. For the historical Dockur-based implementation and its signed Intel driver/IDD repair, see [dockur-windows.md](dockur-windows.md) and the archived sections of [nano11-recovery-runbook.md](nano11-recovery-runbook.md).

## Goal and why it changed

On-demand Windows desktop with the laptop's Intel virtual GPU and native Looking Glass, with **no Dockur container, Podman networking, Docker service, libvirt daemon or unattended container startup**. QEMU is a real KVM VM in a transient systemd **system** unit running as the unprivileged login user. The unit exists only while the guest runs. Sway and NVIDIA RTX 5050 remain on Linux. Do not detach the NVIDIA GPU.

Historical Dockur startup ran `vulkaninfo` on the Intel PF and produced confirmed i915 GPU hangs/context resets. The direct QEMU path uses **non-GL `virtio-vga` only for a fallback display**, avoids Vulkan discovery entirely, and uses Intel SR-IOV for Windows graphics acceleration. Native KVM/QEMU was already doing the virtualization inside Dockur; this migration removes the wrapper and helpers, not KVM itself. After the successful native recovery/Looking Glass tests, the obsolete Dockur container, its 708 MB image, the unused Alpine image, Podman and its orphaned dependency packages, and Podman's lingering rootless pause process/storage were all removed. No Docker/Podman runtime is installed or active.

## Current architecture

```text
ASUS TUF F16, CachyOS, Sway, NVIDIA AsusMuxDgpu
  NVIDIA RTX 5050 0000:01:00.0 -> Linux/Sway 1920x1200 165 Hz
  Intel PF 0000:00:02.0 -> host i915-sriov-dkms (no physical passthrough)
    VF 0000:00:02.1 -> vfio-pci, isolated IOMMU group (was 24 on 2026-11-05)
      |
      +-- ephemeral systemd-run nano11-qemu.service (User=login user)
          |-- qemu-system-x86_64 11.1.3 / KVM / q35 / 12 vCPU / 4 GiB
          |-- original secure OVMF .rom + .vars + swtpm TPM2 state
          |-- existing VirtIO-SCSI qcow2, network NIC with stable MAC
          |-- non-GL virtio-vga recovery display (no Intel Vulkan probe)
          |-- Intel VF via vfio-pci,host=0000:00:02.1,rombar=0
          |-- 64 MiB /dev/kvmfr0 ivshmem-plain (Looking Glass LGMP)
          |-- localhost RDP 127.0.0.1:3389 (QEMU user-mode TCP/UDP forwarding)
          |-- SPICE unix:$XDG_RUNTIME_DIR/nano11-spice/spice.sock
          |-- SPICE audio; LGMP keyboard/mouse/clipboard
          +-- swtpm (runs only for VM lifetime)

Windows Nano11, installed Intel driver 32.0.101.7092, matching LG IDD B7-829
  Looking Glass IDD -> hardware Intel D3D -> KVMFR -> Linux LG client on Sway
```

The QEMU unit is launched using `sudo -n systemd-run --unit=nano11-qemu --collect --no-block` but with `User=$(id -un)`, `Group=$(id -gn)`, `SupplementaryGroups=video`, `LimitMEMLOCK=infinity`. Root initiates the transient unit; QEMU, TPM and user data remain owned by the ordinary user. This was necessary because Remote Desktop Commander's `desktop-commander.service` cgroup has `memory.max=1610612736` (1.5 GiB): a directly spawned QEMU inherited that cgroup and was twice killed by the kernel OOM killer. **Do not start QEMU inside that helper's cgroup.**

The transient unit is collected after exit; it is not enabled at boot. The launcher uses `flock` to serialize start/stop, verifies disk ownership and the actual QEMU process instead of trusting only a PID file, and asks Windows to shut down via an ACPI monitor event. A timeout does **not** forcibly kill Windows.

## Data and original Windows state

VM root is intentionally still at `/mnt/Games/VirtualMachines/dockur-nano11/`. **The folder name is historical, not a runtime Dockur dependency.** Renaming it adds risk and gains no disk space or CPU efficiency.

- `storage/data.qcow2`: original installed Windows 11 Pro/Nano11, 64 GiB virtual, ~14.4 GiB occupied when migrated, NTFS3-hosted.
- `storage/windows_secure.rom`: **existing OVMF firmware**, not replaced by host package firmware.
- `storage/windows_secure.vars`: **existing UEFI NVRAM**; must not regenerate.
- `storage/windows_secure.tpm`: **existing TPM2 state**; must not initialize anew.
- `storage/windows.mac`: original VirtIO NIC MAC `02:14:C5:52:40:35`, retained.
- `media/nano11-25h2.iso`: existing custom installation media; not required during normal direct QEMU boot.
- `shared/`: guest setup files/audit evidence. QEMU's direct launch does not expose Dockur's old SMB share; when required, use RDP's `/drive:shared` or add an explicitly reviewed sharing device. On 2026-11-05 the unused 900 MiB `intel-driver.img` and duplicate 745 MiB `gfx.exe` were deleted after confirming they were not attached to native QEMU. The original Intel 32.0.101.7092 driver installer is retained as `shared/gfx_win_101.7092.exe` (780,899,944 bytes, SHA256 `9643cc60a899ceadf65df2ec80c17cdb69daeb41cdb2c9ccde0d214a79f968f8`). The shared directory shrank from ~2.4 GiB to ~803 MiB; other audit evidence was retained.
- **Pre-migration snapshot copy:** `/mnt/Games/VirtualMachines/nano11-backup-20261105/` includes the QCOW2, OVMF, TPM, and metadata; at backup time QCOW2 SHA-256 matched source: `c93597842cc5ae60071a3ec433099e0d02195f2afa854bab32223b7b887b1385`. This is a separate copy **on the same physical Games partition**, not an off-machine disaster backup. Never run QEMU on both copies simultaneously with the same PCI VF.

The original Dockur launcher (including container creation arguments) is archived at:
`~/.local/state/nano11-direct-qemu-20261105/launcher-chezmoi-before`.
The original live launcher is `launcher-installed-before`; previous Podman/QEMU parameters and a Docker entrypoint copy are in the same directory. These local files are **not** a substitute for repository source or a disk backup.

## Commands and shortcuts

```sh
nano11 status             # QEMU PID and local endpoints, no start
nano11 start              # prepare Intel SR-IOV VF; start transient QEMU if needed
nano11 workspace          # Alt+W: start/reuse and present Looking Glass on Sway workspace 10
nano11 launch             # first actual LGMP frame required; RDP fallback
nano11 glass              # explicit Looking Glass diagnostic
nano11 rdp                # loopback RDP recovery (FreeRDP)
nano11 open               # alias for RDP recovery; NOT a Dockur web page
nano11 here               # move existing Windows surface to focused workspace
nano11 logs               # tail native ~/.local/state/nano11/qemu.log
nano11 stop               # ACPI Windows shutdown; no unconditional SIGKILL
nano11 restart            # graceful stop, then start
```

Alt+Shift+W is the Windows management menu; Right Ctrl releases Looking Glass input capture; desktop entry `Windows (Nano11)` uses the same launcher. Main files:

- `dot_local/bin/executable_nano11` -> `~/.local/bin/nano11`
- `dot_local/bin/executable_rofi-windows` -> `~/.local/bin/rofi-windows`
- `dot_config/fish/functions/nano11.fish` -> `~/.config/fish/functions/nano11.fish`
- `dot_local/share/applications/nano11.desktop` -> user desktop entry
- existing Sway rules and keybindings in `dot_config/sway/config.d/`
- `run_onchange_linux-35-setup-looking-glass-kvmfr.sh.tmpl` (KVMFR module and udev)
- `dot_local/share/nano11/Configure-Guest.ps1` for Windows guest IDD

The generic `looking-glass` client and system-wide `looking-glass` Arch build are not automatically interchangeable with the **matched** `~/.local/bin/looking-glass-client-idd` client. Do not upgrade one side independently.

## Verified acceptance, 2026-11-05

1. Original Dockur VM was cold-started just long enough to capture its **actual** `qemu-system-x86_64` argument array, then shut down via guest ACPI. Before migration its localhost RDP handshake worked.
2. Stopped disk backup completed; SHA-256 of both QCOW2 copies matched. `qemu-img check -q -f qcow2` reported no corruption after the native run.
3. Native QEMU 11.1.3, minimal SPICE/virtio modules, OVMF and `swtpm` installed from distro repositories. Missing Arch package `qemu-hw-display-virtio-gpu` made `virtio-vga` crash: diskless `-S` test reproduced SIGSEGV; adding the core module made the same test survive until deliberate timeout. No hardware defect was inferred.
4. Direct native QEMU successfully booted Windows and answered RDP's TPKT/X.224 handshake on **127.0.0.1:3389**. TCP port **8006 no longer exists**. SPICE socket is active; Podman had no running containers.
5. A 2026-11-05 non-capturing, non-fullscreen Looking Glass smoke test received **actual** `main_frameThread | Format: FRAME_TYPE_BGRA 1920x1200` video, plus `Using Input: LGMP`, `Using Clipboard: LGMP` and `Using Audio: SPICE`. Audio/device/clipboard channels negotiated, but guest typing, bidirectional transfer and audible playback were **not** retested in this migration. Prior audit documented those in the Dockur baseline.
6. Repeated `nano11 start` reused the existing PID; a `nano11 stop` shut Windows down cleanly in ~5 seconds; systemd transient unit disappeared and original disk was released. An additional launch from the installed launcher was verified, with no Podman runtime.
7. No post-native-start Intel PF `vulkaninfo` GPU hang appeared in the checked journal period. This does not establish long-term i915 stability or 165 UPS performance.
8. After **fully uninstalling Podman**, its 10 dependencies, the unused QEMU EGL/GL plugin packages, and clearing rootless Podman metadata, `nano11 stop` shut Windows down cleanly, and a fresh `nano11 start` booted it as native QEMU PID 122683. Guest RDP X.224 answered, actual `FRAME_TYPE_BGRA 1920x1200` Looking Glass video arrived, and input/clipboard LGMP plus SPICE audio connected. Native QEMU remained running with its VF on `vfio-pci`. No Docker container or pause process was required.

Historical validated guest driver/IDD details still live in [dockur-windows.md](dockur-windows.md), but its Podman container instructions are **obsolete for current operations**.

## Fault recovery (inspect, do not blindly rebuild)

```sh
nano11 status
sudo systemctl status nano11-qemu.service --no-pager
sudo journalctl -u nano11-qemu.service --no-pager -n 100
tail -100 ~/.local/state/nano11/qemu.log
stat /mnt/Games/VirtualMachines/dockur-nano11/storage/data.qcow2
lspci -nnk -s 00:02.0 -s 00:02.1
ls -l /dev/kvm /dev/kvmfr0 /dev/vfio/vfio
ls -l "$XDG_RUNTIME_DIR"/nano11-spice/spice.sock
ss -lntp | grep 3389
```

- If `nano11 start` reports Intel VF missing: verify `/sys/bus/pci/devices/0000:00:02.0/sriov_numvfs`, patch/module compatibility, vfio driver binding, and the entire VF IOMMU group. Never bind the Intel PF or NVIDIA host GPU to vfio.
- If `nano11 start` reports missing KVMFR: check the managed hook and the actual **64 MiB** allocation before restarting; **32 MiB breaks the 1920x1200 IDD mode**.
- If the VM is running but no LGMP frame arrives: try `nano11 rdp`, check Windows Intel driver error Code 0, IDD monitor/session/indirect-copy settings, and the matching B7-829 client/IDD. The launcher falls back only after its first-frame readiness window.
- If QEMU fails initializing `virtio-vga`: verify both `qemu-hw-display-virtio-vga` and `qemu-hw-display-virtio-gpu`; a missing core plugin caused SIGSEGV in this exact migration. Check `coredumpctl` before modifying other devices.
- If QEMU disappears early with cgroup OOM logs: do not launch it from `desktop-commander.service`; the native launcher uses a transient systemd system unit. Diagnose host memory exhaustion separately.
- If the RDP port fails: check QEMU user-mode `hostfwd` (TCP and UDP 3389 bound to **127.0.0.1 only**), guest RDP service, and Windows firewall. No Dockur `passt` or web forwarding exists.
- If Windows reports BitLocker/TPM recovery: verify the **original** matching `.rom`, `.vars` and `.tpm` state. Do not create new Windows machine identity or clear TPM.
- Never expose unauthenticated/blank-password guest RDP to a public or LAN IP.

## Rollback and destructive operations

Before changing the VM state, use `nano11 stop`; verify no process holds `data.qcow2`. To revert a **configuration** change, restore the saved source launcher then restore its live copy, but note that the old launcher needs Podman and its Dockur image reinstalled. Restoring the old source alone after Podman removal will not start Windows. The direct launcher is the current supported baseline.

If Windows state is corrupt, restore `data.qcow2`, `windows_secure.rom`, `windows_secure.vars`, `windows_secure.tpm` **together** from a consistent stopped backup. Avoid touching `/mnt/Games/VirtualMachines/nano11-backup-20261105/` during routine cleanup. Always verify a complete backup and check `qemu-img check` when the image is stopped.

No automatic boot service, NVIDIA handoff, libvirt network, Docker daemon, or background Podman process is installed solely for Nano11. The obsolete Podman container and images were removed **after** native VM boot/Looking Glass validation. All bind-mounted `storage/`, `media/`, and necessary `shared/` files were preserved. The historical Dockur root directory name remains to avoid unnecessary filesystem churn.

## Current limitations

- Native recovery is RDP-based; Dockur's browser/noVNC UI is gone. A separate lightweight QEMU VNC socket could be added if RDP and Windows both fail, but it has not been implemented.
- Disk is on NTFS3 mounted at `/mnt/Games`; preserve `cache=none,aio=native` unless verified otherwise.
- This migration does not modify Windows services, apps, telemetry, or power tuning, and does not independently measure sustained guest 165 UPS, input latency, or audible audio quality.
- `qemu-system-x86_64` is running as a regular user under a systemd transient **system** unit, rather than a root VM process or a persistent systemd service. Restart verification after a full host reboot remains outstanding.
