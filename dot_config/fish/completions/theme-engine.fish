# Fish completions for unified Theme Engine commands and aliases

set -l theme_commands theme-set theme-rm thset thrm theme_set theme_rm

for cmd in $theme_commands
    complete -c $cmd -f -a '(theme-ls)' -d "Theme"
end

complete -c theme-ls -s l -l long -d "Display detailed table format"
complete -c theme-ls -s a -l active -d "Print only the currently active theme"
complete -c theme-ls -s p -l provider -x -a "base46 omarchy custom" -d "Filter by provider"

complete -c thls -s l -l long -d "Display detailed table format"
complete -c thls -s a -l active -d "Print only the currently active theme"
complete -c thls -s p -l provider -x -a "base46 omarchy custom" -d "Filter by provider"

complete -c theme_ls -s l -l long -d "Display detailed table format"
complete -c theme_ls -s a -l active -d "Print only the currently active theme"
complete -c theme_ls -s p -l provider -x -a "base46 omarchy custom" -d "Filter by provider"

complete -c theme-rm -s f -l force -d "Skip confirmation prompt"
complete -c theme-rm -s n -l dry-run -d "Simulate deletion without changes"
complete -c theme-rm -l preview -x -a '(theme-ls)' -d "Preview theme metadata & colors"

complete -c thrm -s f -l force -d "Skip confirmation prompt"
complete -c thrm -s n -l dry-run -d "Simulate deletion without changes"
complete -c thrm -l preview -x -a '(theme-ls)' -d "Preview theme metadata & colors"

complete -c theme_rm -s f -l force -d "Skip confirmation prompt"
complete -c theme_rm -s n -l dry-run -d "Simulate deletion without changes"
complete -c theme_rm -l preview -x -a '(theme-ls)' -d "Preview theme metadata & colors"
