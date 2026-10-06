function cod --description "Jump to coding directory"
    if test -d ~/coding
        cd ~/coding
    else if test -d ~/Coding
        cd ~/Coding
    else if test -d ~/projects
        cd ~/projects
    else
        mkdir -p ~/coding; and cd ~/coding
    end
end
