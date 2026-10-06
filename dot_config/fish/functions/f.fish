function f --description "Fuzzy find: cd to dir or open file in nvim"
    set -l target (
        fd --hidden --exclude .git 2>/dev/null | command fzf \
            --layout reverse \
            --border \
            --preview-window 'right,50%' \
            --preview 'if test -d {}; eza --tree --level=2 --icons {}; else; bat --color=always --style=numbers --line-range=:200 {}; end'
    )

    test -z "$target"; and return

    if test -d "$target"
        cd "$target"
    else if test -f "$target"
        nvim "$target"
    end
end
