#!/usr/bin/env bash
# meet-toggle.sh - Toggle Presentation Mode ON and OFF
set -eo pipefail

HAS_HEADLESS=$(swaymsg -t get_outputs | jq -r '.[].name | select(startswith("HEADLESS-"))' | head -n 1)

if [[ -n "$HAS_HEADLESS" ]] || pgrep -x "wl-mirror" > /dev/null; then
    exec "$HOME/.local/bin/meet-stop.sh"
else
    exec "$HOME/.local/bin/meet-start.sh"
fi
