# Unified on-demand Windows VM control. Native fish; no startup work.
# Defaults to X-Lite (10); choose Nano11 with: win 11 <action>.
function win --description 'Control Windows 10 X-Lite / Windows 11 Nano11 VMs'
    set -l target 10
    set -l selected no
    set -l args $argv

    if set -q args[1]
        switch $args[1]
            case 10 win10 xlite
                set target 10
                set selected yes
                set -e args[1]
            case 11 win11 nano
                set target 11
                set selected yes
                set -e args[1]
        end
    end

    set -l action status
    if set -q args[1]
        set action $args[1]
        set -e args[1]
    end

    if test (count $args) -gt 0
        echo 'win: unexpected arguments. Run win help.' >&2
        return 2
    end

    switch $action
        case help -h --help
            printf '%s\n' \
                'win [10|11] <action>  (default: Windows 10 X-Lite)' \
                '  win                 Show status of both Windows VMs' \
                '  win start           Open/focus Windows 10 on workspace 5' \
                '  win stop            Gracefully shut down Windows (ACPI, then guest wstop.cmd)' \
                '  win force-stop      EMERGENCY: hard poweroff; requires typed confirmation' \
                '  win status          Show status of both VMs' \
                '  win logs            Follow Windows 10 QEMU log (Ctrl+C to stop following)' \
                '  win menu            Open the existing shared Windows Fuzzel/Rofi menu' \
                '  win here            Move the Windows 10 display to current workspace' \
                '  win reconnect       Reconnect Windows 10 Looking Glass client only' \
                '  win fps-on|fps-off   Toggle Windows 10 Looking Glass stats' \
                '  win 11 start|stop|status|logs|here   Manage Nano11' \
                '  win 11 rdp          Open Nano11 RDP recovery client' \
                '  win 11 restart      Use Nano11 safe restart workflow' \
                '  win 10 source-status|client-status  Inspect display/input transport'
            return 0

        case status
            if test $selected = no
                command win10lab status
                command nano11 status
            else if test $target = 10
                command win10lab status
            else
                command nano11 status
            end

        case menu
            command rofi-windows

        case start open launch
            if test $target = 10
                command win10lab workspace
            else
                command nano11 launch
            end

        case stop
            if test $target = 10
                command win10lab stop
            else
                command nano11 stop
            end

        case force-stop
            if test $target = 10
                command win10lab force-stop
            else
                echo 'win: force-stop is deliberately unavailable for Nano11.' >&2
                return 2
            end

        case logs log
            if test $target = 10
                command win10lab logs
            else
                command nano11 logs
            end

        case here
            if test $target = 10
                command win10lab here
            else
                command nano11 here
            end

        case reconnect
            if test $target = 10
                command win10lab reconnect-input
            else
                echo 'win: Nano11 has no client-only reconnect command; use win menu.' >&2
                return 2
            end

        case source-status client-status
            if test $target = 10
                command win10lab $action
            else
                echo 'win: source/client status is only available for Windows 10.' >&2
                return 2
            end

        case fps-on fps-off
            if test $target = 10
                command win10lab $action
            else
                echo 'win: Nano11 FPS controls are available through win menu.' >&2
                return 2
            end

        case rdp
            if test $target = 11
                command nano11 rdp
            else
                echo 'win: RDP recovery is for Nano11; use win 11 rdp.' >&2
                return 2
            end

        case restart
            if test $target = 11
                command nano11 restart
            else
                echo 'win: Windows 10 restart is intentionally menu-gated. Use win menu.' >&2
                return 2
            end

        case '*'
            printf 'win: unknown action: %s\nRun win help.\n' "$action" >&2
            return 2
    end
end
