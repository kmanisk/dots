# Wayland (Sway) — General Notes

## Input latency is near-native (verified by feel, backed by architecture)

Mouse and keyboard response on Sway feels instant — including in games — and it is not placebo:

- **Shorter input path.** X11 routes input client → X server → app, with round-trips for grabs and focus. Wayland's libinput delivers evdev events straight to the focused client. Fewer hops, no server in the middle.
- **No compositing penalty when it matters.** Sway bypasses the compositor for fullscreen surfaces, so games present near-direct-to-display with `presentation-time` feedback instead of X11's copy-through-compositor path.
- **Gamescope direct scanout.** Nested sessions (e.g. Elden Ring at native res) keep a direct scanout path, so the extra layer costs ~1 frame, not latency feel.
- **500 Hz mouse polling** (`usbhid.mousepoll=2`) removed the X11 event-flood stalls Wine hit at 1000 Hz — input thread stays responsive (see `gaming/elden-ring/wayland-troubleshooting-and-fixes.md` §8).

Where X11 still wins: exotic automation (xdotool-style), some screen readers/IM tooling. Raw latency crown is Wayland's.
