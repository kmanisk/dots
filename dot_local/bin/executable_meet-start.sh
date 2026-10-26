#!/usr/bin/env bash
# meet-start.sh - Start clean virtual presentation mode for Sway
set -eo pipefail

# 1. Reuse or create HEADLESS output
HEADLESS_OUT=$(swaymsg -t get_outputs | jq -r '.[].name | select(startswith("HEADLESS-"))' | head -n1)
if [[ -z "$HEADLESS_OUT" ]]; then
    swaymsg create_output
    HEADLESS_OUT=$(swaymsg -t get_outputs | jq -r '.[].name | select(startswith("HEADLESS-"))' | head -n1)
fi

if [[ -z "$HEADLESS_OUT" ]]; then
    notify-send -a "Presentation Mode" -u critical -r 8899 -i dialog-error "Presentation Mode: ERROR" "Failed to create headless display"
    exit 1
fi

# 2. Match eDP-1 resolution dynamically
read -r W H < <(swaymsg -t get_outputs | jq -r '.[] | select(.name=="eDP-1") | "\(.current_mode.width) \(.current_mode.height)"')
swaymsg output "$HEADLESS_OUT" resolution "${W}x${H}" position "$W" 0

# 3. Move work workspace to the headless output
swaymsg workspace 1 output "$HEADLESS_OUT"

# 4. Return focus to eDP-1 so wl-mirror opens on the physical panel
swaymsg focus output eDP-1 2>/dev/null || swaymsg workspace 2

# 5. Launch wl-mirror (tiled via window rule, not fullscreen)
if ! pgrep -x "wl-mirror" > /dev/null; then
    wl-mirror "$HEADLESS_OUT" > /dev/null 2>&1 &
fi

# 6. Display notification (synchronous replace ID for Mako)
notify-send -a "Presentation Mode" -u normal -t 4000 -r 8899 -i video-display \
    "Presentation Mode: ON" \
    "Sharing Target: ${HEADLESS_OUT} (${W}x${H})\nMeetingly AI overlay cloaked"
