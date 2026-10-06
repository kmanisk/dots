function cf --description "Copy file contents to clipboard"
    if test -f "$argv[1]"
        cat "$argv[1]" | xclip -selection clipboard
        echo "Copied $argv[1] to clipboard!"
    else
        echo "File does not exist: $argv[1]"
    end
end
