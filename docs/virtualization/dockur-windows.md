# Dockur Nano11 Windows Lab

**Historical Dockur baseline (2026-11-03), superseded on 2026-11-05.** The active Nano11 VM now uses native QEMU/KVM with an on-demand transient systemd unit and no Podman/Dockur runtime; start with [nano11-native-qemu.md](nano11-native-qemu.md). This file retains the original signed Intel VF driver, IDD repair, LGMP validation and Dockur rollback evidence. [nano11-recovery-runbook.md](nano11-recovery-runbook.md) is also an archived Dockur-era reference; do not apply its Podman commands to the current installation.

## Verified state: 2026-11-03

Nano11 now presents a live Windows desktop through Looking Glass on Sway workspace 10, with Intel VF hardware graphics. This replaces the earlier nonfunctional LGMP and RDP-only baselines.

| Component | Verified implementation |
| --- | --- |
| Host | CachyOS 7.3.1-1-cachyos, Sway, AsusMuxDgpu |
| Linux display | RTX 5050 on NVIDIA; eDP-1 1920x1200 at 165.004 Hz, scale 1.30 |
| Intel PF | 0000:00:02.0, i915-sriov-dkms 2026.10.28-1 |
| Intel VF | 0000:00:02.1, vfio-pci, isolated IOMMU group 24 |
| Guest | Nano11 Windows 11 Pro build 26200, rootless Podman, KVM, 12 vCPUs, 4 GiB RAM |
| Storage | Persistent 64 GiB QCOW2 under `/mnt/Games/VirtualMachines/dockur-nano11/storage/` |
| Guest Intel driver | Signed Intel 32.0.101.7092, oem16.inf, igfxn, device error code 0 after reboot |
| Direct3D | Explicit D3D11 hardware device creation succeeded, feature level 11.0, adapter 8086:A78B |
| Looking Glass | Matching client/IDD B7-829-cdba29f2; legacy host service disabled |
| Capture | IDD hardware mode, D3D11 acquisition and D3D12 indirect/readback copies, LGMP, KVMFR DMA on Linux |
| Shared memory | `/dev/kvmfr0`, 64 MiB; QEMU memory-backend-file also 64M |
| Guest display | IDD 1920x1200 at 165.004 Hz; 120 and 60 Hz fallback modes available |
| Input/clipboard | LGMP direct input and clipboard after native frame startup |
| Audio | SPICE playback through the client's PipeWire backend; listening/latency acceptance remains outstanding |
| Recovery | RDP TCP/UDP 127.0.0.1:3389 and web console 127.0.0.1:8006 |

Render numbering is not stable. The current boot uses Intel renderD129 and NVIDIA renderD128. The launcher resolves Intel by vendor **and PF PCI address**, then maps only its matching render/card pair. QEMU's Intel render file descriptor identifies drm-pdev 0000:00:02.0. NVIDIA render nodes are absent from the container.

The PF remains available to Linux and backs the VirtIO/Venus recovery renderer. The Windows Red Hat VirtIO DOD driver is not evidence of guest 3D acceleration. Actual guest acceleration was established separately with a D3D hardware device on Intel, WPF render tier 2, and IDD hardware/D3D12 logs. Dxdiag lists the headless Intel adapter's D3D status as unavailable even while the explicit hardware test succeeds; do not use that field alone to reject or prove acceleration.

## Confirmed failure causes and repairs

1. **Missing guest Intel driver:** the passed-through VF enumerated as Video Controller, CM_PROB_FAILED_INSTALL / Code 28. The existing gfx.exe was copied into Windows over a temporary container-internal HTTP transfer, verified by Windows Authenticode as Intel Corporation, and installed. Its INF includes PCI VEN_8086&DEV_A78B. Driver operation survived the installer's Windows reboot and a subsequent cold VM start. No signature-enforcement bypass, PF detach, MUX change, or NVIDIA handoff was used.
2. **Undersized IDD transport:** IDD opened 32 MiB IVSHMEM but filtered its only 1920x1200 mode and reported no supported modes. The matching source allocates three frame buffers, three 1 MiB cursor-shape buffers, bidirectional clipboard streams and protocol metadata. This exceeds the former allocation at 1920x1200. With both KVMFR and QEMU changed to 64 MiB, the same 165.004 Hz mode was accepted and actual LGMP frames arrived. Refresh forcing was not the repair.
3. **Intel direct-copy corruption:** the native stream showed damaged edges/partial regions. ForceFullDirectCopy=1 did not resolve it. ForceIndirectCopy=1, ForceFullDirectCopy=0 produced clean motion in the observed test while retaining Intel hardware rendering. This adds a CPU readback copy; do not describe it as direct zero-copy guest transport.
4. **Launcher failure handling:** an installed client executable was treated as availability. The launcher now requires a received transport frame, identified by this exact client's `main_frameThread | Format:` log, within a bounded startup window. On failure it closes its client and opens RDP. Connected SPICE channels and local FPS do not satisfy this check.
5. **Session ownership:** active RDP uses a separate Windows display session. The native Windows scheduled task Nano11RestoreConsole transfers this lab user's disconnected RDP session back to console on LocalSessionManager event 24. It does not steal an active RDP session. The task runs as SYSTEM and adds no polling service. The setup source includes battery-operation settings and a one-minute execution limit; live session restoration was tested on AC, and battery-specific acceptance is outstanding.

The IDD helper was already running, IVSHMEM was accessible, and client/IDD versions matched. The disabled legacy host was preserved. These were not the causes of the original unavailable source.

An audit-only `wtype` test delivered Wayland keymap format 0, which this client rejects. Restarting the client restored the compositor's normal keymap. Do not confuse that simulator limitation with physical keyboard acceptance. Subsequent native tests recorded 41 key events, 18 clicks, and typed guest text confirming successful operation. Right Ctrl displayed Capture Disabled; modifier release and host shortcut recovery were observed. Keyboard/mouse acceptance is based on guest behavior, not channel connection logs.

## Controls and lifecycle

- `Alt+W`: `nano11 workspace`, start/reuse Windows and focus workspace 10.
- `Alt+Shift+W`: Windows management menu (`rofi-windows`). This replaces the redundant wallpaper alias; wallpaper-next remains on Super+Shift+W and Super+Ctrl+W.
- `Super+Alt+W`: existing inhibited workspace recovery binding.
- `Right Ctrl`: Looking Glass capture/release. Right Ctrl+D temporarily toggles the FPS/UPS overlay.
- Application entry: **Windows (Nano11)** opens the managed desktop. The generic unconfigured Looking Glass application entry is hidden by a local desktop override.
- `nano11 rdp`: explicitly open recovery RDP. The normal managed launcher closes recovery RDP before returning to native Looking Glass; the disconnect task restores the console.
- `nano11 glass`: explicitly try native Looking Glass for diagnosis.
- `nano11 open`: web recovery console.
- `nano11 stop`: ACPI shutdown, with bounded Dockur fallback.

Closing Looking Glass leaves the VM running. Repeated managed launch focuses the existing native window. The launcher checks readiness only at startup; it is not a continuous health watchdog.

VM and presentation locks remain separate. Rootless crun exec needs the container's unlimited memlock limit too; the ACPI stop path now raises its own limit before podman exec. This prevents failure before the monitor command runs. The obsolete FAT32 intel-driver.img attachment was removed from future container definitions; the image and QCOW2 were retained.

VF creation/binding is reconciled **on demand** by the launcher after boot, not by a new resident service. Boot arguments enable SR-IOV but do not alone guarantee creation/binding. This audit exercised cold VM recreation in the current Linux boot; a new Linux reboot was not performed.

## Managed files and guest setup

- `dot_local/bin/executable_nano11`
- `dot_local/bin/executable_rofi-windows`
- `dot_local/bin/executable_rofi-cheatsheet` (matching shortcut descriptions)
- `dot_config/sway/config.d/30-window-rules.conf`
- `dot_config/sway/config.d/40-keybindings.conf`
- `dot_local/share/applications/nano11.desktop`
- `dot_local/share/applications/looking-glass-client.desktop`
- `run_onchange_linux-35-setup-looking-glass-kvmfr.sh.tmpl`
- `dot_local/share/nano11/Configure-Guest.ps1`

The guest configuration script is installed on Linux as `~/.local/share/nano11/Configure-Guest.ps1`. Copy it into Windows and run elevated **after** installing the signed Intel driver and matching IDD. It backs up the existing IDD registry under `C:\ProgramData\Nano11`, configures the modes/copy workaround, registers console restoration, and restarts only the IDD device. The audit applied this script to Windows. Intel's optional graphics UI, updater, SDK and computing-improvement package added by its installer were removed; the final service inventory retained LGIddHelper and the disabled legacy host, with no Intel telemetry/updater services.

KVMFR resizing requires Windows stopped and all Looking Glass clients closed:

```sh
nano11 stop
sudo modprobe -r kvmfr
sudo modprobe kvmfr static_size_mb=64
nano11 launch
```

The managed hook writes `/etc/modprobe.d/kvmfr.conf`, `/etc/modules-load.d/kvmfr.conf`, and `/etc/udev/rules.d/99-kvmfr.rules`. It checks the live allocation with KVMFR_DMABUF_GETSIZE and refuses an old size rather than unloading memory in use. No Linux reboot is needed for this resize.

## Verification and limits

Verified: host bindings and IOMMU isolation; Intel-only container DRM exposure; explicit Intel D3D11 hardware creation; IDD D3D12 hardware capture; 64 MiB ioctl size; live LGMP frames; clean observed indirect-copy motion; guest typing/clicks; bidirectional clipboard; capture release; loopback-only recovery ports; cold VM start; managed workspace launch; existing-window reuse; simulated failed-client RDP fallback and return to the console/native desktop.

One moving-content overlay sample measured **121.77 FPS / 119.78 UPS**. Another interval measured about 104/104. The configured guest mode is 165 Hz, but sustained 165 UPS and end-to-end input/audio latency have **not** been established. WPF CompositionTarget callback counts can exceed the display rate and must not be reported as captured FPS. A 45-second WPF test reported render tier 2 and approximately 11.2 ms p95 callback interval; this is workload-specific and is not glass-to-glass latency.

Observed cumulative host process averages during audit included roughly 15-20% of one CPU for Looking Glass and 150-166% for QEMU during the animated PowerShell/WPF workload. These include differing phases; they are not an isolated benchmark. Concurrent Linux browser video also used NVIDIA. No global GPU/power/scheduler tuning was made from these observations.

**Remaining host issue:** Dockur's Intel Vulkan capability probes triggered PF context-reset/GPU-hang messages and delayed cold startup in this boot. QEMU subsequently ran on the Intel PF and VF capture worked. The SPICE readiness budget now allows this startup, but the underlying Vulkan probe hang is not repaired. Investigate the host Intel Vulkan/i915 combination separately before claiming a clean PF stability baseline. No new driver packages/kernel changes were attempted in this repair.

A four-second 48 kHz mono 16-bit zero-PCM guest playback completed in 4.157 seconds and triggered the client's SPICE/PipeWire playback path. This validates silent routing, not audible quality or latency; no audible tone was played for acceptance. Recovery remains available if native capture later fails.

Bash syntax, ShellCheck, desktop-file validation, template rendering in an isolated source directory, Sway validation/reload, source/live parity, and focused runtime tests were performed. The repository's existing dangling `docs/projects/tele/source-sixel-README.md` reference prevents ordinary global chezmoi template discovery; targeted files were installed directly and compared. Unrelated repository content was preserved.

## Evidence and rollback

Audit backups and host evidence: `~/.local/state/nano11-audit-20261103/`. A guarded `rollback-host.sh` in that directory restores the host/source/documentation backups and refuses to overwrite later source edits. Guest rollback remains a separate elevated Windows action below. Guest diagnostics and temporary test artifacts: `/mnt/Games/VirtualMachines/dockur-nano11/shared/nano11-audit-live/`. The temporary container-internal HTTP collector and synthetic keyboard are audit tools, not required runtime services, and are stopped after collection.

Configuration-only rollback, after closing Looking Glass:

```sh
repo="$HOME/.local/share/chezmoi"
bak="$HOME/.local/state/nano11-audit-20261103"
nano11 stop
cp "$bak/executable_nano11" "$repo/dot_local/bin/executable_nano11"
install -m755 "$bak/executable_nano11" "$HOME/.local/bin/nano11"
cp "$bak/executable_rofi-windows" "$repo/dot_local/bin/executable_rofi-windows"
install -m755 "$bak/executable_rofi-windows" "$HOME/.local/bin/rofi-windows"
cp "$bak/cheatsheet-before" "$repo/dot_local/bin/executable_rofi-cheatsheet"
install -m755 "$bak/cheatsheet-before" "$HOME/.local/bin/rofi-cheatsheet"
cp "$bak/nano11.desktop" "$repo/dot_local/share/applications/nano11.desktop"
install -m644 "$bak/nano11.desktop" "$HOME/.local/share/applications/nano11.desktop"
for file in 30-window-rules.conf 40-keybindings.conf; do
    cp "$bak/$file" "$repo/dot_config/sway/config.d/$file"
    install -m644 "$bak/$file" "$HOME/.config/sway/config.d/$file"
done
cp "$bak/kvmfr-hook-original" "$repo/run_onchange_linux-35-setup-looking-glass-kvmfr.sh.tmpl"
sudo install -m644 "$bak/kvmfr.conf" /etc/modprobe.d/kvmfr.conf
sudo modprobe -r kvmfr
sudo modprobe kvmfr
rm "$HOME/.local/share/applications/looking-glass-client.desktop"
rm "$repo/dot_local/share/applications/looking-glass-client.desktop"
sway-safe-reload
```

This restores the prior 32 MiB configuration, which reproduces the old IDD capacity problem; it is not the recommended operational state. Keep the Intel driver unless deliberately testing driver rollback.

Inside an elevated Windows PowerShell, remove the new console task and restore the **pre-audit** registry backup if desired:

```powershell
Unregister-ScheduledTask -TaskName Nano11RestoreConsole -Confirm:$false
reg import C:\Users\Public\nano11-idd-before-fullcopy.reg
pnputil /restart-device 'ROOT\DISPLAY\0000'
```

`C:\ProgramData\Nano11\idd-before-*.reg` contains additional timestamped backups from setup runs; select intentionally because later backups already contain the copy workaround. Registry rollback does not uninstall Intel's driver. To return specifically to the old Code 28 state, use Device Manager's driver uninstall for the Intel VF only, or `pnputil /delete-driver oem16.inf /uninstall` after verifying that oem16.inf still names the installed Intel package. This deliberately removes acceleration and is unnecessary for normal rollback. Never delete the QCOW2 or VM directory as part of configuration rollback.

No commit, push, PR, or publication was performed.

## Upstream references

- [i915 SR-IOV Windows guest guidance](https://github.com/strongtz/i915-sriov-dkms/blob/master/docs/install-windows-guest.md): compatibility guidance, not proof that any driver works on this machine.
- [Matching IDD frame-capacity calculation](https://github.com/gnif/LookingGlass/blob/cdba29f2/idd/LGIdd/transport/lgmp/CLGMPFrameCaps.cpp).
- [IDD configuration and copy workarounds](https://github.com/gnif/LookingGlass/blob/master/doc/idd_configuration.rst).
