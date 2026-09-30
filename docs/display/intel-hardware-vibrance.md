# Intel Hardware DRM CTM Vibrance & Saturation

## Architecture Overview

This subsystem implements zero-overhead, zero-latency digital vibrance and color saturation on Linux (CachyOS) for hybrid GPU laptops (Intel UHD/Iris Xe + NVIDIA RTX 5050 Mobile).

Instead of using per-frame compositor shaders (SwayFX, post-processing filters, ICC LUT shaders) or game injection (vkBasalt), color transformation is offloaded directly to the **Intel Display Controller Hardware Color Transformation Matrix (DRM CTM)** on the primary display pipe (`CRTC 151` driving `eDP-1`).

```
+-----------------------------------------------------------------------------------+
|                            HYBRID GPU DISPLAY PIPELINE                            |
+-----------------------------------------------------------------------------------+

[ dGPU: RTX 5050 ] (Games / CUDA via prime-run)
        |
        | dma-buf / DRI3 zero-copy blit
        v
[ iGPU: Intel UHD (i5-13450HX) ]
        |
        | Compositor Framebuffer Scanout (Sway / i3 / Plasma)
        v
[ Intel Display Hardware Pipe (CRTC 151) ]
        |
        +---> [ DEGAMMA_LUT ]  (33-point linear degamma ramp)
        |           |
        +---> [ CTM ]          (3x3 S31.32 sign-magnitude saturation matrix)
        |           |
        +---> [ GAMMA_LUT ]    (262145-point gamma ramp; driven by wl-gammarelay-rs)
                    |
                    v
          [ Laptop Panel: eDP-1 ] (1920x1200 @ 165Hz)
```

---

## Performance & Invariants

1. **0.0% FPS Loss & 0 Shader Overhead:**
   Neither the Intel iGPU execution units nor the RTX 5050 CUDA cores execute any shaders for color transformation. Pixels are transformed in hardware silicon during scanout across the eDP link.
2. **Zero Input Latency Penalty:**
   Does not add buffer stages or extra composition passes.
3. **Global Display Scope:**
   Because CTM is applied at the CRTC output stage, it uniformly saturates:
   - All Wayland / Sway workspaces (1 through 10)
   - All X11 / i3 workspaces
   - All prime-run / Proton Vulkan & OpenGL games
   - All TTY Linux virtual terminals (tty1–tty6)
4. **Independent Night Light Coexistence:**
   Night light and brightness tools (`wl-gammarelay-rs`, `wlsunset`) drive the separate `GAMMA_LUT` hardware stage. The `CTM` matrix sits in an independent pipeline stage and is never modified or overwritten by gamma adjustments.

---

## Kernel & DRM Requirements

### 1. `DRM_CLIENT_CAP_ATOMIC` Requirement
When issuing atomic KMS commits via `libdrm`, user space must declare atomic capabilities on the open file descriptor:
```c
drmSetClientCap(fd, DRM_CLIENT_CAP_UNIVERSAL_PLANES, 1);
drmSetClientCap(fd, DRM_CLIENT_CAP_ATOMIC, 1);
```
Without `DRM_CLIENT_CAP_ATOMIC`, the Linux DRM core (`drivers/gpu/drm/drm_atomic_uapi.c:drm_mode_atomic_ioctl`) rejects all atomic commits with `-EINVAL` at the entry point before passing the request to the `i915` driver, producing no output in `dmesg`.

### 2. Rec.709 Sign-Magnitude Matrix Format
The DRM CTM property expects an array of 9 64-bit integers in **S31.32 sign-magnitude format**:
- Bit 63 is the sign bit (`1ULL << 63` for negative numbers).
- Bits 0–62 represent the absolute value scaled by $2^{32} = 4294967296.0$.

Luminance-preserving coefficients (Rec.709):
$$R_{lum} = 0.2126, \quad G_{lum} = 0.7152, \quad B_{lum} = 0.0722$$
$$t = 1.0 - s$$

Matrix structure:
$$\begin{bmatrix}
s + t \cdot R_{lum} & t \cdot G_{lum} & t \cdot B_{lum} \\
t \cdot R_{lum} & s + t \cdot G_{lum} & t \cdot B_{lum} \\
t \cdot R_{lum} & t \cdot G_{lum} & s + t \cdot B_{lum}
\end{bmatrix}$$

For $s = 1.25$:
$$\begin{bmatrix}
 1.196850 & -0.178800 & -0.018050 \\
-0.053150 &  1.071200 & -0.018050 \\
-0.053150 & -0.178800 &  1.231950
\end{bmatrix}$$

---

## Startup & DRM Master Latch

Under Linux DRM, the active compositor (Sway / wlroots) holds exclusive DRM master. Upstream wlroots does not expose a CTM IPC protocol, but **wlroots preserves existing CRTC CTM states across output modesetting**.

Therefore, the hardware matrix is latched immediately before the compositor starts:
1. `~/.local/bin/launch-desktop` and `~/.local/bin/sway-run` invoke:
   ```bash
   ~/.local/bin/ctm-test --set "${VIB_VAL:-1.25}"
   ```
2. `ctm-test` acquires temporary DRM master, writes the `CTM` property blob (and a 33-point linear `DEGAMMA_LUT`), commits atomically to CRTC 151, and releases master.
3. Sway launches, takes DRM master, and renders all workspaces through the latched hardware pipeline.

---

## Tooling & Control

### CLI Controller: `vibrance-ctl`
Located at `~/.local/bin/vibrance-ctl`.

```bash
# Check current configured level and live hardware CTM matrix
vibrance-ctl get

# Set new saturation baseline (saved to ~/.config/vibrance)
vibrance-ctl set 1.25

# Set and instantly cycle Sway to latch into hardware (windows preserved)
vibrance-ctl set 1.30 -r

# Reset back to stock neutral (1.0)
vibrance-ctl off
```

### Low-Level C Utility: `ctm-test`
Located at `~/.local/bin/ctm-test` (source: `~/.local/bin/ctm-test.c`).
- Built with `gcc -O2 -o ~/.local/bin/ctm-test ~/.local/bin/ctm-test.c $(pkg-config --cflags --libs libdrm) -lm`
- `--inspect`: Safe, read-only hardware dump (works inside live Sway).
- `--set <s>`: Commits saturation matrix permanently and exits immediately.
- `--identity`: Resets CTM to NULL (identity).
- `--diagnose`: Runs non-destructive `TEST_ONLY` probe ladder across DRM pipeline stages.
