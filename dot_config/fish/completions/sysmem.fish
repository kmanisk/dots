# Fish completions for sysmem
complete -c sysmem -s c -l categories -d "Display high-level category breakdown table"
complete -c sysmem -s a -l all -d "Display all tables (both Applications and Categories)"
complete -c sysmem -s p -l pids -d "Display raw individual process PIDs ranking"
complete -c sysmem -s b -l baseline -l idle -d "Audit pure system idle baseline memory footprint"
complete -c sysmem -s n -l top -d "Number of items to display in tables" -x
complete -c sysmem -s j -l json -d "Output memory metrics as structured JSON"
complete -c sysmem -s h -l help -d "Display help and usage"
