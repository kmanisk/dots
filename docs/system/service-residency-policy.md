# On-demand service residency policy

Current audit: 2026-11-06 (CachyOS / Sway). Primary principles: [`system-philosophy.md`](system-philosophy.md) and [`AGENTS.md`](../../AGENTS.md).

## Rule

Optional applications and lab stacks must not consume memory, CPU, sockets or wakeups between uses. Prefer an executable launcher with clear `start`, `status` and `stop` operations, or a systemd **transient service** that disappears after shutdown. Use socket activation only where its idle overhead is justified. Do not add a polling daemon to enforce this rule. An **actively used** VM, Android container or game is not an unwanted background process; do not kill it during an audit.

For each new application or service:

1. Inspect `systemctl is-enabled` as well as `is-active` (system and user). Installing a package does not mean its service should start at boot.
2. Check the corresponding launcher, user session, and lifecycle cleanup. Require an idle/stopped verification after normal shutdown; avoid using window-close events when clients can replace surfaces during normal operation.
3. Confirm no legacy Docker/Podman/libvirt service is enabled solely for a QEMU/Waydroid use case.
4. Measure before replacing a required daemon. Keep NetworkManager, PipeWire/WirePlumber/DSP, Bluetooth for connected devices, NVIDIA power handling, display controls, xremap and explicitly requested remote access when they provide active features.
5. Document justified resident exceptions; do not turn off unrelated agent tooling, active VMs, or connected peripherals merely because they appear in the process table.

The one-shot, read-only `~/.local/bin/system-residency-audit` (chezmoi `dot_local/bin/executable_system-residency-audit`) prints optional services with active and enabled states plus a WARP package check. `system-residency-audit --strict` exits nonzero on an unexpected persistent state. It is **not** a watchdog, cron job or timer, and intentionally does not auto-stop workloads.

## Verified virtualization baseline

| Module | Boot behavior | Run behavior | Stop behavior |
| --- | --- | --- | --- |
| Nano11 native QEMU | no enabled VM unit | `nano11` starts a transient systemd QEMU unit | shutdown collects transient unit; see `docs/virtualization/nano11-native-qemu.md` |
| X-Lite Micro10 (`win10lab`) | no enabled VM unit | uses transient `win10lab-qemu.service` | stop through its dedicated launcher; no automatic boot |
| Waydroid 0.2 NVIDIA | `waydroid-container.service` disabled | `waydroid-launcher` starts container/session only on demand | `waydroid-stop` ends session, stops container and disables its boot unit; do not infer session state solely from a window |
| Podman/Docker/libvirt | packages/daemons not installed on audited machine | not required for native QEMU | no daemon to keep resident |

The Waydroid **container can be active while its Android UI session is stopped**. This is a runtime state, not proof of boot autostart. Check the owner and stop through `waydroid-stop` when the Android task is finished; do not stop it blindly when the user is starting or using Android.

## Cloudflare WARP retirement

On 2026-11-06 `cloudflare-warp-bin 2026.8.2115-1` was still installed and its `warp-svc.service` was enabled and running despite `warp-cli status` reporting **Registration Missing**. The network had no WARP interface and continued over USB-tethered `enp0s20f0u5`. `warp-svc.service` was stopped and disabled. `warp-taskbar.service` is globally enabled by the installed package but **masked and inactive** in the user session to prevent reactivation.

**Remaining privileged removal:** the WARP package and its unused dependencies are not yet removed. An attempted pre-removal Snapper root snapshot required interactive polkit authentication, so that incomplete attempt was canceled without removing packages. On the laptop, complete removal with a local authenticated terminal:

```bash
sudo snapper -c root create -d 'before removing Cloudflare WARP'
sudo pacman -Rns cloudflare-warp-bin
systemctl --user unmask warp-taskbar.service
```

Check that `systemctl is-active warp-svc.service`, `command -v warp-cli` and `pacman -Q cloudflare-warp-bin` indicate absence after uninstall. Only after confirming the program is gone, review any residual `/var/lib/cloudflare-warp` data before deleting it; no private WARP registration data is included in chezmoi. The `warp-taskbar` local mask is intentionally temporary because package removal also removes the global unit.

Do **not** confuse the Cloudflare WARP VPN daemon with the workstation's independent static DNS resolver configuration. `/etc/systemd/resolved.conf.d/99-custom-dns.conf`, dated 2026-10-19, uses Cloudflare/Google/Quad9 public DNS as part of earlier USB-tethered Jio 5G connectivity tuning; changing it mid-session risks disrupting remote access and provides no persistent-daemon savings. It was not changed during this WARP cleanup.

## Active feature exceptions

The audited machine also runs explicitly configured components such as `desktop-commander.service` for authorized remote control, `bt-keyboard-reconnect` for reliable keyboard input, `asus-speaker-dsp` and PipeWire for audio, and `wl-gammarelay` for active brightness/night-light controls. These are feature dependencies, not interchangeable with WARP or idle VM daemons. Do not change them without subsystem-specific evidence.
