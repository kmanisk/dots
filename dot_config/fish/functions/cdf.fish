function cdf --description "Fuzzy find directory or file parent and cd"
    set -l sel (find . -maxdepth 4 -not -path '*/.*' 2>/dev/null | fzf)
    if test -n "$sel"
        if test -d "$sel"
            cd "$sel"
        else
            cd (dirname "$sel")
        end
    end
end
