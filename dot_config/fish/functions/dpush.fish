function dpush --description "Interactive commit and push dotfiles"
    echo "Starting automation..."
    cd ~/.local/share/chezmoi
    git add .
    read -P "Enter commit message: " msg
    if test -z "$msg"
        set msg "update dotfiles"
    end
    git commit -m "$msg"
    git push -u origin master
    cd -
end
