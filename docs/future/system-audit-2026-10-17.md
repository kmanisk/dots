# System Audit — 2026-10-17

**Target machine:** ASUS TUF Gaming F16 (FX608JH) · Intel Core i5-13450HX · GeForce RTX 5050 Mobile
**OS/Desktop:** CachyOS rolling (x86-64-v3, kernel 7.2.9-2-cachyos, preempt=full) · Sway (Wayland) · AsusMuxDgpu
**Method:** Live inspection (read-only audit). Approved fixes applied on 2026-10-17 are recorded in section 1.1.

---

## 1. Executive Summary

| # | Finding | Priority | Impact | Status |
|---|---|---|---|---|
| 1 | Duplicate Bluetooth auto-connect: system oneshot holds boot transaction 45.3s, user daemon polls every 20s forever (8,600+ failed connect attempts/day) | P1 | Idle power, journal spam, boot metric inflation | Applied 2026-10-17 |
| 2 | Btrfs never scrubbed (`no stats available`), `btrfs-scrub@.timer` disabled | P1 | Silent bitrot detection absent on 123 GiB data | Applied 2026-10-17 |
| 3 | MangoHud.conf is not immutable — RULE 9 unenforced (`lsattr` shows no `i` flag) | P1 | Goverlay/GUI tools can overwrite protected config | Applied 2026-10-17 |
| 4 | 240 MB initramfs (131.77 MiB uncompressed early cpio, mostly legacy NVIDIA GSP firmware) drives the 12.4s GRUB loader time | P2 | ~6-8s boot delay per boot | Pending (optional experiment) |
| 5 | Root filesystem 84% full; 4.3 GB pacman cache, 6 GB `~/.cache`, 11 orphans | P3 | Space headroom, Btrfs performance | Partial: cache already at keep-2 policy, nothing prunable |
| 6 | Docs drift: GRUB timeout, `chattr +C` on NTFS claim | P3 | Documentation accuracy | Pending |

**Verdict:** The system is healthy and already well-optimized (0 failed units, 0 pending updates, clean GPU/power stack). The three P1 items above were the only genuine defects found; everything else is headroom management.

---

## 1.1 Applied 2026-10-17 (Post-Audit Actions)

Snapshot baseline: root `#963` (`pre-audit-fixes-20261017`).

### Bluetooth deduplication + backoff (finding 1)
- Removed the redundant system unit: `bt-autoconnect-q20i.service` disabled, unit file deleted (`/etc/systemd/system/`), `daemon-reload` done.
- Boot verification (2026-10-17 15:46 reboot): userspace startup 48.4s -> 4.3s, total boot 75.0s -> 26.0s (9.8s firmware + 7.6s loader + 0.6s kernel + 3.7s initrd + 4.3s userspace), 0 failed units, `systemd-analyze blame` no longer lists the unit. Note: the loader delta (12.4s -> 7.6s) compares a cold boot to a warm reboot with the 240 MB initramfs unchanged, so treat loader variance accordingly (trim still pending, finding 4).
- Fresh-boot liveness: one failed attempt (Boult, powered off), then dormant once the Q20i connected (audio confirmed RUNNING on `bluez_output`). `Host is down` entries: 1 per boot in this pattern vs 36 per 10 minutes before.
- Patched the user daemon via chezmoi (`dot_local/bin/executable_bt-autoconnect`, applied with `chezmoi apply`):
  - Exponential backoff per failed scan cycle: 20s -> 40 -> 80 -> 160 -> 300s cap; reset on device disconnect, adapter power-on, and resume from sleep.
  - Fixed a latent bug: the 1-2s quick-check callbacks returned `True`, which promoted `timeout_add_seconds(1/2, ...)` sources into repeating 1-2s timers stacking on top of the 20s poll.
- Verified cadence from bluetoothd log: attempts at 11:16:44/49, 11:17:04/10 (+20s), 11:17:44/50 (+40s), 11:19:04/10 (+80s) — gaps widen as designed. Steady state: <= 24 attempts/hour vs 360+/hour before (~93% reduction).
- Note: daemon verbose lines did not surface in the user journal even before the patch (`StandardOutput=journal`, stdout fd is the journald socket). Live state is queryable with `~/.local/bin/bt-autoconnect -s`. Non-blocking observability quirk.

### Btrfs scrub (finding 2)
- `btrfs scrub start /` completed: 122.98 GiB in 36s (3.42 GiB/s), **no errors found**.
- `btrfs-scrub@-.timer` enabled (monthly, persistent); next fire 2026-11-07.

### MangoHud immutability (finding 3)
- `chattr +i` applied; write test fails with `Operation not permitted`; `chezmoi status` clean.
- Caveat: `chezmoi apply` will fail for this file if its source changes — run `sudo chattr -i`, edit, apply, then re-lock with `+i`.

### Cache prune (finding 5, partial)
- `paccache -rk2` and `paccache -ruk0`: no candidate packages found. The 4.3 GB holds only current+previous versions of installed packages (largest: `jdk-openjdk` 408M, `proton-cachyos-slr` 354M, `nvidia-utils` 315M, `linux-cachyos` 161M). Cache is already at policy; the next lever is `-rk1` (reduces downgrade ability — not applied by choice).

### Still pending
- Initramfs slimming (finding 4): optional experiment; requires snapshot + reboot test with a fallback boot path.
- Partition expansion: offline (live USB) task per `future-plans.md`; unchanged.
- Docs drift (finding 6): not yet corrected.

---

## 2. Verified Healthy (Leave As-Is)

| Area | Verified State |
|---|---|
| Failed systemd units | 0 system + 0 user |
| Pending package updates | 0 (fully synced) |
| Kernel | 7.2.9-2-cachyos, x86-64-v3, PREEMPT_DYNAMIC (full) |
| Memory architecture | zram 15.2G zstd swap (priority 32767), systemd-oomd active, THP=madvise |
| GPU power | RTX 5050 in P8 idle, 3.8W, 43 °C, nvidia-open-dkms 615.78.08, `nvidia_drm.modeset=Y`, `fbdev=Y` |
| Backlight | `nvidia_0` sysfs device works with `acpi_backlight=native` + `EnableBrightnessControl=1` |
| NVMe | SMART PASSED, 6% wear, 43 °C composite, no AER/IO errors |
| Filesystem options | Btrfs `noatime,compress=zstd:1` on all subvolumes, quota/qgroups off (no overhead) |
| Boot to desktop | `graphical.target` reached at 3.9s (autologin path is fast) |
| Sway config | `sway -C` validates (only the expected proprietary-NVIDIA notice) |
| Tearing policy | Correct implementation: output-level `allow_tearing yes` + per-window rules. (Sway requires both output and application permission; games-only as intended.) |
| `max_render_time off` | Deliberate, documented latency choice — benchmark-only candidate |
| `adaptive_sync off` | Deliberate (flicker mitigation on this panel) — keep |
| CPU pinning | `cs2-launch` correctly uses `taskset -c 0-11` (P-cores) with gamescope/gamemoderun |
| Event-driven helpers | `game-workspace-daemon` and `sway-idle-guard` are flock-protected, Sway-IPC driven, zero-polling |
| updatedb | Prunes `/mnt` — NTFS Games partition is not indexed |
| fstrim | `fstrim.timer` enabled |
| Scheduler | BORE kernel default; scx_loader correctly disabled (no stacked schedulers) |

---

## 3. P1 Findings — Action Required

### 3.1 Bluetooth: duplicate mechanisms + perpetual 20s polling loop

**Evidence:**
- `/etc/systemd/system/bt-autoconnect-q20i.service` (enabled): oneshot with `ExecStartPre=/bin/sleep 5` + up to 5 `bluetoothctl connect` attempts with 4s sleeps. Measured duration: **45.262s** in `systemd-analyze blame`. This inflates the reported "userspace" boot time from ~3.9s to 48.4s.
- `~/.local/bin/bt-autoconnect` (user service, enabled): duplicates Q20i handling ("BassBox & Q20i"), `POLL_INTERVAL_SEC = 20`, GLib timer calls `attempt_connect_all_disconnected()` every 20s indefinitely.
- Journal this boot (~10 minutes sample): **36x** `bluetoothd: profiles/audio/avdtp.c:avdtp_connect_cb() connect to ... Host is down (112)` for `B0:38:E2:78:9B:FE` (Q20i) and `9E:74:98:79:5D:15` (Boult BassBox), continuing nonstop.
- Extrapolated: ~8,600 failed HCI connect attempts/day, each waking the BT radio and writing journal entries — a direct violation of the zero-idle-wakeup philosophy.

**Fix (pending):**
1. Remove the redundant system unit: `systemctl disable --now bt-autoconnect-q20i.service` then delete `/etc/systemd/system/bt-autoconnect-q20i.service`.
2. Add exponential backoff to the user daemon: per-device attempt interval doubles after each failure (20s → 40 → 80 → 160 → 300s cap), reset on success, adapter power-on, or resume from sleep. Optionally make it event-driven on BlueZ `org.bluez.Device1` D-Bus signals instead of a timer.
3. Expected result: boot transaction closes in ~4s; BT radio idle noise reduced by ~95%; zero functional loss (user daemon already covers Q20i).

### 3.2 Btrfs scrub never run

**Evidence:** `sudo btrfs scrub status /` → `no stats available`. `btrfs-scrub@.timer` exists ("Monthly Btrfs scrub on %f", `OnCalendar=monthly`, `Persistent=true`) but is disabled.

**Fix (pending):**
```bash
sudo btrfs scrub start -B /              # one-time verification pass (123 GiB, runs in background)
sudo systemctl enable --now btrfs-scrub@-.timer
```
Notes: scrub is read-only with respect to data; metadata is dup'd (ratio 2.00) and snapshots exist, so detected corruption is recoverable if caught early. Best run on AC.

### 3.3 MangoHud protection not enforced

**Evidence:** `lsattr ~/.config/MangoHud/MangoHud.conf` shows no immutable flag, contradicting RULE 9 (GUI tools such as Goverlay can overwrite it).

**Fix (pending):**
```bash
sudo chattr +i ~/.config/MangoHud/MangoHud.conf
```
To edit later: `sudo chattr -i <file>`, edit, re-apply `+i`.

---

## 4. P2 — Boot Time: 12.4s GRUB Loader Is Initramfs-Bound

**Measured breakdown:** firmware 9.8s + loader 12.4s + kernel 0.6s + initrd 3.7s + userspace 48.4s (userspace dominated by 3.1 above).

**Root cause:** `/boot/initramfs-linux-cachyos.img` is **240 MB** on disk:
- Early cpio: 131.77 MiB, **uncompressed**, containing 346 NVIDIA firmware entries + microcode.
- Main cpio: 107.54 MiB compressed (188.96 MiB raw, zstd).
- Largest items: `ucodes_ga10x.bin` 56.8M, `ga102/gsp/gsp-570.144.bin.zst` 50.5M, `gsp_ga10x.bin` 26.4M, `ga102/gsp/gsp-535.113.01.bin.zst` 25.6M, `gsp_tu10x.bin` 22.4M, `tu102/gsp` 13.7M + 12.9M, plus i915/xe firmware and modules pulled by the `kms` hook.

GRUB must read all 240 MB through UEFI block I/O at every boot; that is the entire loader delay. GRUB_TIMEOUT is already 1s.

**Contributing factors:**
1. The `kms` hook adds all DRM drivers (i915, xe, nouveau) and places GPU firmware into the uncompressed early cpio — redundant here because `MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)` already provides early KMS for this dGPU-only machine.
2. Firmware payload includes legacy/foreign-architecture blobs never loaded on GB207: Turing `tu10x` variants and version-suffixed GSP files for driver branches 535.113.01 / 570.144.

**Fix (pending, requires snapshot + reboot test):**
1. Remove `kms` from `HOOKS` in `/etc/mkinitcpio.conf` (keep `MODULES` nvidia set; keeps DS3 Plymouth working on the dGPU).
2. Optionally exclude dead firmware via `/etc/pacman.conf` `NoExtract` patterns for `usr/lib/firmware/nvidia/ga102/gsp/gsp-535.*`, `gsp-570.*`, and `usr/lib/firmware/nvidia/tu102/*`.
3. Rebuild: `sudo mkinitcpio -P`, verify with `lsinitcpio -a`, then reboot and re-measure `systemd-analyze`.
4. Expected: 240 MB → ~100-140 MB; loader 12.4s → ~5-7s. Keep the existing Btrfs snapshot as rollback; verify Plymouth renders at boot.

---

## 5. P3 — Storage Headroom (Root 84% Full)

**Current:** `/` 151G total, 124G used, 25G free; device unallocated 9.98GiB. Btrfs write performance degrades as allocation tightens.

| Item | Size | Recommended Action |
|---|---|---|
| `/var/cache/pacman/pkg` | 4.3G | `sudo paccache -rk2` (keep 2 versions; ~2-3G recovered) |
| `~/.cache` | 6.0G | Brave 1.5G, uv 1.2G, nvidia 984M, makepkg 923M, ccache 232M — clear selectively (`uv cache clean`, remove makepkg artifacts) |
| Orphans | 11 pkgs | Review list below before removal |
| `~/.local/share/Steam` | 47G | `common` 34G, `compatdata` 13G (prefixes for installed games; grows with every Proton game — prune via Steam uninstall only) |
| Snapshots | root 17 / home 4 | `snapper-cleanup` handles numbered ones; review stale manual pre/post pairs from Oct 10-15 if space is needed |
| Partition expansion | pending | The 150 → 210+ GiB expansion in `future-plans.md` is now the structural fix — prioritize it |

**Outcome 2026-10-17:** `paccache -rk2` and `-ruk0` found no candidates — the cache already holds only current+previous versions of installed packages. Remaining levers: `-rk1`, selective `~/.cache` clears, and the partition expansion above.

**Orphan list (`pacman -Qtdq`):** `bun cmake maturin meson portmidi python-installer sdl_mixer sdl_ttf spirv-headers vulkan-headers zip`
Note: `cmake`, `meson`, `maturin`, `python-installer` are common AUR build dependencies — keep them if you build AUR packages. The rest are typically safe to remove with `pacman -Rns`.

---

## 6. Benchmark-Only Candidates (from performance-audit-plan.md)

These were re-confirmed against the live system; none should be applied without measurement:

| Candidate | Current State | Test Method |
|---|---|---|
| `max_render_time` | `off` (all outputs) | `swaymsg output eDP-1 max_render_time 1` (then 2, 3, off) during CS2, compare frametimes |
| CPU EPP | `balance_power` (intel_lpmd auto) | A/B `echo performance \| sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference` during CS2; watch 1% lows |
| PipeWire quantum | 512 (deliberate, BT stability) | A/B 256 only on the wired `sink.peace_gaming` route; monitor xruns |
| Kernel variant | linux-cachyos (BORE) | Consider `linux-cachyos-eevdf` A/B; do not stack scx schedulers (scx_loader stays disabled) |
| Renderer | GLES2 default | Do not switch to Vulkan without isolated testing |

---

## 7. Documentation Drift Found

| Document | Claim | Reality |
|---|---|---|
| `docs/bootloader/dark-souls-boot.md` | GRUB timeout 3 | `/etc/default/grub` has `GRUB_TIMEOUT=1` |
| `docs/system/system-philosophy.md` | `chattr +C` applied to `/mnt/Games/SteamLibrary` | `/mnt/Games` is NTFS3; `chattr` is inapplicable. Only `~/.local/share/Steam/steamapps/compatdata` actually carries `+C` (verified). Steam games live on the NTFS partition and on the internal Btrfs library |
| `docs/system/future-plans.md` | Partition expansion plan | Still accurate and now urgent (84% full) |

---

## 8. Fix Playbook (Ordered, Snapshot First)

Steps 1-4 below were executed on 2026-10-17 (outcomes in section 1.1); step 5 remains an optional experiment.

```bash
# 0. Snapshot first (per AGENTS.md policy)
sudo snapper -c root create -d "pre-system-audit-fixes-20261017"

# 1. Bluetooth deduplication
sudo systemctl disable --now bt-autoconnect-q20i.service
sudo rm /etc/systemd/system/bt-autoconnect-q20i.service
sudo systemctl daemon-reload
# Then patch ~/.local/bin/bt-autoconnect with exponential backoff (see 3.1)
systemctl --user restart bt-autoconnect.service

# 2. Btrfs scrub
sudo systemctl enable --now btrfs-scrub@-.timer
sudo btrfs scrub start -B /

# 3. MangoHud immutability
sudo chattr +i ~/.config/MangoHud/MangoHud.conf

# 4. Storage headroom
sudo paccache -rk2
# Review orphans before: pacman -Rns <list>

# 5. Initramfs slimming (requires reboot test, do separately)
#    - Remove kms hook from /etc/mkinitcpio.conf
#    - Optional firmware NoExtract in /etc/pacman.conf
#    - sudo mkinitcpio -P && lsinitcpio -a /boot/initramfs-linux-cachyos.img
#    - Reboot, verify Plymouth + systemd-analyze, keep snapshot as rollback
```

**Verification after each step:**
- `systemctl --user status bt-autoconnect.service` and 5-minute journal watch (`journalctl -f | grep "Host is down"` should go quiet).
- `sudo btrfs scrub status /` shows completed pass with `Error summary: no errors found`.
- `systemd-analyze blame | head` no longer lists bt-autoconnect-q20i; userspace drops to ~4s.
- `df -hT /` shows improved headroom.
- After reboot post-initramfs change: `sway -C`, Plymouth splash visible, `systemd-analyze` loader time reduced.

---

## Appendix — Raw Measurements

- `systemd-analyze`: 9.841s firmware + 12.414s loader + 0.613s kernel + 3.741s initrd + 48.422s userspace; graphical.target @3.901s.
- `systemd-analyze blame`: bt-autoconnect-q20i.service 45.262s (top entry).
- `lsinitcpio -a`: Early CPIO 131.77 MiB, Size 107.54 MiB, uncompressed 188.96 MiB, zstd, 38 modules.
- `journalctl -b | grep -c "Host is down"`: 36 (10-minute window).
- `swapon --show`: /dev/zram0 partition 15.2G, priority 32767, zstd.
- `btrfs filesystem usage -T /`: 140.02GiB allocated, 122.98GiB used, 24.68GiB free (estimated), metadata ratio 2.00.
- `smartctl`: PASSED, Percentage Used 6%, Critical Warning 0x00.
- GPU: P8, 3.81W, 43 °C, 0% utilization at idle.
- `cat /proc/cmdline`: `quiet splash nowatchdog nvme_load=YES loglevel=3 vt.global_cursor_default=0 i915.enable_psr=0 acpi_backlight=native nvidia.NVreg_RegistryDwords=EnableBrightnessControl=1` (all verified appropriate for AsusMuxDgpu; no obsolete entries identified).
