# dGPU Mode (AsusMuxDgpu) — Permanent Display Topology + CS2 Findings

**Status:** `AsusMuxDgpu` is the permanent GPU mode on this machine (verified via
`supergfxctl -g`). Hybrid is no longer in use. No reboot/mode-switch needed —
supergfxctl persists the bracketed mode across reboots.

**Date established:** 2026-10-02 · **Sway startup fix:** `SWAY_UNSUPPORTED_GPU=true`
conditional in `~/.local/bin/sway-run` (auto-applies only in `AsusMuxDgpu`).

---

## 1. Topology (current, permanent)

```text
AsusMuxDgpu (MUX switch: NVIDIA owns the panel)

RTX 5050
 ├── renders desktop + games
 └── scans out eDP-1 directly (1920x1200 @ 165Hz)

Intel iGPU
 └── idle (no scanout duties)
```

Previous Hybrid topology (Intel scanout + NVIDIA render) is retired — see §4
for why.

Device nodes after the switch: Intel = `/dev/dri/card1`, NVIDIA = `/dev/dri/card2`
(enumeration shifted; the old `card0` no longer exists). The `WLR_DRM_DEVICES`
Intel pin in `sway-run` now no-ops by design (its `card1 && card0` guard fails),
so Sway auto-selects the NVIDIA device.

---

## 2. Controlled A/B result (same launcher, both modes)

Launcher held constant throughout: `~/.local/bin/cs2-launch %command%`
(native Wayland, 1600x1200, `MODE_SCALING=stretch`, `__NV_DISABLE_EXPLICIT_SYNC=1`,
Reflex OFF, V-Sync OFF, `+fps_max 0`).

```text
Hybrid + native Wayland  → ~165 FPS cap, 4:3 stretch works
dGPU-only + native Wayland → uncapped FPS, 4:3 stretch works
```

**Conclusion:** the ~165 FPS pacing came from the hybrid Intel-scanout /
NVIDIA-render presentation path — not from `fps_max`, VSync, MangoHud,
vkBasalt, Gamescope, Sway `allow_tearing`, Reflex, or any CS2-intrinsic limit.
The launcher was never the variable; the GPU topology was.

Ruled out along the way: needing X11 for stretched 4:3 (native Wayland does
both now), XWayland black-bar tradeoff, present-mode overrides.

---

## 3. Working CS2 combination (current)

```text
1600x1200 stretched → 1920x1200 + uncapped FPS + native Wayland + Sway + RTX 5050
```

Tradeoff accepted: the RTX 5050 now drives desktop/display, so idle/battery
cost is normal dGPU-only behavior (no D3cold desktop, Intel display efficiency
gone). Worth it for this machine's primary purpose (competitive CS2).

---

## 4. Vibrance (current: NVIDIA, archived: Intel CTM)

Active implementation: [`nvidia-vibrance.md`](./nvidia-vibrance.md) —
`nvibrant-bin 1.3.0`, panel = NVKMS connector 2 (`nvibrant 0 0 <val>`),
tested value **800**, one-shot MUX-gated call in `sway-run`, no daemon.

### ARCHIVED: Intel CTM hardware vibrance (Hybrid-era subsystem)

> **Status: ARCHIVED — inactive under dGPU mode, preserved for future use.**
> The Intel CRTC CTM pipeline only affects the panel when the Intel iGPU
> scans out. In `AsusMuxDgpu` the NVIDIA owns eDP-1, so the latched CTM matrix
> has no visible effect. If this machine ever returns to Hybrid, re-enable by
> doing nothing extra — `sway-run` still latches CTM before Sway claims DRM
> master, and `vibrance-ctl` still works. Full design doc (archived):
> [`../archive/intel-hardware-vibrance.md`](../archive/intel-hardware-vibrance.md).

Preserved essentials:

- **Pipeline (Hybrid only):** `DEGAMMA_LUT (33)` → `CTM (3x3 S31.32)` →
  `GAMMA_LUT (262145)` on Intel CRTC → eDP-1. Zero shader cost, zero FPS drop.
- **Latch mechanism:** `ctm-test --set <val>` runs in `sway-run` /
  `launch-desktop` before the compositor takes DRM master; wlroots preserves
  the CTM across modesets (requires `DRM_CLIENT_CAP_ATOMIC` in the committer).
- **Tooling (keep installed):**
  - `~/.local/bin/ctm-test` (`--inspect` read-only, `--set <s>`, `--identity`,
    `--diagnose`, `--saturation`) — source: `~/.local/bin/ctm-test.c`
  - `~/.local/bin/vibrance-ctl` (`get` / `set <val> [-r]` / `off`), state in
    `~/.config/vibrance`
  - Profiles: `~/.config/sway/vibrance-1.2/1.3/1.4.icc` (dormant ICC path)
- **Reactivation check (if ever needed):** switch to Hybrid → confirm Intel
  owns eDP-1 (`modetest -M i915`) → `vibrance-ctl set 1.3 -r` → verify with
  `ctm-test --inspect`.
