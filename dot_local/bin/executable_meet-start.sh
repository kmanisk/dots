#!/usr/bin/env bash
# meet-start.sh - Start clean virtual presentation mode for Sway (Target: Workspace 2)
set -eo pipefail

TARGET_WS=2

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

# 3. Proactively isolate Meetingly onto physical panel eDP-1 before moving workspaces
swaymsg '[app_id="(?i)^meetingly.*"] move to output eDP-1' 2>/dev/null || true
swaymsg '[class="(?i)^meetingly.*"] move to output eDP-1' 2>/dev/null || true

# 4. Move target workspace (Workspace 2: Brave, editor, terminal) to the headless display
swaymsg "[workspace=${TARGET_WS}] move workspace to output $HEADLESS_OUT"

# 5. Launch wl-mirror if not already running (rule places it tiled borderless on eDP-1)
if ! pgrep -x "wl-mirror" > /dev/null; then
    wl-mirror "$HEADLESS_OUT" > /dev/null 2>&1 &
fi

# 6. Active polling loop: wait for wl-mirror container to appear in the tree (up to 3.0s)
for _ in $(seq 1 30); do
    if swaymsg -t get_tree | jq -r '.. | select(.type?=="con" and .app_id?!=null) | .app_id' | grep -qiE 'wl[-_]mirror|at\.yrlf\.wl_mirror'; then
        break
    fi
    sleep 0.1
done

# 7. Re-verify Meetingly remains exclusively on eDP-1
swaymsg '[app_id="(?i)^meetingly.*"] move to output eDP-1' 2>/dev/null || true
swaymsg '[class="(?i)^meetingly.*"] move to output eDP-1' 2>/dev/null || true

# 8. Return keyboard and window focus to Workspace 2 so typing and new windows route to HEADLESS-OUT
swaymsg "[workspace=${TARGET_WS}] focus"

# 9. Display notification (synchronous replace ID for Mako)
notify-send -a "Presentation Mode" -u normal -t 4000 -r 8899 -i video-display \
    "Presentation Mode: ON" \
    "Sharing Target: ${HEADLESS_OUT} (Workspace ${TARGET_WS})\nMeetingly AI overlay cloaked"
