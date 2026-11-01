function clip --description "Copy stdin, text, or file contents to the Wayland clipboard"
    if not set -q WAYLAND_DISPLAY
        echo "clip: WAYLAND_DISPLAY is not set (Wayland session required)" >&2
        return 1
    end

    if not type -q wl-copy
        echo "clip: wl-copy not found (install wl-clipboard)" >&2
        return 127
    end

    if test (count $argv) -gt 0
        set -l all_files 1
        for arg in $argv
            if not test -f "$arg"
                set all_files 0
                break
            end
        end

        if test $all_files -eq 1
            command cat -- $argv | wl-copy
            set -l pipeline_status $pipestatus
            if test $pipeline_status[1] -ne 0
                return $pipeline_status[1]
            end
            return $pipeline_status[2]
        end

        string join ' ' -- $argv | wl-copy
        return $status
    end

    if tty -s
        echo "usage: <command> | clip" >&2
        echo "       clip <text> ..." >&2
        echo "       clip <file> [file ...]" >&2
        return 1
    end

    wl-copy
end
