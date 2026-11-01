# Wayland (Sway) — General Notes

## Input latency is near-native (verified by feel, backed by architecture)

Mouse and keyboard response on Sway feels instant — including in games — and it is not placebo:

- **Shorter input path.** X11 routes input client → X server → app, with round-trips for grabs and focus. Wayland's libinput delivers evdev events straight to the focused client. Fewer hops, no server in the middle.
- **No compositing penalty when it matters.** Sway bypasses the compositor for fullscreen surfaces, so games present near-direct-to-display with `presentation-time` feedback instead of X11's copy-through-compositor path.
- **Gamescope direct scanout.** Nested sessions (e.g. Elden Ring at native res) keep a direct scanout path, so the extra layer costs ~1 frame, not latency feel.
- **500 Hz mouse polling** (`usbhid.mousepoll=2`) removed the X11 event-flood stalls Wine hit at 1000 Hz — input thread stays responsive (see `gaming/elden-ring/wayland-troubleshooting-and-fixes.md` §8).

Where X11 still wins: exotic automation (xdotool-style), some screen readers/IM tooling. Raw latency crown is Wayland's.
## Cursor sizing and display-state ownership (2026-11-01)

The Phinger cursor is currently standardized at **24 px** across the Sway seat, `environment.d`, GTK 3, GTK 4, and GSettings. Cursor size is a display/UI setting only; this change does not alter output mode or compositor scaling. Live verification after the change showed `eDP-1` still running at 1920x1200, approximately 165.004 Hz, with Sway scale 1.30.

Authoritative managed consumers are `dot_config/sway/config.d/10-display.conf`, `dot_config/environment.d/30-cursor.conf`, and the GTK settings files. Use the existing cursor helper for future changes instead of editing one consumer independently, so Sway, GTK, session environment, and XWayland fallback state do not drift.
