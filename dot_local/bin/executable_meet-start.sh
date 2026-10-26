#!/usr/bin/env bash
# meet-start.sh - Start clean virtual presentation mode for Sway
set -eo pipefail

# 1. Reuse or create HEADLESS output dynamically
HEADLESS_OUT=$(swaymsg -t get_outputs | jq -r '.[].name | select(startswith("HEADLESS-"))' | head -n1)
if [[ -z "$HEADLESS_OUT" ]]; then
    swaymsg create_output
    HEADLESS_OUT=$(swaymsg -t get_outputs | jq -r '.[].name | select(startswith("HEADLESS-"))' | head -n1)
fi

if [[ -z "$HEADLESS_OUT" ]]; then
    notify-send -a "Presentation Mode" -u critical -r 8899 -i dialog-error "Presentation Mode: ERROR" "Failed to create headless display"
    exit 1
fi

# 2. Match eDP-1 panel resolution dynamically
read -r W H < <(swaymsg -t get_outputs | jq -r '.[] | select(.name=="eDP-1") | "\(.current_mode.width) \(.current_mode.height)"')
swaymsg output "$HEADLESS_OUT" resolution "${W}x${H}" position "$W" 0

# 3. Move work workspace 1 to the headless display
swaymsg "[workspace=1] move workspace to output $HEADLESS_OUT"

# 4. Launch wl-mirror (the window rule 'move to output eDP-1' places it on the physical panel)
if ! pgrep -x "wl-mirror" > /dev/null; then
    wl-mirror "$HEADLESS_OUT" > /dev/null 2>&1 &
fi

# 5. Ensure keyboard focus is on Workspace 1 so typing goes to your active apps
sleep 0.3
swaymsg "[workspace=1] focus"

# 6. Display notification (synchronous replace ID for Mako)
notify-send -a "Presentation Mode" -u normal -t 4000 -r 8899 -i video-display \
    "Presentation Mode: ON" \
    "Sharing Target: ${HEADLESS_OUT} (${W}x${H})\nMeetingly AI overlay cloaked"
