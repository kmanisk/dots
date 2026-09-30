# CS2 Native Wayland 4:3 Stretched — Fix Log (2026-09-30)

**Result:** 1600x1200 4:3 stretched fullscreen, clean and sharp on the
1920x1200@165Hz panel. Test A passed on first run — test B not needed yet.

**Session:** Sway 1.12 (Wayland) · Intel iGPU scanout · RTX 5050 via PRIME ·
scale 1.0 (`nearest`) · Gamescope off · vkBasalt off · MSAA untouched

**Launch option (Steam):**
```text
/home/manisk/.local/bin/cs2-launch %command%
```

---

## 1. The bug

`~/.local/bin/cs2-launch` parsed `CS2_RES` into `TARGET_W`/`TARGET_H`
(lines 35-45), but only the Gamescope branch used them (`-w/-h`).
The native Wayland branch launched CS2 with flags that contained **no
`-fullscreen -w -h` at all**, so `CS2_RES` was silently dead and the game
never received the requested 4:3 mode — the blur/softness came from the
wrong resolution being scaled, not from AA or the compositor.

## 2. The fix (launcher only)

File: `~/.local/bin/cs2-launch` — three changes, nothing else touched
(Gamescope, MSAA, `scale_filter`, NVIDIA mode, vkBasalt all unchanged):

1. Added `export SDL_VIDEO_WAYLAND_MODE_SCALING=stretch`
   (SDL 3.2+ hint; CS2 ships SDL 3.5.0, so supported; needs compositor
   viewport support, which wlroots provides). Kept
   `SDL_VIDEO_WAYLAND_SCALE_TO_DISPLAY=1`.
2. Default `CS2_RES` changed `1440x1080` → `1600x1200`.
3. `CS2_FLAGS` now includes `-fullscreen -w "$TARGET_W" -h "$TARGET_H"`,
   so the native branch actually requests the parsed resolution.

In-game settings: Aspect Ratio 4:3 · Resolution 1600x1200 · Display Mode
Fullscreen.

## 3. Why 1600x1200

1600/1200 = 1.333 → panel 1920/1200 = 1.6, i.e. 1.2x horizontal stretch
while keeping all 1200 vertical pixels. Maximum 4:3 mode on this panel;
1440x1080 and below throw away vertical resolution for no benefit.

MSAA was deliberately left alone: it resolves inside the render target
and cannot fix blur introduced by the final upscale step.

## 4. Test protocol (A/B, one variable)

- **A:** `MODE_SCALING=stretch` + `SCALE_TO_DISPLAY=1` + 1600x1200 → **PASS,
  sharp.** Stopped here.
- **B (reserved):** flip only `SCALE_TO_DISPLAY` to `0` and re-test.
  SDL documents `=1` can cause rounding-error blur on some configs, so B
  remains the fallback if A had been soft.

## 5. Known context (verified, not changed)

- `game/cs2.sh` pins `SDL_VIDEO_DRIVER=x11` (Valve reverted Wayland-default
  on 7/30/2025 after customer issues); our launcher intentionally overrides
  to `wayland`. Native Wayland CS2 has crash reports upstream
  (ValveSoftware/csgo-osx-linux#4176 notes native-Wayland crashes and
  XWayland/native scaling differences) — unrelated to this scaling fix.
- Sway `scale_filter` resolves `smart` → `nearest` at integer scale 1.0
  (confirmed in `sway/config/output.c` and live `get_outputs`); whether it
  governs the SDL fullscreen viewport path is still an open question, left
  for a future test if softness ever returns.
- Valve #4104 (KDE scale>1.0 oversize fullscreen) is not applicable here
  (we run scale 1.0); not used as evidence.

## 6. Related docs

- [Status & Experience Log](./README.md)
- [VProf Benchmark Telemetry Report](./performance-benchmarks.md)
- Launcher: `~/.local/bin/cs2-launch`
