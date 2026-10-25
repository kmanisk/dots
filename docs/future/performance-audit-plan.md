# Future Plan — CachyOS + Sway Performance Audit (dGPU-only, RTX 5050, 1920x1200@165Hz)

> Source: performance direction review for ASUS TUF F16 / i5-13450HX / RTX 5050 Laptop GPU / dGPU-only (AsusMuxDgpu) / Sway 1.12 / wlroots 0.20.x / CachyOS / NVIDIA open driver / Wayland.
> Status: PLAN ONLY — audit first, benchmark individually. Do not apply generic tweak lists.

Given **exact setup — CachyOS + Sway 1.12/wlroots 0.20 + RTX 5050 dGPU-only + 1920×1200 165 Hz** — there are several things worth auditing, but do **not** start throwing generic “Linux gaming tweaks” into the system.

The current Sway stack already has useful performance controls. Sway 1.12 is current upstream and depends on wlroots 0.20.0; it added/updated several modern Wayland features. ([GitHub][1])

## Highest-value things to investigate

### 1. `max_render_time`

Currently disabled, which can be completely reasonable for latency. Sway explicitly recommends starting at `1 ms` and increasing it if frames are dropped; `off` gives the compositor maximum time but can behave differently for latency/frame scheduling. ([GitHub][2])

For 165 Hz display:

```text
165 Hz = 6.06 ms/frame
```

So this is worth **benchmarking**, not blindly changing.

Test:

```text
off
1 ms
2 ms
3 ms
```

and compare frametimes in CS2/GTA IV and normal desktop video.

### 2. `allow_tearing` for games

This is now an actual Sway output/application feature. Sway documents that it can permit immediate page flips for fullscreen applications rather than waiting for vblank. ([GitHub][2])

For a competitive game this could be interesting, but:

```text
latency ↓
frame presentation freedom ↑
tearing may occur
```

Do **not enable it globally**. Test specifically for fullscreen games.

### 3. VRR / adaptive-sync configuration

Previously disabled because of flicker, so do **not simply turn it back on**.

But with the current dGPU-only setup and newer NVIDIA/Sway/wlroots stack, this is one of the things worth retesting.

Sway documents adaptive sync as a latency improvement that can nevertheless flicker on some hardware. ([GitHub][2])

Situation has changed substantially since the hybrid Intel-scanout configuration, so this deserves a fresh test.

### 4. NVIDIA modeset / Wayland path

Keep:

```text
nvidia_drm.modeset=1
```

and don't add random NVIDIA kernel parameters just because they're frequently recommended online.

Current NVIDIA driver/kernel interaction is important because there are active 2026 NVIDIA issues involving Wayland/display hangs and GPU power/display handling. ([GitHub][3])

So on this machine, **stability beats theoretical tweaks**.

### 5. CachyOS scheduler

Worth investigating because CachyOS provides multiple scheduler/kernel variants rather than just one generic kernel.

CachyOS documents:

* BORE
* EEVDF
* BMQ
* POC CPU idle selection
* selectable preemption models
* 1000 Hz default timer
* x86-64-v3/v4 optimized kernels

and specifically offers `linux-cachyos-eevdf`, `linux-cachyos`, `linux-cachyos-lts`, etc. ([CachyOS][4])

For CPU-heavy workload/game mix, **benchmark scheduler choice rather than stacking scheduler tweaks manually**.

## Things to specifically NOT add

Avoid the usual giant tweak lists containing:

```text
vm.swappiness=10
vm.dirty_ratio=...
vm.vfs_cache_pressure=...
transparent_hugepage tweaks
random IRQ affinity scripts
disable SMT
disable mitigations
force performance governor permanently
PCIe ASPM hacks
random NVIDIA environment variables
```

Those often make a machine *look* optimized while providing no measurable improvement — and some can make laptop thermals, power consumption, or stability worse.

Goal:

```text
minimum compositor latency
minimum frame-time variance
no unnecessary background activity
no polling
no daemons
no reloads
no unnecessary disk/D-Bus work
```

## Sway 1.12 HDR / color-management note

Sway 1.12 added HDR10 and color-management support. ([GitHub][1])

**Don't enable these for performance.**

There is already a Sway 1.12 report where switching color profiles changed game performance and frametime behavior on a system using the Vulkan renderer. ([GitHub][5])

So for performance baseline keep the display pipeline boring:

```text
8-bit
normal gamma/color profile
no HDR
no experimental color-management
VRR only if proven stable
```

## Next step: audit prompt for agy

Rather than manually changing anything, use this:

```text
AUDIT ONLY — PERFORMANCE OPTIMIZATION

Audit my current CachyOS + Sway system for measurable performance/latency improvements.

Hardware:
- ASUS TUF F16
- i5-13450HX
- RTX 5050 Laptop GPU
- dGPU-only / AsusMuxDgpu
- 1920x1200 165 Hz internal panel
- Sway 1.12
- wlroots 0.20.x
- CachyOS
- NVIDIA open driver
- Wayland

GOAL:
Maximum desktop responsiveness and minimum frame-time variance for:
- Sway itself
- fullscreen games
- video playback
- normal Wayland applications

Constraints:
- no daemons
- no polling
- no background watchers
- no unnecessary services
- no permanent CPU overhead
- no compositor reloads for runtime changes
- do not sacrifice stability for theoretical gains

Audit these specifically:

1. Sway max_render_time:
   compare off / 1 / 2 / 3 ms conceptually and determine what should actually be benchmarked.

2. Sway adaptive_sync / VRR:
   determine whether my current dGPU-only configuration changes the recommendation compared with my old hybrid Intel-scanout setup.

3. Sway allow_tearing:
   determine whether per-application fullscreen tearing is useful for CS2/GTA IV and how to keep it disabled for everything else.

4. Sway renderer:
   determine whether the current renderer should remain the default or whether Vulkan rendering is worth testing on this NVIDIA hardware.
   Do NOT switch it yet.

5. NVIDIA:
   audit current required Wayland/KMS settings and identify obsolete or harmful parameters.
   Do not add random NVIDIA tweaks.

6. CachyOS kernel:
   identify my currently installed kernel and available CachyOS kernels/schedulers.
   Compare linux-cachyos / EEVDF / BORE / relevant current variants.
   Determine which one is worth benchmarking for this CPU and gaming workload.

7. Kernel parameters:
   audit current cmdline first.
   Only recommend parameters with a documented/likely benefit for this exact hardware.

8. CPU scheduling:
   inspect whether my current scheduler/preemption configuration is already optimal.
   Do not recommend disabling SMT, mitigations, or other major safety/stability features without evidence.

9. GPU power management:
   audit whether dGPU-only mode is configured optimally for latency while plugged in.
   Avoid changes that cause unnecessary power usage when idle.

10. Sway config:
    find expensive or unnecessary configuration features, exec_always commands, scripts, IPC calls, notifications, status-bar polling, file watchers, animations, etc.

11. Cursor/theme switching:
    verify that the new cursor runtime architecture does not introduce compositor stalls or excessive process spawning.

12. Measure where possible:
    distinguish actual measurable performance improvements from theoretical tweaks.

RETURN:
- Current state
- Already optimal settings
- Worth testing
- Do not touch
- Expected benefit
- Risk
- Exact benchmark/test for each candidate

AUDIT ONLY.
Do not modify any files, kernel parameters, Sway config, services, packages, or bootloader settings.
```

There are probably 3–5 worthwhile optimizations in this setup, but benchmark them individually rather than turning the machine into a pile of sysctl/kernel tweaks.

[1]: https://github.com/swaywm/sway/releases?utm_source=chatgpt.com "Releases · swaywm/sway · GitHub"
[2]: https://github.com/swaywm/sway/blob/master/sway/sway-output.5.scd?utm_source=chatgpt.com "sway/sway/sway-output.5.scd at master · swaywm/sway · GitHub"
[3]: https://github.com/NVIDIA/open-gpu-kernel-modules/issues?utm_source=chatgpt.com "Issues · NVIDIA/open-gpu-kernel-modules · GitHub"
[4]: https://wiki.cachyos.org/features/kernel/?utm_source=chatgpt.com "CachyOS Kernel | CachyOS"
[5]: https://github.com/swaywm/sway/issues/9144?utm_source=chatgpt.com "1.12-rc3: app/game performance changes when switching between `gamma22` and `srgb` color profiles · Issue #9144 · swaywm/sway · GitHub"
