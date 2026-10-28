#!/usr/bin/env bash
# meet-stop.sh - Stop clean virtual presentation mode and restore Sway state
set -eo pipefail

TARGET_WS=2

# 1. Terminate wl-mirror
pkill -x wl-mirror || true

# 2. Restore target workspace (Workspace 2) back to the physical panel eDP-1 and focus it
swaymsg "[workspace=${TARGET_WS}] move workspace to output eDP-1"
swaymsg "[workspace=${TARGET_WS}] focus"

# 3. Unplug all active HEADLESS virtual outputs
for out in $(swaymsg -t get_outputs | jq -r '.[].name | select(startswith("HEADLESS-"))'); do
    swaymsg output "$out" unplug || true
done

# 4. Display notification (synchronous replace ID for Mako)
notify-send -a "Presentation Mode" -u normal -t 3000 -r 8899 -i video-display \
    "Presentation Mode: OFF" \
    "Headless display unplugged\nWorkspace ${TARGET_WS} restored to eDP-1"
