function shutit --description "Sync dotfiles via dall and safely shutdown"
    echo "Synchronizing dotfiles before shutdown..."
    dall "auto sync before shutdown"
    echo "Shutting down system..."
    sudo poweroff
end
