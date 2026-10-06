function sec --description "Decrypt and view/copy secret"
    set -l file "new 1.txt"
    set -l clip 0
    for arg in $argv
        if test "$arg" = "-c" -o "$arg" = "--clip"
            set clip 1
        else
            set file $arg
        end
    end
    set -l target "$HOME/Documents/$file"
    if not test -f "$target"
        set target "$file"
    end
    set -l content (chezmoi cat "$target" 2>/dev/null)
    if test -z "$content"
        echo "Secret not found or unable to decrypt: $file"
        return 1
    end
    if test $clip -eq 1
        printf "%s" "$content" | xclip -selection clipboard
        echo "Decrypted secret copied to clipboard!"
    else
        printf "%s\n" "$content"
    end
end
