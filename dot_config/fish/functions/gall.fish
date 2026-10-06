function gall --description "Commit and push dotfiles readme"
    cd ~/.local/share/chezmoi
    git add .
    git commit -m "for readme file"
    git push -u origin master
    cd -
end
