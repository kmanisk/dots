# ==============================================================================
# 40-login.fish — TTY1 Graphical Session Autostart
# ==============================================================================

if status is-login
    if test -z "$DISPLAY" -a -z "$WAYLAND_DISPLAY" -a "$XDG_VTNR" = 1
        exec "$HOME/.local/bin/launch-desktop"
    end
end
