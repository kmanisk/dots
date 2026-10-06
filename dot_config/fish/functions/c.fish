function c --description "Fuzzy find directory and cd into it"
    set -l dir (
        fd --type d --hidden --exclude .git 2>/dev/null | command fzf \
            --layout reverse \
            --border \
            --preview-window 'right,50%' \
            --preview 'eza --tree --level=2 --icons {}'
    )

    test -n "$dir"; and cd "$dir"
end
