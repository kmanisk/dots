# Completions for spk (ASUS TUF Speaker DSP control utility)
complete -c spk -f

# Windows DAX3 Authentic Modes
complete -c spk -n "__fish_use_subcommand" -a dynamic -d "Switch to Dynamic mode (Windows DAX3 default, Leveler + Spatial)"
complete -c spk -n "__fish_use_subcommand" -a dyn -d "Switch to Dynamic mode"
complete -c spk -n "__fish_use_subcommand" -a movie -d "Switch to Movie mode (DAX3 Cinema, warm bass, soft treble)"
complete -c spk -n "__fish_use_subcommand" -a m -d "Switch to Movie mode"
complete -c spk -n "__fish_use_subcommand" -a music -d "Switch to Music mode (DAX3 Audiophile, uncompressed dynamics)"
complete -c spk -n "__fish_use_subcommand" -a mu -d "Switch to Music mode"
complete -c spk -n "__fish_use_subcommand" -a game -d "Switch to Game mode (DAX3 Gaming, +6dB boost, Leveler)"
complete -c spk -n "__fish_use_subcommand" -a g -d "Switch to Game mode"
complete -c spk -n "__fish_use_subcommand" -a voice -d "Switch to Voice mode (DAX3 Speech, -15dB low-cut, +3dB dialog)"
complete -c spk -n "__fish_use_subcommand" -a v -d "Switch to Voice mode"
complete -c spk -n "__fish_use_subcommand" -a custom -d "Switch to Custom 2 mode (Dolby Access user preset, +11.6dB presence)"
complete -c spk -n "__fish_use_subcommand" -a c -d "Switch to Custom 2 mode"

# Linux Reference Voicings
complete -c spk -n "__fish_use_subcommand" -a balanced -d "Switch to Balanced voicing (reference DAX3 baseline)"
complete -c spk -n "__fish_use_subcommand" -a b -d "Switch to Balanced voicing"
complete -c spk -n "__fish_use_subcommand" -a detailed -d "Switch to Detailed voicing (enhanced presence/clarity)"
complete -c spk -n "__fish_use_subcommand" -a d -d "Switch to Detailed voicing"
complete -c spk -n "__fish_use_subcommand" -a warm -d "Switch to Warm voicing (rich low-end contour)"
complete -c spk -n "__fish_use_subcommand" -a w -d "Switch to Warm voicing"

# Control Commands
complete -c spk -n "__fish_use_subcommand" -a status -d "Display detailed DSP telemetry & filter state"
complete -c spk -n "__fish_use_subcommand" -a off -d "Bypass DSP immediately (flat internal speakers)"
complete -c spk -n "__fish_use_subcommand" -a on -d "Re-enable DSP on internal speakers"
complete -c spk -n "__fish_use_subcommand" -a help -d "Show usage help"
