function clip --description "Copy stdin or arguments to the Wayland clipboard"
    if not set -q WAYLAND_DISPLAY
        echo "clip: WAYLAND_DISPLAY is not set (Wayland session required)" >&2
        return 1
    end

    if not type -q wl-copy
        echo "clip: wl-copy not found (install wl-clipboard)" >&2
        return 127
    end

    if test (count $argv) -gt 0
        string join ' ' -- $argv | wl-copy
        return $status
    end

    if tty -s
        echo "usage: <command> | clip" >&2
        echo "       clip <text> ..." >&2
        return 1
    end

    wl-copy
end
