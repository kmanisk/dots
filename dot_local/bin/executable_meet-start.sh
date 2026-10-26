#!/usr/bin/env bash
# meet-start.sh - Start clean virtual presentation mode for Sway
set -eo pipefail

# 1. Resolve or spawn HEADLESS output dynamically
HEADLESS_OUT=$(swaymsg -t get_outputs | jq -r '.[].name | select(startswith("HEADLESS-"))' | head -n 1)

if [[ -z "$HEADLESS_OUT" ]]; then
    swaymsg create_output
    HEADLESS_OUT=$(swaymsg -t get_outputs | jq -r '.[].name | select(startswith("HEADLESS-"))' | head -n 1)
fi

if [[ -z "$HEADLESS_OUT" ]]; then
    notify-send -a "Presentation Mode" -u critical -r 8899 -i dialog-error "Presentation Mode: ERROR" "Failed to create headless display"
    exit 1
fi

# 2. Configure 1:1 resolution matching eDP-1 panel (1920x1200)
swaymsg output "$HEADLESS_OUT" resolution 1920x1200 position 1920 0

# 3. Move workspace 1 to the headless display and focus it
swaymsg workspace 1 output "$HEADLESS_OUT"
swaymsg workspace 1

# 4. Launch wl-mirror on eDP-1 if not already running
if ! pgrep -x "wl-mirror" > /dev/null; then
    ( wl-mirror "$HEADLESS_OUT" || wl-mirror -b screencopy "$HEADLESS_OUT" ) > /dev/null 2>&1 &
fi

# 5. Display notification
notify-send -a "Presentation Mode" -u normal -t 4000 -r 8899 -i video-display \
    "Presentation Mode: ON" \
    "Sharing Target: ${HEADLESS_OUT}\nMeetingly AI overlay cloaked"
