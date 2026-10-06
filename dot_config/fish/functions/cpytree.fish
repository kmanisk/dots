function cpytree --description "Copy clean directory tree to clipboard"
    set -l p "."
    if test (count $argv) -ge 1
        set p $argv[1]
    end
    if type -q tree
        tree -I "node_modules|next|build|.git|target|dist|__pycache__" "$p" | xclip -selection clipboard
    else
        find "$p" -maxdepth 3 -not -path '*/.*' -not -path '*node_modules*' | xclip -selection clipboard
    end
    echo "Directory tree copied to clipboard!"
end
