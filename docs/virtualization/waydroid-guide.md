# Waydroid + NVIDIA on CachyOS — Setup & Troubleshooting Log

Machine: ASUS TUF F16 · i5-13450HX · RTX 5050 Mobile (Blackwell) · Sway 1.12 Wayland · 1920×1200@165Hz · CachyOS (`linux-cachyos`), UFW active.
Stack: `waydroid-nvidia-bin 0.1.2-1` (Venus over vtest socket) · LineageOS 20 GAPPS · `supergfxctl` mode `AsusMuxDgpu` (dGPU-only).

## 0. Architecture (how the whole thing fits together)

```
┌─ HOST (CachyOS, Sway/Wayland on NVIDIA, MUX dGPU) ─────────────────────────┐
│  wd-venus.service (user)          │  waydroid-container.service (system)    │
│  virgl_test_server +             │  LXC container (LineageOS 20, Android 13│
│  virgl_render_server ─real       │  GAPPS, kernel-shared, no VM)           │
│  Vulkan─▶ RTX 5050 proprietary   │    binderfs (/dev/binder, hwbinder, vndbinder)   │
│  driver                          │    veth eth0 ◄──► bridge waydroid0 (.1)  │
│  socket: /run/waydroid-venus/    │    dnsmasq (.2–.254, authoritative)      │
│  venus.sock ⇆ bind-mounted as    │    UFW: allow 67/udp + 53 + route in on  │
│  /dev/venus in guest             │    waydroid0; NAT via ip lxc masquerade  │
└────────────────────────────────────────────────────────────────────────────┘
```

- **Graphics path (64-bit app):** app Vulkan → guest Mesa Venus (`vulkan.virtio.so`) → unix socket → host renderer → NVIDIA driver → block-linear dmabuf → guest gralloc (`minigbm_gbm_mesa` vtest backend) → `hwcomposer.waydroid` → Wayland subsurface → Sway (NVIDIA-driven, so buffers display natively). GL goes via ANGLE-on-Venus (`skiavk` HWUI, `skiaglthreaded` RenderEngine). Refresh pinned `--refresh 165`.
- **ARM path (32-bit app):** ARM32 → Houdini (`libhoudini.so`) → x86 ANGLE → x86 Venus → same socket/host NVIDIA path (dual-ABI guest ships ELF32 `vendor/lib` + ELF64 `vendor/lib64`). ARM64 → `houdini64`. Kernel auto-invokes translators via binfmt_misc (`arm_exe/arm_dyn/arm64_exe/arm64_dyn`).
- **Images/data layout:** base `system.img`/`vendor.img` (read-only, OTA) + `/var/lib/waydroid/nv/guest` (NVIDIA stack) + `/var/lib/waydroid/overlay/system` (Houdini, upperdir) merged by overlayfs; userdata `~/.local/share/waydroid/data` (730M); cfg `waydroid.cfg` (NVIDIA props + Houdini props, disjoint keys).
- **Known limits:** no ETC2 emulation, no ASTC readback, render nodes renumber across boots (re-run setup), `hwcomposer` flaky across some boots (container restart recovers), no keymapper layer (host keyboard = physical keyboard; clicks = taps).

## 1. Preflight audit (read-only, no changes)
- Verified: open kernel modules (`nvidia-open-dkms`, `modinfo` Dual MIT/GPL, `/proc/driver/nvidia` says Open), `nvidia-drm.modeset=Y`, driver ≥ 595.71 (615.71.09, later 615.78.08).
- Verified: eDP panel on NVIDIA card, Sway/GLX/EGL-Wayland on NVIDIA (`LIBVA_DRIVER_NAME=nvidia`), kernel binderfs flags set, `/dev/udmabuf` present, 51G disk free.
- Ran upstream probe (`tests/run-probe.sh`): exit 0 — block-linear DMA-BUF imports pass; LINEAR+INPUT_ATTACHMENT `FORMAT_NOT_SUPPORTED` is a known, guest-worked-around quirk.

## 2. Installation
1. Snapper pre-snapshot (`snapper -c root create --description pre-waydroid-nvidia-bin-gapss-165hz`).
2. Re-checked AUR `PKGBUILD 0.1.2-1` (provides/conflicts `waydroid`) + `waydroid-nvidia-setup`, udev rule (`TAG+=uaccess`, scoped), `wd-venus.service` (user unit), tmpfiles.
3. `paru -S --noconfirm --needed waydroid-nvidia-bin` (pulls `lxc`, `python-gbinder`; snapper pre/post auto).
4. `sudo waydroid init -s GAPPS` (system 2.5G + vendor 537M).
5. `sudo waydroid-nvidia-setup --refresh 165` (validates dual-ABI ELF, NVIDIA node, modeset, minigbm vendor; writes `drm_device`, `suspend_action=none`, Venus props; `waydroid upgrade -o`).
6. Enabled `waydroid-container.service` (system) + `wd-venus.service` (user). udev ACL already grants `/dev/udmabuf`.
7. Verified: `boot_completed=1`, `GLES: ANGLE NVIDIA Vulkan Venus (RTX 5050)`, gralloc `minigbm_gbm_mesa`, Settings window on Sway.

## 3. Internet fix (root cause proven, 3 UFW rules)
- Symptom: Android DHCPDISCOVER loop, no IP.
- `nft monitor trace` proof: `inet lxc input` → accept, then UFW `ip filter INPUT` → `dport 67 → skip-to-policy → DROP` (terminating; bypasses UFW logging, hence invisible in dmesg). Same pattern blocked DNS (:53) and TCP forwarding (UFW passes only ICMP + established).
- Fix (persistent, defaults untouched):
  ```
  sudo ufw allow in on waydroid0 to any port 67 proto udp
  sudo ufw allow in on waydroid0 to any port 53
  sudo ufw route allow in on waydroid0
  ```
- Verified: IP `.112` leased → gateway/DNS/external-IP ping 0% loss → HTTPS `204 in 0.096s` → Finsky active.
- Rollback: `sudo ufw delete route allow in on waydroid0`, `sudo ufw delete allow in on waydroid0 to any port 53`, `sudo ufw delete allow in on waydroid0 to any port 67 proto udp`, `sudo ufw reload`.

## 4. Graphics crashes (fixed by setup re-runs + reboot)
- `hwcomposer.waydroid.so` SIGABRT → SurfaceFlinger `HIDL DEAD_OBJECT` → app `Adding window failed`; later a hang variant (SF/window dumpsys timeouts, launches hanging, 0 crashes).
- Fix: `sudo waydroid-nvidia-setup --refresh 165` (idempotent) + container restart. Crash buffer clean since.
- Driver mismatch found mid-way: userspace updated to 615.78.08 while live boot ran module 615.71.09 (NVML mismatch, NVIDIA missing from Vulkan, Venus fell back to Intel). Fixed by rebooting into `linux-cachyos 7.2.9-2`.

## 5. Operational quirks learned
- **Render nodes renumber across boots** (observed 129→128→129 for NVIDIA). After every reboot: check `grep DRIVER /sys/class/drm/renderD*/device/uevent` vs `grep drm_device /var/lib/waydroid/waydroid.cfg`; re-run setup if stale.
- **Android-side `netd` can wedge** (`stopping`, no DHCP attempts despite healthy host path). Fix: `sudo systemctl restart waydroid-container.service` + session stop/start (data-preserving).
- Session stop tears down bridge/dnsmasq/lxc tables (`waydroid-net.sh stop`); all recreated on start. UFW user rules persist.
- ARM translation absent (`abilist=x86_64,x86`); Play sign-in/certification are user-side follow-ups.

## 6. Daily commands (autostart stays OFF)
```bash
sudo systemctl start waydroid-container.service
systemctl --user start wd-venus.service
waydroid session start
waydroid status
waydroid app launch com.android.settings   # or com.android.vending
sudo waydroid shell dumpsys SurfaceFlinger | grep GLES
waydroid session stop
sudo systemctl stop waydroid-container.service
systemctl --user stop wd-venus.service
```

## 8. ARM translation — WORKING (2026-10-11)
- Installed ONLY `libhoudini` via audited `casualsnek/waydroid_script` @ `48dbfaf` (Android 13 archive `2f8f088`, MD5 `37fe0899…` re-hashed independently; Intel proprietary, expiry 2028-07-01).
- Backup: Snapper #866 + `~/waydroid-backup-pre-houdini-20261011/` (1.8G verified). No Magisk/Zygisk/libndk; base images untouched (overlay-only + 7 props).
- Live proof: `abilist=x86_64,x86,arm64-v8a,armeabi-v7a,armeabi`, `native.bridge=libhoudini.so`, binfmt `arm_exe/arm_dyn/arm64_exe/arm64_dyn` registered.
- Functional proof: Subway Surfers (`com.rioo.runnersubway`) running translated — Houdini 14.0.0 `GoogleGame_com1.3` init OK, process maps contain `libhoudini.so` + 64-bit `vulkan.virtio.so` (ARM → x86_64 → Venus NVIDIA). Translated system procs: media provider, Google search, GMS.
- Note: one `hwcomposer` SIGSEGV (Wayland-dispatch mutex) occurred post-install and felled a boot's windows; cleared by container restart, crash-free since. Causation vs Houdini not established (HWC flaky before).
- Houdini uninstall: `cd /tmp/opencode/waydroid_script && sudo venv/bin/python3 main.py --android-version 13 remove libhoudini`.

## 7. Full rollback
```bash
systemctl --user disable --now wd-venus.service
sudo systemctl disable --now waydroid-container.service
paru -R waydroid-nvidia-bin
sudo rm -rf /var/lib/waydroid ~/.local/share/waydroid   # destroys Android data
sudo snapper -c root undochange <pre-install-id>..0
```
