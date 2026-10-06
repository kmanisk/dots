function cpycmd --description "Run command and copy output to clipboard"
    eval "$argv" | xclip -selection clipboard
    echo "Command output copied to clipboard!"
end
