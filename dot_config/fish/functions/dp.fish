function dp --description "Lazy commit and push dotfiles"
    echo "Starting automation..."
    cd ~/.local/share/chezmoi
    git add .
    git commit -m "added lazyily .files"
    git push -u origin master
    cd -
end
