function fcd --description "Fuzzy find directory with preview and cd"
    set -l dir (find . -maxdepth 4 -type d -not -path '*/.*' 2>/dev/null | fzf --preview 'lsd -la {} 2>/dev/null || ls -la {}' --height 40% --border)
    if test -n "$dir"
        cd "$dir"
    end
end
