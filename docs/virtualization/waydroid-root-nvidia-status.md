# Waydroid Root + NVIDIA — Authoritative System State

Last verified: 2026-11-02
Purpose: context-free handoff and recovery reference for this machine.

## Rules for future agents

Treat this document as the source of truth for the known-good Waydroid installation. Inspect before changing anything. Do not reinstall, downgrade, regenerate images, replace the vendor, change GPU nodes, remove overlays, or alter Magisk merely as a diagnostic step. Preserve the working state first and prefer read-only verification.

## Host and hardware

- Host OS: CachyOS x86_64
- Kernel at latest verification: `7.3.1-1-cachyos`
- Desktop: Sway/Wayland, display `wayland-1`
- Laptop GPU topology: Intel iGPU + NVIDIA GeForce RTX 5050 Laptop GPU 8 GB
- Intel render node: `/dev/dri/renderD128`, driver `i915`
- NVIDIA render node: `/dev/dri/renderD129`, driver `nvidia`
- NVIDIA package: `nvidia-open-dkms 615.78.08-2`
- NVIDIA runtime driver: `615.78.08`

## Installed Waydroid stack

Latest verified packages:

```text
waydroid-nvidia-bin 0.2.0-1
lxc 1:7.0.0-2.1
libgbinder 1.1.54-1.1
libglibutil 1.0.83-1.1
python-gbinder 1.3.1-1.1
python-dbus 1.5.1-1
```

`waydroid --version` reports `1.6.3`.

The installed package is `waydroid-nvidia-bin`, not stock Arch `waydroid`. It is based on `Shiro836/waydroid-nvidia` v0.2.0.

## Android image

Latest live Android properties:

```text
Android version: 13
Build: lineage_waydroid_x86_64-userdebug 13 TQ3A.230901.001 eng.aleast.20260927.143833 test-keys
ABI: x86_64
Vendor type: MAINLINE
```

Historical setup used LineageOS 20 images. The current live build above is authoritative if it differs from older notes.

## Known-good runtime state

On 2026-11-02:

```text
Session:         RUNNING
Container:       RUNNING
Vendor type:     MAINLINE
IP address:      192.168.240.112
Session user:    onyx (1000)
Wayland display: wayland-1
```

`waydroid-container.service` was `active` and `disabled`, meaning running/on-demand rather than enabled for unconditional boot startup.

Normal launch path used successfully:

```bash
waydroid-launcher
```

## NVIDIA configuration

The important verified Waydroid GPU settings are:

```ini
vendor_ota = https://github.com/Shiro836/waydroid-nvidia/releases/download/v0.2.0/waydroid-nvidia-vendor-ota-v0.2.0.json
drm_device = /dev/dri/renderD129
nvidia_prolapse_install = vendor-image
nvidia_driver_mode = nvidia-prolapse
nvidia_native_gl = off
debug.hwui.renderer = skiavk
```

Do not change `drm_device` back to Intel simply because older notes describe an Intel-only setup. The current NVIDIA path has been directly verified working.

## Sway / full-UI sizing workaround

On 2026-11-02 the full Waydroid UI intermittently opened with Android rendered only in the upper-left portion of the Sway tile while the remaining right/bottom area was black. The GPU renderer itself was healthy. Sway had a `1476x902` logical Waydroid tile at scale `1.3`, while Android correctly exposed a roughly corresponding `1918x1172` physical display, so this was not an NVIDIA/ANGLE/NVK failure.

The active NVIDIA setup intentionally keeps:

```text
persist.waydroid.use_subsurface=true
```

The targeted workaround is:

```text
persist.waydroid.no_background_subsurface=true
```

This disables Waydroid's separate black background subsurface without disabling the NVIDIA direct-subsurface path. It was applied with `waydroid prop set persist.waydroid.no_background_subsurface true` and verified to survive a full Waydroid session restart. After the restart, the Waydroid surface filled the Sway window again.

Do **not** set `persist.waydroid.use_subsurface=false` as a first-line fix on this installation. `waydroid-nvidia` v0.2.0 deliberately configures the subsurface path, and the working RTX 5050 setup should be preserved unless a future upstream fix explicitly changes that requirement.

## NVIDIA hardware acceleration — verified working

Live Android properties:

```text
ro.hardware.egl      = angle
ro.hardware.gralloc  = minigbm_gbm_mesa
ro.hardware.vulkan   = nvidia
gralloc.gbm.device   = /dev/dri/renderD129
```

SurfaceFlinger reported:

```text
GLES: Google Inc. (NVIDIA)
ANGLE (NVIDIA, Vulkan 1.4.354
NVIDIA GeForce RTX 5050 Laptop GPU (NVK NV1B7)
NVK-26.2.5)
OpenGL ES 3.2
```

This proves Android is not using llvmpipe or SwiftShader. The active graphics chain is:

```text
Android app / HWUI
        |
      ANGLE
        |
     Vulkan
        |
   Mesa NVK
        |
 NVIDIA kernel driver
        |
 RTX 5050 Laptop GPU
        |
 Waydroid presentation
        |
       Sway
```

`nvidia-smi` directly observed Android processes on the RTX, including:

- Android graphics composer
- SurfaceFlinger
- minigbm allocator
- SystemUI
- Launcher3
- Google Play Services
- Google Search

During verification, total NVIDIA VRAM usage was about 508 MiB with Waydroid running. Therefore RTX 5050 hardware acceleration and hybrid presentation through the current Sway environment are known-good.

## Historical GPU context

The machine previously stayed on Intel rendering because `waydroid-nvidia` v0.1.2 had a hybrid Intel+NVIDIA presentation problem involving NVIDIA block-linear dma-bufs and Intel/i915 presentation. Local probes had already shown that NVIDIA-linear to i915 import could work, but the released path was not suitable.

That old decision is obsolete for the current installation: `waydroid-nvidia` v0.2.0 with `nvidia-prolapse` is installed and has been directly verified rendering on the RTX 5050. Do not "restore" the old Intel configuration unless troubleshooting a confirmed regression and only after preserving the current state.

## Root / Magisk architecture

Waydroid was rooted systemlessly rather than by destructively rewriting the base system/vendor images. Root-related overlay state is under:

```text
/var/lib/waydroid/overlay/
```

Historical root injection included Android init/Magisk files under the overlay, including `system/etc/init/bootanim.rc` and `system/etc/init/magisk/`. Magisk runtime state is stored inside Android under:

```text
/data/adb/
```

The original setup used a Waydroid-compatible Magisk/MagiskSU implementation and provisioned root through the overlay so the base images could remain recoverable.

## Current root status

MagiskSU is definitely installed. On 2026-11-02:

```text
adb shell 'su -v'
v27.2-Waydroid:MAGISKSU
```

Normal ADB identity:

```text
uid=2000(shell) gid=2000(shell)
```

But the current ADB shell root request returns:

```text
adb shell 'su -c id'
Permission denied
```

Interpret this precisely:

- MagiskSU is installed and its `su` binary is present.
- Root infrastructure has not disappeared.
- The ADB `shell` user is currently denied/unauthorized by MagiskSU.
- Do not claim current ADB root is operational until `su -c id` returns `uid=0(root)`.
- This authorization problem is separate from the NVIDIA graphics stack; do not modify the working GPU configuration while investigating root.

Earlier in the installation history, `su -c id` was verified returning UID 0 and persisted across container/session restarts. Therefore the present failure is a regression or authorization-state issue, not evidence that Waydroid was never rooted.

## ADB and networking

Known network state:

```text
Waydroid subnet: 192.168.240.0/24
Interface: waydroid0
Current Android IP: 192.168.240.112
ADB TCP: 192.168.240.112:5555
```

The host ADB key was historically provisioned into Android so the host could connect without repeated authorization. Current verification successfully connected with:

```bash
adb connect 192.168.240.112:5555
```

The IP can change; obtain it from `waydroid status` rather than assuming `.112` forever.

## Backups and recovery history

A clean Waydroid backup was created historically at:

```text
/var/backups/waydroid_clean/
```

Recorded clean-image SHA256 values from the original setup:

```text
system.img  d2809f66124f5d99e1165466ebd8aa1dacfb82829937942d81134a0862117103
vendor.img  5edafb92678c5abec7c8403c6873ce1de583009a57a6cb6de44d99f9b3f5c070
```

A Snapper snapshot was also recorded historically as snapshot `#589`, description `pre-waydroid-setup`.

These backups predate the current `waydroid-nvidia` v0.2.0 state. They are recovery references, not a reason to overwrite the working current vendor. Before any future destructive operation, verify that these backups/snapshot still exist and create a fresh backup of the current v0.2.0 state.

## Important paths

```text
/var/lib/waydroid/waydroid.cfg       main Waydroid configuration
/var/lib/waydroid/images/            Android system/vendor images
/var/lib/waydroid/overlay/           systemless overlay/root modifications
/var/backups/waydroid_clean/         historical clean backup
~/.local/share/waydroid/             user-side Waydroid state/data
~/.local/share/applications/         Waydroid desktop launchers
~/.android/adbkey                    host ADB private key
~/.android/adbkey.pub                host ADB public key
```

Do not publish or copy `~/.android/adbkey` into dotfiles or documentation.

## Read-only verification procedure

Use this first when a future agent needs to understand the state:

```bash
waydroid status
waydroid --version
pacman -Q waydroid-nvidia-bin nvidia-open-dkms

adb connect "$(waydroid status | awk '/IP address/{print $3}'):5555"
adb shell id
adb shell 'su -v'
adb shell 'su -c id'

adb shell getprop ro.build.version.release
adb shell getprop ro.build.display.id
adb shell getprop ro.product.cpu.abi
adb shell getprop ro.hardware.egl
adb shell getprop ro.hardware.gralloc
adb shell getprop ro.hardware.vulkan
adb shell getprop gralloc.gbm.device

adb shell dumpsys SurfaceFlinger | grep -E 'GLES|EGL implementation'
readlink -f /sys/class/drm/renderD128/device/driver
readlink -f /sys/class/drm/renderD129/device/driver
nvidia-smi
```

Expected healthy GPU indicators:

```text
ro.hardware.egl=angle
ro.hardware.vulkan=nvidia
gralloc.gbm.device=/dev/dri/renderD129
SurfaceFlinger renderer contains NVIDIA + ANGLE + NVK + RTX 5050
```

`llvmpipe` or `SwiftShader` in the active renderer would indicate software rendering and should be treated as a regression.

Expected root indicators:

```text
su -v -> v27.2-Waydroid:MAGISKSU
su -c id -> uid=0(root) ...
```

At the latest verification only the first root indicator passes; `su -c id` is currently denied.

## Safe troubleshooting order

1. Read this document.
2. Run only the read-only verification commands above.
3. Distinguish root authorization failures from GPU failures; they are separate subsystems.
4. If graphics is healthy, do not touch the NVIDIA configuration.
5. If root is denied, inspect Magisk policy/authorization state before reinstalling anything.
6. Before any change to `/var/lib/waydroid`, images, overlays, vendor, or Magisk, create a fresh backup/snapshot.
7. Change one subsystem at a time and re-run verification.
8. Record any new known-good state back into this file.

## Do not do these as first-line diagnostics

- Do not run `waydroid init -f`.
- Do not reinstall Waydroid just to test it.
- Do not replace the current vendor image with stock MAINLINE.
- Do not switch `drm_device` to Intel because of old v0.1.2 notes.
- Do not remove `/var/lib/waydroid/overlay/` to test root.
- Do not delete Android `/data/adb/` to test Magisk.
- Do not blindly `rm -rf` Waydroid state.
- Do not overwrite the current v0.2.0 setup with the historical clean backup without first preserving the current state.

## Current concise state

As of 2026-11-02:

```text
Waydroid:             1.6.3, RUNNING
Package:              waydroid-nvidia-bin 0.2.0-1
Android:              13 / Lineage Waydroid x86_64 userdebug
Vendor:               MAINLINE + waydroid-nvidia v0.2.0 vendor path
GPU:                  RTX 5050 Laptop GPU
NVIDIA driver:        615.78.08 / nvidia-open-dkms
Android render node:  /dev/dri/renderD129
Graphics:             ANGLE -> Vulkan -> NVK -> RTX 5050
HW acceleration:      VERIFIED WORKING
Software fallback:    NOT ACTIVE
Sway presentation:    WORKING
Sizing workaround:    use_subsurface=true + no_background_subsurface=true
MagiskSU:             INSTALLED, v27.2-Waydroid:MAGISKSU
ADB shell root:       CURRENTLY DENIED (Permission denied)
Container service:    ACTIVE, disabled for boot enablement
ADB/network:          WORKING, current IP 192.168.240.112
```

This is the baseline a context-free future agent should preserve.