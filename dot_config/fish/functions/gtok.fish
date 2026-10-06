function gtok --description "Extract GitHub token or secret to clipboard"
    set -l clip 0
    set -l raw 0
    for arg in $argv
        if test "$arg" = "-c" -o "$arg" = "--clip"
            set clip 1
        else if test "$arg" = "-r" -o "$arg" = "--raw"
            set raw 1
        end
    end
    set -l content (chezmoi cat "$HOME/Documents/new 1.txt" 2>/dev/null)
    if test -z "$content"
        set content (chezmoi cat "$HOME/.test-secret.txt" 2>/dev/null)
    end
    if test $raw -eq 1
        if test $clip -eq 1
            printf "%s" "$content" | xclip -selection clipboard
            echo "Full secret copied to clipboard!"
        else
            printf "%s\n" "$content"
        end
        return 0
    end
    set -l token (echo "$content" | grep -oE 'ghp_[a-zA-Z0-9]+' | head -n 1)
    if test -z "$token"
        set token "$content"
    end
    if test $clip -eq 1
        printf "%s" "$token" | xclip -selection clipboard
        echo "Token copied to clipboard!"
    else
        echo "$token"
    end
end
