# CS2 — AsusMuxDgpu Mode: Uncapped FPS + 4:3 Stretched (Confirmed Working)

> **Status:** Confirmed working as of 2026-10-03  
> **Driver:** NVIDIA 615.71.09  
> **CS2 Build:** 11064364  
> **Compositor:** Sway 1.12 / Wayland

---

## TL;DR

| What changed | Result |
|---|---|
| `supergfxctl` switched from **Hybrid** → **AsusMuxDgpu** | FPS became uncapped (200+) |
| Launch option stays `~/.local/bin/cs2-launch %command%` | 4:3 stretch still works |
| No fps_max, VSync, Reflex, MangoHud, or launcher changes needed | — |

---

## Confirmed Working Setup

### Steam Launch Option

```
~/.local/bin/cs2-launch %command%
```

That is the **only** launch option in Steam. All environment configuration is inside the script.

### GPU Mode

```bash
supergfxctl -m AsusMuxDgpu   # requires logout/login to take effect
```

In this mode the RTX 5050 Mobile owns eDP-1 scanout directly (hardware MUX bypasses iGPU).
No cross-GPU presentation hop → FPS is uncapped.

### Environment Stack (set by `cs2-launch`)

| Variable | Value | Purpose |
|---|---|---|
| `SDL_VIDEO_DRIVER` | `wayland` | Native Wayland, not XWayland |
| `SDL_VIDEO_WAYLAND_SCALE_TO_DISPLAY` | `1` | Upscale to 1920×1200 panel |
| `SDL_VIDEO_WAYLAND_MODE_SCALING` | `stretch` | 4:3 pillarbox fill |
| `__VK_LAYER_NV_optimus` | `NVIDIA_only` | Force Vulkan to dGPU |
| `LIBVA_DRIVER_NAME` | `nvidia` | NVIDIA VA-API (AsusMuxDgpu path) |
| `__NV_DISABLE_EXPLICIT_SYNC` | `1` | Workaround for syncobj crash class B |
| `ENABLE_VKBASALT` | `0` | vkBasalt disabled (not needed at native res) |
| `__NV_PRIME_RENDER_OFFLOAD` | **unset** | Not needed — NVIDIA is the display GPU |
| `__GLX_VENDOR_LIBRARY_NAME` | **unset** | Not needed in AsusMuxDgpu mode |

### CS2 Flags (set by `cs2-launch`)

```
-vulkan -fullscreen -w 1600 -h 1200 -threads 7 -mainthreadpriority 2 -nojoy -novid
+fps_max 0 +fps_max_ui 0
```

Resolution default: `1600×1200` (4:3). Override via `CS2_RES=1440x1080 cs2-launch ...`.

### Sway Integration

`cs2-launch` activates `mode "gaming"` on launch and restores `mode "default"` on exit.  
The CS2 window rule `shortcuts_inhibitor enable` passes all keys directly to CS2 —
most Sway keybinds are intentionally suppressed while in-game. Use `Alt+Shift+F` to escape.

---

## Root Cause of the Previous ~165 FPS Cap (Hybrid Mode)

In **Hybrid** mode:

```
NVIDIA RTX 5050 → renders frames
        ↓  (PRIME offload copy)
Intel UHD Graphics → owns eDP-1 scanout → 165 Hz KMS flip
```

SDL 3 native Wayland presents via the Wayland Vulkan WSI. The PRIME copy back to the Intel
display controller introduced a FIFO-style sync boundary, locking presentation to one frame
per 165 Hz interval (~6.06 ms).

In **AsusMuxDgpu** mode:

```
NVIDIA RTX 5050 → renders frames → owns eDP-1 scanout
```

No cross-GPU hop. NVIDIA Vulkan WSI presents frames as fast as the GPU produces them.
`adaptive_sync off` is set on eDP-1 (prevents backlight PWM flicker), but the GPU
submits frames without a FIFO ceiling.

### What was definitively ruled out

| Theory | Evidence against |
|---|---|
| NVIDIA Reflex capping FPS | A/B test: Reflex ON avg 166.2 FPS, Reflex OFF avg 164.8 FPS — identical within variance |
| `fps_max` convar | Confirmed `"fps_max" "0"` in `cs2_machine_convars.vcfg` |
| VSync in CS2 | Confirmed `"setting.mat_vsync" "0"` in `cs2_video.txt` |
| MangoHud or vkBasalt limiting | Both disabled / passthrough during tests |
| Sway gaming mode keybind issue | Keybinds suppressed by design (shortcuts_inhibitor), not a bug |
| FPS jumping when CS2 console opens | Expected — Vulkan swapchain recreates in non-FIFO mode for the overlay surface |

---

## Crash Investigation Summary

Two distinct crash classes were found in `~/.local/share/Steam/logs/console-linux.txt`.

### Class A — SIGSEGV (PID 11814, 2026-10-01 23:51:49 IST)

- **Site:** `libengine2.so` offset `+0x4c7072`, instruction `call *0x98(%rdx)` with `%rdx = NULL`
- **Context:** GDB string at crash site: `"id-match-mvp-map_283"` → Panorama end-of-round MVP/map UI
- **Classification:** CS2 engine application bug — NULL vtable dereference in Panorama UI transition
- **GPU/kernel involvement:** None. Not an OOM, not a GPU fault.
- **Reproducibility:** Happened once, correlates with CS2 build 11064364 update completing 3 minutes prior — correlational only, not proven causal
- **Workaround:** None; upstream CS2 issue. File on [Valve's CS2 GitHub tracker](https://github.com/ValveSoftware/counter-strike) if it recurs

### Class B — Wayland syncobj fatal error (Sessions 2026-10-01 00:40, 01:04, 01:35 IST)

- **Exact error:**
  ```
  wp_linux_drm_syncobj_surface_v1#61: error 3: Acquire point set but no buffer attached
  ERROR: Wayland display connection closed by server (fatal)
  ```
- **Mechanism:** SDL 3 native Wayland commits explicit sync acquire points without attaching valid Vulkan frame buffers during `SDL_VIDEO_WAYLAND_MODE_SCALING=stretch` surface transitions. Sway (wlroots) enforces the `linux-drm-syncobj-v1` protocol and severs the connection on violation.
- **Pre-existing:** Also occurred Sep 29 and Sep 30 — predates the Oct 1 CS2 update. Not a regression.
- **Valve's own stance:** `game/cs2.sh` explicitly overrides `SDL_VIDEO_DRIVER=x11` with the comment that Wayland has known stability issues.
- **Workaround applied:** `export __NV_DISABLE_EXPLICIT_SYNC=1` in `cs2-launch`
  - Disables `linux-drm-syncobj-v1` negotiation; SDL falls back to implicit sync
  - NVIDIA documents this variable in `egl-wayland` for apps with explicit-sync multi-threaded surface commit problems
  - A/B result: **zero syncobj errors** across all sessions after applying the workaround
  - Caveat: disabling explicit sync can affect frame pacing order; monitor for out-of-order frames or tearing on very high FPS sessions

---

## Quick Reference: CS2 Mode Switching

```bash
# Default (AsusMuxDgpu, Wayland, 1600×1200 stretch)
~/.local/bin/cs2-launch

# Different resolution
CS2_RES=1440x1080 ~/.local/bin/cs2-launch

# XWayland fallback (if Wayland issues arise)
CS2_MODE=x11 ~/.local/bin/cs2-launch

# Via Steam (only option needed in Steam launch options)
~/.local/bin/cs2-launch %command%
```

---

## Related Docs

- [`wayland-43-stretched.md`](./wayland-43-stretched.md) — How 4:3 stretch was first achieved on Wayland (Sep 30)
- [`performance-benchmarks.md`](./performance-benchmarks.md) — VProf data, Reflex A/B, GPU utilization numbers
