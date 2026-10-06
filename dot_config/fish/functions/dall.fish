function dall --description "Sync all changes, forget deleted, and push dotfiles"
    set -l msg $argv[1]
    echo "Changes done..."
    chezmoi status
    echo "Forgetting deleted files if any..."
    dfor
    echo "Re-adding modified files..."
    chezmoi re-add
    cd ~/.local/share/chezmoi
    git add .
    if test -z "$msg"
        git commit -m "added lazyily .files"
    else
        git commit -m "$msg"
    end
    git push -u origin master
    cd -
    echo "Dotfiles synchronized successfully!"
end
