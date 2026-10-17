function hudtest --description "Preview MangoHud telemetry overlay on a spinning 3D Vulkan cube"
    set -l target_config ""
    set -l use_igpu 0

    for arg in $argv
        switch $arg
            case "--igpu" "-i"
                set use_igpu 1
            case "-h" "--help"
                echo "Usage: hudtest [OPTIONS] [CONFIG_FILE]"
                echo ""
                echo "Previews your MangoHud overlay on a spinning Vulkan test cube."
                echo ""
                echo "Options:"
                echo "  -i, --igpu       Preview on Intel iGPU instead of discrete RTX 5050"
                echo "  -h, --help       Show this help message"
                echo ""
                echo "Examples:"
                echo "  hudtest                       # Preview active global MangoHud config on RTX 5050"
                echo "  hudtest ~/mangohud_custom_backup.conf"
                echo "  hudtest --igpu                # Test on Intel iGPU"
                return 0
            case "*"
                if test -f "$arg"
                    set target_config (path resolve "$arg")
                else if test -f "$HOME/.config/MangoHud/$arg"
                    set target_config "$HOME/.config/MangoHud/$arg"
                else if test -f "$HOME/.config/MangoHud/$arg.conf"
                    set target_config "$HOME/.config/MangoHud/$arg.conf"
                else
                    echo "Warning: Config file '$arg' not found. Using default active config."
                end
        end
    end

    if test -n "$target_config"
        echo "Rendering MangoHud preview with: $target_config"
        set -x MANGOHUD_CONFIGFILE "$target_config"
    else
        echo "Rendering MangoHud preview with active configuration (~/.config/MangoHud/MangoHud.conf)"
    end

    # Previews must always show the HUD even though the default preset hides it
    # for games. read_cfg keeps the config file in the chain (a bare MANGOHUD_CONFIG
    # would replace it entirely); no_display=0 is applied last and wins.
    set -x MANGOHUD_CONFIG "read_cfg,no_display=0"

    if test $use_igpu -eq 1
        echo "GPU: Intel iGPU (Integrated)"
        mangohud vkcube
    else
        echo "GPU: NVIDIA GeForce RTX 5050 (prime-run)"
        prime-run mangohud vkcube
    end
end
