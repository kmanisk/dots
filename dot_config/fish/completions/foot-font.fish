# Fish shell completions for foot-font

complete -c foot-font -s s -l size -d "Set font size (e.g. 18.5)"
complete -c foot-font -s f -l family -d "Set font family (e.g. 'Iosevka Nerd Font Mono')" -r -a "(fc-list : family | tr ',' '\n' | string trim | sort -u | string match -r '(?i).*(nerd|mono|code).*')"
complete -c foot-font -l style -d "Set font style (e.g. Bold, Regular, Italic)" -a "Bold Regular Medium SemiBold Light"
complete -c foot-font -s r -l restart -d "Restart foot-server.service"
complete -c foot-font -l force -d "Bypass font validation and active foot session check"
complete -c foot-font -s l -l list -d "List installed monospace and nerd fonts"
complete -c foot-font -s h -l help -d "Show usage help"
