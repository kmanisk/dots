# Nano11 Intel SR-IOV and Looking Glass: Recovery Runbook

**ARCHIVED DOCKUR RECOVERY BASELINE (2026-11-03). Not the current launcher.** Nano11 migrated to native QEMU/KVM on **2026-11-05**. For the current commands, paths, one-shot systemd service, restoration and verified hardware behavior, read **[nano11-native-qemu.md](nano11-native-qemu.md) first**. All Podman commands, the Dockur web console (`127.0.0.1:8006`), and Dockur container creation described below are historical only and **must not be run as ordinary recovery procedures**. Detailed prior evidence: [dockur-windows.md](dockur-windows.md). Original persistent VM data remains under `/mnt/Games/VirtualMachines/dockur-nano11/` for compatibility; this directory name does not imply Dockur is installed.

This document is for restoring a damaged installation, not reconfiguring a healthy VM. Fresh live state and current source take precedence over dated figures below.

## Mandatory agent bootstrap and safety

1. Read `AGENTS.md`, `docs/system/SYSTEM_CONTEXT.md`, `docs/system/system-philosophy.md`, `docs/system/SUBSYSTEM_MAP.md`, then [dockur-windows.md](dockur-windows.md). Inspect the current launcher, KVMFR hook, Sway rules and guest setup.
2. Record `git status --short`, current host runtime and failing symptoms before edits. Do not reset/clean, commit or push without explicit instruction.
3. Preserve the persistent Windows QCOW2, UEFI/TPM state and ISO. Do not detach NVIDIA, switch `AsusMuxDgpu`, unbind the Intel PF, or expose blank-password RDP on the LAN.
4. Use RDP for recovery, and verify *actual* Intel Direct3D acceleration and *actual* guest LGMP UPS separately. A local FPS counter, the Windows refresh mode, VirtIO/IDD device names or SPICE connection alone are insufficient.

## First-response commands

~~~sh
nano11 status                  # reports state; does not open the VM
nano11 workspace               # normal: start/reuse and focus Windows on Sway workspace 10
nano11 launch                  # native Looking Glass; falls back to RDP if no first video frame
nano11 rdp                     # reliable localhost recovery window
nano11 open                    # web console, http://127.0.0.1:8006/
nano11 glass                   # explicit Looking Glass diagnostic
nano11 logs                    # live container logs
~~~

**Keybinds:** Alt+W opens/focuses Windows on workspace 10; Alt+Shift+W opens its management menu; Super+Alt+W provides the inhibited-workspace fallback. Right Ctrl toggles capture/release; Right Ctrl+D toggles Looking Glass FPS/UPS overlay. Closing the LG client leaves the VM running. The generic unconfigured Looking Glass launcher is hidden.

If the VM is black, frozen or shows **Transport Source Not Available**, immediately use `nano11 rdp` and **diagnose**, rather than deleting disks or blindly changing drivers.

## Verified architecture (November 3, 2026)

~~~text
ASUS TUF F16, i5-13450HX, CachyOS/Sway, AsusMuxDgpu
  RTX 5050/NVIDIA --> Linux display and games (1920x1200 @ 165.004 Hz)
  Intel UHD PF 0000:00:02.0 (8086:A78B) --> host i915-sriov-dkms
    |-- Intel PF DRM --> QEMU VirtIO/Venus recovery display
    |-- Intel SR-IOV VF 0000:00:02.1 --> vfio-pci --> Nano11
         --> signed Intel Windows driver --> D3D11 hardware
         --> Looking Glass matched IDD --> D3D12 indirect capture
         --> LGMP / 64 MiB IVSHMEM --> /dev/kvmfr0
         --> Looking Glass Linux client --> Sway workspace 10
  SPICE Unix --> audio/PipeWire and fallback input/display
  RDP 127.0.0.1:3389 TCP+UDP / web 127.0.0.1:8006
~~~

| Subsystem | Verified baseline |
| --- | --- |
| Kernel | `7.3.1-1-cachyos`, patched `i915-sriov-dkms 2026.10.28-1` |
| GPU bindings | Intel PF `00:02.0` on i915; Intel VF `00:02.1` on vfio-pci, isolated group 24 on that boot; RTX remains NVIDIA/Sway |
| Container | Rootless Podman `windows-nano11`, `docker.io/dockurr/windows:latest`, 12 KVM vCPUs, 4 GiB RAM |
| Windows | Nano11 Windows 11 Pro (25H2, build 26200), 64 GiB virtual QCOW2 |
| Intel guest GPU | Signed driver `32.0.101.7092`, earlier `oem16.inf`, error code 0; explicit D3D11 hardware on `8086:A78B` / feature level 11.0 |
| Looking Glass | Matching client/IDD `B7-829-cdba29f2`; old legacy Looking Glass Host disabled |
| Shared memory | KVMFR `/dev/kvmfr0` and QEMU memory-backend-file **64 MiB each** |
| IDD mode | `1920x1200@165.004*` plus 120 and 60 Hz; ForceIndirectCopy 1 / ForceFullDirectCopy 0 |
| Input | Native LGMP keyboard/mouse/clipboard tested; Right Ctrl releases; SPICE audio routes to PipeWire |
| Motion | 121.77 FPS / 119.78 UPS in one test, around 104/104 in another; sustained 165 UPS not yet proven |
| Recovery | RDP/web remain bound to localhost; no port 5900 exposure |

**DRM enumeration changes:** Intel was renderD129 and NVIDIA renderD128 on the audited boot, but they swapped from earlier boots. The managed launcher resolves the Intel DRM render/card pair by **PCI identity**, not render-node number. Likewise, do not assume IOMMU group 24 or `oem16.inf` stays fixed. SR-IOV VF creation/binding happens **on demand** during managed launch, not via a resident daemon.

## Canonical files: inspect, do not duplicate

All paths relative to `~/.local/share/chezmoi`:

| File | Purpose |
| --- | --- |
| `dot_local/bin/executable_nano11` | VF checks/bind, Podman/QEMU, Intel DRM discovery, first LGMP frame gate, RDP fallback, locks |
| `dot_local/bin/executable_rofi-windows` and `dot_local/bin/executable_rofi-cheatsheet` | Management menu and controls |
| `dot_config/sway/config.d/30-window-rules.conf` and `40-keybindings.conf` | Windows app-id/workspace and shortcuts |
| `dot_local/share/applications/nano11.desktop` | Managed Windows desktop entry |
| `dot_local/share/applications/looking-glass-client.desktop` | Hide generic LG desktop entry |
| `dot_config/fish/functions/nano11.fish` | Fish wrapper |
| `run_onchange_linux-35-setup-looking-glass-kvmfr.sh.tmpl` | KVMFR 64 MiB module/udev config and size check |
| `dot_local/share/nano11/Configure-Guest.ps1` | Elevated guest IDD registry/backup and RDP-to-console task |
| `docs/virtualization/dockur-windows.md` | Full evidence, repair narrative, tests, rollback |

Relevant live files: `~/.local/bin/nano11`, `~/.local/share/nano11/Configure-Guest.ps1` and `~/.config/sway/config.d/`. Source/live parity matters.

**Persistent non-Git files, must survive recovery:** `/mnt/Games/VirtualMachines/dockur-nano11/storage/data.qcow2`, `storage/windows_secure.*` firmware/TPM, `media/nano11-25h2.iso`, and guest-state under `storage/`. The `shared/` folder may contain user data, installers and audit evidence. Never delete these to fix a presentation issue. A chezmoi restore alone **cannot** reconstruct a missing installed Windows disk.

**Local historical audit evidence (not guaranteed on a replacement machine):** `~/.local/state/nano11-audit-20261103/repair-report.md`, `guest-evidence/`, `glass-final.log`, `rollback-manifest.json` and guarded `rollback-host.sh`. Runtime LG log: `$XDG_RUNTIME_DIR/nano11-looking-glass.log`; runtime SPICE socket: `$XDG_RUNTIME_DIR/nano11-spice/spice.sock`.

## Safe host verification

~~~sh
uname -r
cat /proc/cmdline
pacman -Q i915-sriov-dkms looking-glass-module-dkms podman freerdp
dkms status
modinfo i915 | grep -E '^filename:|^version:|max_vfs'
lspci -nnk -s 00:02.0           # Intel PF must remain on i915
lspci -nnk -s 00:02.1           # VF must be vfio-pci when guest is using it
cat /sys/bus/pci/devices/0000:00:02.0/sriov_numvfs
readlink -f /sys/bus/pci/devices/0000:00:02.1/iommu_group
ls -l /dev/dri /dev/vfio /dev/kvmfr0
supergfxctl -g
nano11 status
podman ps -a --filter name=windows-nano11
ss -lntup | grep -E ':(3389|8006|5900)\b'
~~~

Verified boot args (check the real current bootloader before editing):

~~~text
intel_iommu=on i915.enable_guc=3 i915.max_vfs=1 i915.xelp_enable_ccs=1 module_blacklist=xe
~~~

On a new kernel, **first** verify DKMS compatibility and patched i915 module. Avoid changing the host GPU mode or binding the Intel PF to vfio-pci.

### Check actual KVMFR allocation

~~~sh
cat /etc/modprobe.d/kvmfr.conf
cat /etc/modules-load.d/kvmfr.conf
cat /etc/udev/rules.d/99-kvmfr.rules
python3 - <<'PY'
import os, fcntl
fd = os.open('/dev/kvmfr0', os.O_RDONLY)
try:
    size = fcntl.ioctl(fd, 0x7544)  # KVMFR_DMABUF_GETSIZE
finally:
    os.close(fd)
print(size, 'bytes')
assert size == 64 * 1024 * 1024
PY
~~~

Verified size **67108864 bytes**, node permissions root:video 0660. If size is wrong, *only after a clean guest shutdown and after all LG clients stop*:

~~~sh
nano11 stop
# Verify QEMU and LG no longer hold /dev/kvmfr0.
sudo modprobe -r kvmfr
sudo modprobe kvmfr static_size_mb=64
# Re-run the ioctl test above before starting Windows.
~~~

The managed hook owns the options in `/etc/modprobe.d/kvmfr.conf`, load rule in `/etc/modules-load.d/kvmfr.conf`, and `/etc/udev/rules.d/99-kvmfr.rules`. Do **not** unload memory while QEMU/client uses it.

### Check live QEMU arguments, not guessed DRM nodes

~~~sh
pid=$(pgrep -f '^qemu-system-x86_64 ' | head -n1)
test -n "$pid" || { echo 'QEMU not running'; exit 1; }
tr '\0' '\n' <"/proc/$pid/cmdline" |
    grep -E 'vfio-pci|rendernode=|virtio-vga-gl|memory-backend-file|ivshmem|spice'
for dev in /sys/class/drm/renderD*; do
    printf '%s %s %s\n' "$dev" \
      "$(cat "$dev/device/vendor")" "$(basename "$(readlink -f "$dev/device")")"
done
~~~

Expected: `-device vfio-pci,host=0000:00:02.1,rombar=0`, Intel PF EGL render node, VirtIO GPU for recovery, shared KVMFR `size=64M` and Unix SPICE. NVIDIA DRM must **not** be mapped into the VM.


## Rebuild/start order after host damage

1. Read the policies and current source; capture `uname -r`, `dkms status`, boot args, VF/DRM mappings, KVMFR size and existing Podman state.
2. Keep the QCOW2, ISO and firmware state. A stopped container definition is disposable; the `storage/` directory **is not**.
3. If Windows is already running, use `nano11 rdp` without recreating it. If stopped, use `nano11 start` to reconcile one Intel VF (creating it if needed), confirm IOMMU isolation, bind VF to vfio-pci and start the managed rootless container.
4. Inspect the QEMU arguments and Intel-only DRM exposure. Keep the host NVIDIA path unchanged.
5. Recover Windows Intel driver and native LG IDD, using RDP/web access as required; only then retry `nano11 glass` and evaluate real LGMP frames.
6. A new machine needs the current chezmoi source, compatible patched i915/DKMS, KVMFR, QEMU/Podman and **a separate backup of the complete VM storage and custom ISO**. Dotfiles alone cannot recreate the installed guest.

Current package manifests list `podman` and `freerdp` in `packages/development.txt` and `looking-glass` / `looking-glass-module-dkms` in `packages/aur-explicit.txt`. Verify the separately installed patched `i915-sriov-dkms`. Recorded package versions are a known-good 2026-11-03 compatibility set, **not** a promise they work on any future kernel.

## Windows Intel VF repair and Direct3D validation

The original Windows failure was an unidentified Intel **Video Controller, Code 28**, even though PCI passthrough worked. Codex installed the **signed Intel 32.0.101.7092** package with hardware ID `PCI\VEN_8086&DEV_A78B`. Error code became **0** and survived Windows reboot and a cold VM start. No signature-enforcement bypass was needed.

In Windows (elevated PowerShell if required):

~~~powershell
Get-PnpDevice -Class Display | Format-List Status,FriendlyName,InstanceId
Get-PnpDevice -PresentOnly |
  Where-Object InstanceId -like 'PCI\VEN_8086*' |
  Format-List Status,FriendlyName,InstanceId
Get-CimInstance Win32_VideoController |
  Format-List Name,DriverVersion,InfFilename,Status
Get-PnpDevice -PresentOnly |
  Where-Object InstanceId -like 'PCI\VEN_8086*' |
  ForEach-Object {
    Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName DEVPKEY_Device_ProblemCode -ErrorAction SilentlyContinue
  }
~~~

An old driver installer was called `gfx.exe` in the RDP shared directory. **2026-11-05 archive correction:** it was SHA256-identical to `gfx_win_101.7092.exe` and removed during native-QEMU cleanup. The remaining original driver installer is `shared/gfx_win_101.7092.exe`; validate its **Intel Authenticode signature** and PCI hardware ID before any reinstall. The obsolete 900 MiB FAT32 `intel-driver.img` (which was not attached to the native VM) was also deleted on 2026-11-05. Do not regenerate an `INTELDRV` disk without proving a need.

To prove acceleration, use an explicit **D3D11 hardware device creation** test on Intel vendor `8086`, device `A78B` (the audit recorded feature level 11.0); inspect IDD hardware/D3D12 logs. A GPU name in Fastfetch, Red Hat VirtIO DOD or the headless adapter's Dxdiag field alone is not proof. Dxdiag sometimes reported unavailable 3D on this headless VF even when an explicit D3D11 hardware test succeeded.

## Looking Glass IDD: repair without breaking the working display

Use a **matching** Windows IDD and Linux client at `B7-829-cdba29f2`. The old **Looking Glass (host)** Windows service remains **disabled**, deliberately; do not start it alongside the IDD. Historical installer artifacts were in `shared/looking-glass-idd/looking-glass-idd-setup.exe` and `shared/looking-glass-idd-B7-829-cdba29f2.zip`; check for actual presence and matching hashes/versions before use.

The guest configuration source is `dot_local/share/nano11/Configure-Guest.ps1`, installed on the Linux side at `~/.local/share/nano11/Configure-Guest.ps1`. Copy it into Windows and run **elevated only after** installing a compatible signed Intel VF driver and matching IDD. It:

- Exports the prior registry state to timestamped `C:\ProgramData\Nano11\idd-before-*.reg`.
- Configures 1920×1200 modes and the indirect-copy workaround.
- Creates `C:\ProgramData\Nano11\Restore-Console.ps1` and scheduled task `Nano11RestoreConsole`.
- Restarts only the IDD display device (`ROOT\DISPLAY\0000` in the audit).

Known-good registry:

~~~text
HKLM\SOFTWARE\LookingGlass\IDD
  DefaultRefresh      REG_SZ        165.004
  Modes               REG_MULTI_SZ  1920x1200@165.004*
                                    1920x1200@120
                                    1920x1200@60
  ExclusiveMonitor    REG_DWORD     1
  ForceFullDirectCopy REG_DWORD     0
  ForceIndirectCopy   REG_DWORD     1
~~~

Windows read-only verification:

~~~powershell
Get-ItemProperty 'HKLM:\SOFTWARE\LookingGlass\IDD' |
  Format-List DefaultRefresh,Modes,ExclusiveMonitor,ForceFullDirectCopy,ForceIndirectCopy
Get-PnpDevice -Class Display
Get-CimInstance Win32_Service |
  Where-Object DisplayName -match 'Looking Glass' |
  Format-List Name,DisplayName,State,StartMode
Get-ScheduledTask -TaskName Nano11RestoreConsole -ErrorAction SilentlyContinue
~~~

**Root cause:** 32 MiB IVSHMEM could not hold the IDD's three full-resolution frame buffers plus cursor buffers, clipboard, metadata; it rejected the only monitor mode. Raising **both** Linux KVMFR and QEMU backing to **64 MiB** enabled real LGMP frames. Intel direct-copy caused image corruption: `ForceFullDirectCopy=1` did not help; `ForceIndirectCopy=1` with `ForceFullDirectCopy=0` produced clean observed motion while retaining Intel hardware rendering (with an extra CPU readback). Do not describe this as zero-copy.

### RDP-to-console restoration

RDP owns a distinct Windows display session. The guest event-driven `Nano11RestoreConsole` task (SYSTEM, LocalSessionManager event 24) transfers **only a disconnected** lab-user RDP session to the console using `tscon`. It never steals an active session, and requires no persistent polling service. Check `quser`, `Get-ScheduledTask` and `Get-ScheduledTaskInfo` before changing it. The current source permits battery operation and sets a one-minute execution limit, but battery-specific restoration is **not verified**. Do not expose the guest's blank-password RDP exception beyond localhost.


## Verify LGMP frames, keyboard, clipboard, audio

With native Windows console/IDD running, use `nano11 workspace`. On Linux:

~~~sh
log="$XDG_RUNTIME_DIR/nano11-looking-glass.log"
grep -E 'main_frameThread|Format:|Using Input:|Using Clipboard:|transport source|ERROR|Error' "$log" | tail -45
~~~

Verified live log signatures from November 3:

~~~text
main_frameThread | Format: FRAME_TYPE_BGRA 1920x1200 ... pitch:7680 ...
Using Input: LGMP
Using Clipboard: LGMP
~~~

The managed launcher waits for a **first actual LGMP frame** matching its client's `main_frameThread | Format:` output. If that startup condition fails, it closes the failed client and opens localhost RDP. Connected SPICE input/display and a locally rendered high FPS number are **not** valid success signals. This is a startup check, not a continuous watchdog.

Acceptance sequence:

1. Drag a Windows window; measure actual guest **UPS** in Right Ctrl+D overlay, as well as FPS. Confirm non-static video.
2. Move/click the mouse, type text, use modifiers, release with **Right Ctrl**, confirm Sway shortcuts work afterward. Input **must** be tested in Windows, not only via a connected channel.
3. Copy/paste Linux → Windows and Windows → Linux; verify the client reports `Using Clipboard: LGMP`.
4. Check Windows Intel VF hardware D3D (not VirtIO display), IDD resolution/mode and indirect-copy registry.
5. Close/reopen native client; ensure the VM stays running and the second launch focuses the same window.
6. Try recovery RDP, disconnect, and restore the console/native desktop. Do not run an active RDP session and expect console capture to show that same desktop automatically.
7. Verify audible SPICE/PipeWire output separately; only **silent** audio routing was confirmed by the audit.

**Performance limits:** one observed moving-content test measured **121.77 FPS / 119.78 UPS**, another ~104/104. The guest mode is 165 Hz, but sustained 165 UPS, end-to-end latency, audio listening quality and battery console restoration were not verified. WPF render callback counts can exceed capture UPS; do not report those as LGMP FPS.

**Input-test pitfall:** synthetic `wtype` injected Wayland keymap format 0 rejected by this client; restarting the client restored its normal compositor keymap. Do not classify this as a physical keyboard regression without an actual guest-input test.

## Root-cause lookup table

| Symptom | Safe check | Documented cause / direction |
| --- | --- | --- |
| "Transport Source Not Available", broken monitor, no native video | `nano11 rdp`, IDD helper/monitor, LG log, 64 MiB ioctl/QEMU memory | Former 32 MiB frame capacity rejection; or missing guest capture/console session |
| LG window shows desktop but 0 UPS | `main_frameThread | Format:` log; compare SPICE fallback | Host client running is not proof of native frames |
| Corrupted edges / partial dirty regions | Guest registry and IDD copy logs | Keep `ForceIndirectCopy=1` and `ForceFullDirectCopy=0` |
| Intel VF Code 28 / missing Intel GPU | Windows PnP IDs and driver signature; Linux VF binding | Install matching signed Intel VF driver, confirm error 0 and real D3D11 device |
| VF absent after new Linux boot | Start VM then inspect `sriov_numvfs` and `lspci` | VF is created/bound on demand; **do not** unbind PF |
| Kernel update broke SR-IOV | `dkms status`, `modinfo i915`, boot args | Reconcile patched driver with new kernel, not NVIDIA or MUX |
| Mouse/keyboard does not work | Right Ctrl capture and `Using Input: LGMP`; actual guest typing | Separate client capture from Windows session/input |
| LG fails after an RDP session | `quser`, console-restore task and IDD service | Guest session must be returned to console after disconnection |
| Slow cold start; PF reset logs | `journalctl -k` and container/QEMU logs | **Known unresolved:** Dockur's Intel Vulkan probes generated context resets/hangs |
| No `INTELDRV` removable disk | RDP redirected `shared` directory | Historical FAT32 raw SCSI image was not auto-mounted |
| Wrong Sway workspace | Window app-id/rules and managed launcher | `nano11-looking-glass` on workspace 10; Alt+W |

## Emergency rollback and backup rules

**First fix the narrow failing component.** Do not roll back the entire working graphics setup just because one display/input symptom appears.

Historical backups and evidence are in `~/.local/state/nano11-audit-20261103/` (local only). The guarded `rollback-host.sh` is a **pre-repair rollback**, and can refuse later source edits. Importantly, it restores the **old 32 MiB KVMFR**, which *reproduces* the broken IDD mode-capacity condition. **Do not run it as a normal recovery command.**

Windows registry backup paths: `C:\ProgramData\Nano11\idd-before-*.reg`; earlier task XML may also be saved there. Review timestamps before importing: newer backups may already contain the fixed settings. The source [dockur-windows.md](dockur-windows.md) and original `repair-report.md` document host/guest reversal, including removing the console task. Do not uninstall Intel OEM driver INF numbers blindly: `oem16.inf` is a historical identifier and may have changed.

If the VM disk becomes corrupted, **stop Windows cleanly**, then back up `storage/data.qcow2` together with `storage/windows_secure.*`, the custom ISO and other relevant state to separate durable storage *before* attempting repair/restoration. Never use `podman rm --volumes` or delete the runtime directory as a troubleshooting shortcut. Preserve all unrelated local repo changes and avoid reinitializing Windows.

## Remaining issues and provenance

- Dockur's Intel Vulkan capability probing caused PF context-reset/GPU-hang logs and delayed startup. The subsequent QEMU/Intel VF worked, but the probe root cause was **not repaired**. Do not invent a kernel-wide performance fix.
- The full Linux host was not rebooted again during Codex's final acceptance run; cold *VM* recreation was tested. Module/client versions are specific to the November 3 working baseline.
- A pre-existing dangling Tele documentation link obstructed global chezmoi discovery. Codex applied only selected targets with source/live verification. Do not edit unrelated Tele configuration during a Windows recovery.
- No new persistent watchdog/service was required. Audio listening/latency, battery console restoration and sustained 165 UPS are outstanding.
- The user's workstation prioritizes NVIDIA/Sway gaming. Avoid touching its MUX, NVIDIA or unrelated desktop configuration in recovery.

**Detailed evidence (local only):** `~/.local/state/nano11-audit-20261103/repair-report.md`, `guest-evidence/d3d-hardware.txt`, `guest-evidence/looking-glass-idd.txt`, `guest-evidence/final-config.txt`, `guest-evidence/looking-glass-input.txt`, `guest-evidence/motion-result.txt`, and `glass-final.log`.

Upstream background, not a substitute for current testing:

- Intel SR-IOV guest guidance: https://github.com/strongtz/i915-sriov-dkms/blob/master/docs/install-windows-guest.md
- IDD frame-capacity calculation: https://github.com/gnif/LookingGlass/blob/cdba29f2/idd/LGIdd/transport/lgmp/CLGMPFrameCaps.cpp
- IDD settings/copy workarounds: https://github.com/gnif/LookingGlass/blob/master/doc/idd_configuration.rst

**Agent completion criteria:** preserve existing Windows storage; verify Intel PF/VF ownership, 64 MiB KVMFR, actual Intel D3D hardware, native LGMP first video frame, actual keyboard/mouse/clipboard, recovery RDP and loopback ports. Make only validated changes in chezmoi, update the owning subsystem docs plus `SYSTEM_CONTEXT.md` when system assumptions change and `SYSTEM_CHANGELOG.md` per `AGENTS.md`. Clearly report unverified items. Never commit/push unless explicitly directed.
