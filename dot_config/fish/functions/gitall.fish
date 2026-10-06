function gitall --description "Git add, commit, and push"
    git add .
    git commit -m "$argv"
    git push
end
