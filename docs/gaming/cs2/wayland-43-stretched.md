# CS2 Native Wayland 4:3 Stretched — Fix Log (2026-09-30)

## Launcher reliability update, 2026-10-23

The chezmoi-managed `~/.local/bin/cs2-launch` now runs GameMode only after
confirming ananicy-cpp is inactive. If a noninteractive attempt to stop ananicy
fails, the game starts without GameMode. Cleanup restores ananicy only when the
launcher stopped it, and restores the prior ASUS profile rather than always
forcing Balanced. Wayland socket discovery uses a shell socket check; preload
filtering handles an empty result correctly.

Four stubbed scenarios passed: stop failure, successful stop/restore, already
inactive ananicy, and the Gamescope branch. They also checked quoted arguments,
game exit status, prior Quiet profile restoration, direct-MUX environment, and
`ENABLE_VKBASALT=0`. `bash -n` and ShellCheck passed. No game was launched and no
FPS, latency, or frame-pacing improvement is claimed. Existing Steam options for
other games remain unchanged. See [audit and rollback](../../system/workstation-audit-2026-10-23.md).

**Result:** 1600x1200 4:3 stretched fullscreen, clean and sharp on the
1920x1200@165Hz panel. Test A passed on first run — see the 2026-10-17
update (§0): Test B was tested and rejected, and the actual reason Steam
launches still showed black bars was found and fixed.

**Session:** Sway 1.12 (Wayland) · Intel iGPU scanout · RTX 5050 via PRIME ·
scale 1.0 (`nearest`) · Gamescope off · vkBasalt off · MSAA untouched

**Launch option (Steam):**
```text
/home/onyx/.local/bin/cs2-launch %command%
```

`%command%` is mandatory — without it Steam appends the option string to
the game's command line as arguments and the launcher never runs (see §0).
MangoHud is intentionally not used for CS2 (the temporary `MANGOHUD=1` /
`MANGOHUD_CONFIG=...` env tokens from the 2026-10-17 verification were
removed the same day).

---

## 0. Update 2026-10-17 — root cause of the persistent black bars

**Symptom:** normal play (launched from Steam) still showed side black
bars, no MangoHud, no fps flags, even though bench sessions launched from
a terminal looked correct.

**Root cause:** the Steam launch option carried **no `%command%`**.
Verified with `steam -applaunch 730`: the actual process was

```text
cs2.sh -steam MANGOHUD=1 MANGOHUD_CONFIG=vsync=0,fps_limit=0 /home/onyx/.local/bin/cs2-launch
```

— i.e. without `%command%`, Steam appends the option string as *arguments*
to the game command; the launcher never executed on any Steam launch.
`cs2.sh` then set its X11 fallback (`SDL_VIDEO_DRIVER=x11`, set only when
unset) and the game ran XWayland at stored settings — the black-bar
configuration. Terminal launches (bench harness) run the launcher
directly, which is why they looked right.

**Fix (applied 2026-10-17):** Steam → CS2 → Properties → Launch Options:

```text
/home/onyx/.local/bin/cs2-launch %command%
```

With `%command%` present, Steam expands the real game chain
(`steam-launch-wrapper → reaper → SteamLinuxRuntime_sniper → cs2.sh
-steam`) as arguments to the launcher; leading `VAR=value` tokens (used
during the verification below) become real environment variables.

**Verified 2026-10-17 (AsusMuxDgpu, native Wayland):**

- Process chain: `cs2-launch → steam-launch-wrapper → reaper → sniper
  container → pv-adverb → cs2.sh → cs2` (launcher truly runs now).
- `cs2` argv: `-steam -vulkan -fullscreen -w 1600 -h 1200 -threads 6
  -nojoy -novid +fps_max 0 +fps_max_ui 0 +clientport 27006`.
- Game process env: `SDL_VIDEO_DRIVER=wayland`, `SDL_VIDEODRIVER=wayland`,
  `SDL_VIDEO_WAYLAND_MODE_SCALING=stretch`,
  `SDL_VIDEO_WAYLAND_SCALE_TO_DISPLAY=1`,
  `SDL_VIDEO_WAYLAND_ALLOW_TEARING=1`, `LIBVA_DRIVER_NAME=nvidia`,
  `PIPEWIRE_NODE=...` (audio routing). (`MANGOHUD=1` /
  `MANGOHUD_CONFIG=vsync=0,fps_limit=0` were present during this
  verification only — removed later the same day, see header note.)
- Sway node: `app_id="cs2"` (native Wayland — an XWayland window has no
  app_id), client geometry 1600x1200, `rect`/`window_rect` 1920x1200,
  `fullscreen_mode=1`.
- CPU affinity `0-11` (taskset), `gamemode is active` (MangoHud layer was
  mapped during this verification only — no longer used for CS2).
- On exit: asusctl restored to Balanced, `ananicy-cpp` restarted, sway
  binding state back to `default`; `cs2_video.txt` rewritten to
  1600x1200 + `setting.fullscreen 1`.

**SDL hint matrix (tested 2026-10-17 with CS2's bundled SDL 3.5.0,
1600x1200 buffer on 1920x1200 output, pixel-verified):**

| Hints | Result |
|---|---|
| none | 1:1 left-anchored, black bar right |
| `MODE_SCALING=stretch` + `SCALE_TO_DISPLAY=1` (current) | fills edge-to-edge, zero bars |
| `MODE_SCALING=stretch` + `SCALE_TO_DISPLAY=0` (old "Test B") | black bar — rejected |
| `MODE_SCALING=aspect` | black bar |

1440x1080 with the current hints also fills edge-to-edge: the resolution
was never the black-bar variable — whether the launcher ran at all was.

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

- **A:** `MODE_SCALING=stretch` + `SCALE_TO_DISPLAY=1` + 1600x1200 → Softness observed on subpixel text.
- **Gamescope Isolation Test:** Gamescope ruled out. Triggered compositor `SIGABRT` in Intel Mesa `dri_create_fence_fd` and rendered 1:1 unscaled with a 320px black bar.
- **B (Tested 2026-10-17 — REJECTED):** `SCALE_TO_DISPLAY=0` with `MODE_SCALING=stretch` + 1600x1200 leaves a black bar — the viewport stretch is lost. Do not apply; the shipped combo (`SCALE_TO_DISPLAY=1`) is the verified-correct one (see §0).

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
