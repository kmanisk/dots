# Windows 10 X-Lite Micro10 lab (separate native KVM VM)

**Historical installation notes, superseded by [win10-xlite-experiment.md](win10-xlite-experiment.md).** Resource, networking, driver and capture statements below describe earlier stages and are not the current baseline.

Historical status: installed and desktop boot verified on 2026-11-06; Intel VFIO/KVMFR/SPICE attached. **Intel Windows driver installation is under test; device Code 0 and Looking Glass frame capture are not yet confirmed.** This is an isolated experimental guest, not a Nano11 replacement.

Before changing the machine, read AGENTS.md, docs/system/SYSTEM_CONTEXT.md, docs/system/system-philosophy.md, and the current Nano11 runbook (docs/virtualization/nano11-native-qemu.md). Follow live runtime evidence over historical notes and keep unrelated dirty chezmoi files intact.

## Purpose and isolation

Compare a heavily stripped Windows 10 installation against the working Windows 11 Nano11 baseline, especially idle process count, memory use, Intel Raptor Lake VF acceleration and Looking Glass. The test VM must **never** write to Nano11's original QCOW2, secure OVMF vars, TPM state, or existing guest configuration.

- Host: CachyOS/Sway, display on NVIDIA RTX 5050. Intel PF 0000:00:02.0 stays on Linux i915. Intel SR-IOV VF 0000:00:02.1 is bound to vfio-pci in group 24 on the verified boot.
- Test guest: X-Lite "Micro 10" SE, Windows 10 Pro build **19045.3757**. This is a third-party modified build; its provenance and security are not guaranteed.
- CPU/RAM: KVM/QEMU, 4 virtual CPUs, 3072 MiB allocated. QEMU launched in an on-demand transient systemd system unit running as the ordinary user, not within the 1.5 GiB Desktop Commander memory cgroup.
- Network: **-nic none**. No outbound internet, RDP port forwarding, shared host directory, or Docker/Podman container.
- BIOS: SeaBIOS/legacy optical boot; see boot-media findings below. The guest currently does not use the OVMF/UEFI state used by Nano11.
- Virtual display: standard VGA and localhost VNC 127.0.0.1:5912 for setup/recovery. Do not expose VNC to the network (no authentication is configured).
- Optional GPU mode: pass Intel VF via VFIO, map **64 MiB /dev/kvmfr0** with ivshmem-plain, and expose a user-owned SPICE Unix socket under $XDG_RUNTIME_DIR/win10lab/spice.sock. Keep Nano11 stopped so the guests never compete for the VF or LGMP transport.
- Both guests are intended to be on-demand; do not create permanently enabled services solely for this experiment.

## Paths, checkpoints and media

All large files live on the Games NTFS3 partition, not the small Linux Btrfs root.

- VM root: /mnt/Games/VirtualMachines/xlite-micro10/
- Installed guest disk: storage/win10lab.qcow2 (sparse **40 GiB virtual**).
- **Untouched Windows 11 reference:** /mnt/Games/VirtualMachines/dockur-nano11/storage/data.qcow2. Nano11's independent backup remains /mnt/Games/VirtualMachines/nano11-backup-20261105/.
- Initial clean-install QCOW2 internal snapshot: **clean-xlite-pre-intel-vf**, created after a guest-initiated clean shutdown, before Intel Windows driver installation.
- ISO: media/xlite-micro10-19045.3757.iso, **1,310,619,648 bytes**, SHA-256 **b413bc20f04f543dbdf0127cf8ea519a65c8ed5e93692cf86334e4f6bd5d9837**. Extracted from the downloaded Windows X-Lite 7z archive; original 7z was deleted after extraction and ISO verification at user's request.
- Original ISO contains Windows Setup and a single install.wim for Windows 10 Professional build 19045.3757. WIM contents were successfully read/verified; the image lacks built-in WIM integrity metadata.
- Installer image media/xlite-installer-fat32.img (historical UEFI workaround test; not used during current BIOS boot). This may be removed after preserving the verified ISO.
- Driver-only media/xlite-drivers-fat32.img: 2.5 GiB conventional MBR/FAT32 partition starting at sector 2048, volume label **XLITEDRV**, mounted as **E:** in Windows on 2026-11-06. QEMU attaches it read-only as USB storage.
- Report media/xlite-reports-fat32.img: 64 MiB conventional MBR/FAT32 partition starting at sector 2048, volume label **WIN10RPT**, mounted as **F:** in Windows. Guest may write logs; do not mount it read/write on Linux concurrently.
- Staging: staging/intel-driver/Graphics contains the extracted signed Intel driver files. An older 1 GiB USB image copy is at staging/driver-usb-before-inf.img; the new verified media replaces it for current testing.

Use the partition offset with mtools, **after Windows is shut down**, to inspect the report image:

~~~sh
mtype -i /mnt/Games/VirtualMachines/xlite-micro10/media/xlite-reports-fat32.img@@1048576 ::/intel-install.log
mtype -i /mnt/Games/VirtualMachines/xlite-micro10/media/xlite-reports-fat32.img@@1048576 ::/idd-config.log
~~~

Do not read/write a FAT32 image from the host while QEMU has it open for guest writes; stop the guest cleanly first. The driver disk is read-only to the guest.

## Launch and lifecycle

Current chezmoi source is dot_local/bin/executable_win10lab, installed as ~/.local/bin/win10lab. Bash/ShellCheck validation has passed. Default GPU mode (0) uses virtual VGA; GPU mode 1 requires VFIO/KVMFR and adds SPICE/LGMP. The launcher refuses to silently reuse an already-running VM in a different GPU mode.

~~~sh
win10lab status
WIN10LAB_GPU=1 win10lab start
win10lab screen
win10lab viewer                 # localhost VNC; configured with no password
win10lab logs
win10lab stop                   # ACPI event; may not terminate Micro10
~~~

Micro10 did **not** reliably shut down from QEMU ACPI. The tested safe fallback is to issue Windows shutdown from inside the guest. The local experimental VNC input helper at ~/.local/state/win10lab/vnc-input.py implements this:

~~~sh
python3 ~/.local/state/win10lab/vnc-input.py shutdown
win10lab status
~~~

This invokes Windows shutdown.exe via the guest desktop; verify that QEMU has actually exited before snapshots or host-side media editing. Do not use force-kill or rewrite guest QCOW2 while running.

The helper originally mapped a colon into a semicolon when typing a Windows drive path; this was corrected by explicitly sending Shift+semicolon. When automating a Windows command, verify the visible PowerShell text/result rather than treating typed keystrokes as proof of execution.

## ISO boot and media recovery

The original ISO's Windows Setup install.wim is valid and contains an EFI El Torito entry, but OVMF returned "No bootable option or device was found" from optical and early superfloppy USB attempts. QEMU SeaBIOS with an AHCI/IDE CD-ROM booted the original ISO and completed Windows Setup. The initial 40 GiB guest disk was unallocated; only the dedicated test disk was selected in Setup.

Raw FAT32 "superfloppy" USB images later did not receive normal Windows drive letters. Rebuilding **both** offline transfer images with DOS/MBR partition tables, a FAT32 partition at 1 MiB, and mtools image-offset syntax resolved it: Windows Get-Volume showed **E: XLITEDRV** and **F: WIN10RPT**. Preserve this format for future recoveries.

## Baseline measurement before Intel driver

Windows reached a functional desktop without internet. Windows 10 Task Manager showed:

- **39 processes**, 0.6 GB physical RAM in use out of 3 GB allocated, 0% CPU at the measurement instant.
- Around 6.9 GiB actually allocated in the QCOW2 after installation (can grow while testing).
- This was before Intel graphics WDDM and Looking Glass IDD installation, so it is not an after-acceleration benchmark. Earlier Nano11 screenshots showed ~120 processes and ~2.6 GB in use with 4 GB guest RAM; the two guests are not yet workload-matched.

## Intel driver and Looking Glass plan: verified versus pending

Host-side VFIO and KVMFR are attached in GPU mode: QEMU arg list included vfio-pci,host=0000:00:02.1, ivshmem-plain with 64 MiB KVMFR, and the SPICE Unix socket. Windows can boot on the fallback VGA in this mode.

The original signed Intel 32.0.101.7092 package was archived at /mnt/Games/VirtualMachines/dockur-nano11/shared/gfx_win_101.7092.exe. Its extracted **Graphics/iigd_dch.inf** explicitly lists **PCI VEN_8086&DEV_A78B** in the Windows 10 17763+ driver section. Avoid running Intel's full installer (which can add update apps and telemetry); use the native Windows `pnputil` signed-driver path instead. The unmodified Graphics directory and its matching Microsoft-trusted catalog igdlh.cat were copied onto XLITEDRV.

Guest-side PowerShell scripts under chezmoi:

- dot_local/share/win10lab/Install-Intel-Driver.ps1: checks for 8086:A78B, runs pnputil /add-driver on Graphics/iigd_dch.inf with /install, records the resulting Code and driver version. It writes C:\ProgramData\Win10Lab\intel-install.log and copies it to WIN10RPT if present.
- dot_local/share/win10lab/Configure-XLite-IDD.ps1: after **confirmed Intel Code 0 and installed IDD**, backs up IDD registry, sets 1920x1200 modes with 165.004/120/60 Hz, ExclusiveMonitor, and the known Intel VF ForceIndirectCopy workaround. Unlike Nano11's script, it does not register an RDP console-restoration task (there is no RDP connection in this offline experiment).
- The matching signed Looking Glass IDD B7-829 installer is available as E:\LGIddSetup.exe and Linux client as ~/.local/bin/looking-glass-client-idd. These must remain version matched.

On 2026-11-06 the Windows Intel VF enumerated as Video Controller with **Code 28** before driver installation. The first attempt to type E:\Install-Intel-Driver.ps1 via VNC failed because colon mapped to semicolon; this was not a driver error. The corrected input helper changed PowerShell to E: successfully and launched .\Install-Intel-Driver.ps1. The script confirmed that 8086:A78B was present before calling pnputil. **Final pnputil success/Code 0, IDD installation and LGMP capture still require verification; do not claim them based on host-side device attachment alone.**

Once the Intel driver is confirmed Code 0, install the matching IDD and apply the X-Lite configuration script. Then test a real `main_frameThread | Format:` LGMP frame with the matching client and a separately configured SPICE Unix socket for this VM; a connection to SPICE alone is not proof of capture. Keep the offline trust boundary and original Nano11 configuration intact.

## Recovery

- Before any destructive driver troubleshooting, stop Windows cleanly and check `qemu-img check -q -f qcow2` only with the disk unowned.
- The pre-driver QCOW2 internal snapshot is `clean-xlite-pre-intel-vf`. To revert deliberately, shut down the guest and use `qemu-img snapshot -a clean-xlite-pre-intel-vf /mnt/Games/VirtualMachines/xlite-micro10/storage/win10lab.qcow2`. This **discards guest changes since the snapshot**; never do so automatically.
- If a Windows driver fails, keep VNC as the recovery display and check the logged ConfigManagerErrorCode, the guest installer logs, QEMU stderr, and the host's i915/vfio kernel journal.
- If Windows 10 proves incompatible with the current IDD or driver, leave Nano11 as the working VFIO/Looking Glass baseline rather than altering it to accommodate the experiment.

## Security and limitations

The downloaded X-Lite ISO is an unofficial, stripped-down Windows build. It creates a local Administrator account with no password and may have changed important Windows security or update services. The lab is **not trusted for sensitive accounts or internet access**. Use it strictly for offline testing. No Windows activation or license entitlement is supplied by this setup.

Full Windows 10 22H2 consumer security support ended in October 2025. This custom build is not a supported alternative to a properly licensed, serviced Windows installation. Record measured memory, Intel driver behavior and genuine Looking Glass frame capture before recommending it over Nano11.
