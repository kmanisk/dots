# Completions for spk (ASUS TUF Speaker DSP control utility)
complete -c spk -f

# Core Speaker Profiles
complete -c spk -n "__fish_use_subcommand" -a custom -d "Switch to Custom 2 mode (Dolby Access user preset, +11.6dB presence)"
complete -c spk -n "__fish_use_subcommand" -a c -d "Switch to Custom 2 mode"
complete -c spk -n "__fish_use_subcommand" -a dynamic -d "Switch to Dynamic mode (Windows DAX3 default, Leveler + Spatial)"
complete -c spk -n "__fish_use_subcommand" -a dyn -d "Switch to Dynamic mode"
complete -c spk -n "__fish_use_subcommand" -a music -d "Switch to Music mode (DAX3 Audiophile, uncompressed dynamics)"
complete -c spk -n "__fish_use_subcommand" -a mu -d "Switch to Music mode"
complete -c spk -n "__fish_use_subcommand" -a balanced -d "Switch to Balanced voicing (reference DAX3 baseline)"
complete -c spk -n "__fish_use_subcommand" -a b -d "Switch to Balanced voicing"

# Control Commands
complete -c spk -n "__fish_use_subcommand" -a status -d "Display detailed DSP telemetry & filter state"
complete -c spk -n "__fish_use_subcommand" -a off -d "Bypass DSP immediately (flat internal speakers)"
complete -c spk -n "__fish_use_subcommand" -a on -d "Re-enable DSP on internal speakers"
complete -c spk -n "__fish_use_subcommand" -a help -d "Show usage help"
