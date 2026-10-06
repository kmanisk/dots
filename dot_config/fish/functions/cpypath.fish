function cpypath --description "Copy absolute path to clipboard"
    if test -e "$argv[1]"
        realpath "$argv[1]" | tr -d '\n' | xclip -selection clipboard
        echo "Path copied to clipboard!"
    else
        echo "Path does not exist: $argv[1]"
    end
end
