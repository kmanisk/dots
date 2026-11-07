# Steam Client Runtime Policy

This document owns workstation-specific Steam client launch and UI-rendering behavior. Game-specific Proton/launch policy remains under each game's own `docs/gaming/` directory.

## Managed launcher

`~/.local/bin/steam` (chezmoi source: `dot_local/bin/executable_steam`) is the normal Steam client wrapper.

It keeps the existing workstation policies:

- strips inherited PRIME/NVIDIA offload variables unless `STEAM_DGPU=1` explicitly opts the client into them,
- refreshes X11/XWayland cursor fallbacks through `ensure-xcursor-fallbacks`,
- keeps Steam desktop UI scaling at `1.0` so Sway remains the single desktop-scale authority.

## CEF / steamwebhelper acceleration

As of 2026-11-01, Steam Chromium/CEF hardware acceleration must remain enabled by default on this NVIDIA + Sway system.

Live diagnosis of the `Loading user data...` stall found:

- no material disk I/O wait, memory pressure, download activity, or Steam-network latency problem,
- Steam's persisted `GPUAccelWebViewsV3` was `0`,
- the old wrapper also unconditionally added `-cef-disable-gpu -cef-disable-gpu-compositing`,
- two `steamwebhelper` processes then sustained roughly 100% and 86% CPU while the UI remained slow.

A controlled restart with `GPUAccelWebViewsV3=1` and no forced software-CEF flags produced an NVIDIA ANGLE renderer and enabled GPU compositing, rasterization, video decode, and WebGL. The busiest CEF process during startup fell to roughly 16% CPU instead of consuming a full core continuously, and after settling the busiest webhelpers were about 4.3%, 3.5%, and 2.5% CPU.

The wrapper therefore no longer disables CEF GPU acceleration by default. The old software path remains only as an explicit diagnostic fallback:

```sh
STEAM_CEF_SOFTWARE=1 steam
```

Do not make that fallback the default again without reproducing a current cursor/hitbox failure and comparing it against the hardware-accelerated path. Steam's application-owned preference lives in `~/.steam/registry.vdf` as `GPUAccelWebViewsV3`; it is runtime/user state and is intentionally not managed by chezmoi.

## Validation

When changing this launcher, verify all of the following:

```sh
bash -n ~/.local/bin/steam
grep GPUAccelWebViewsV3 ~/.steam/registry.vdf
ps -eo pid,pcpu,args | grep '[s]teamwebhelper'
tail -n 100 ~/.local/share/Steam/logs/webhelper_gpu.txt
```

The normal path should not show `--disable-gpu` or `--disable-gpu-compositing` in the primary webhelper launch command, and `webhelper_gpu.txt` should report `gpu_compositing` and `rasterization` as enabled.
