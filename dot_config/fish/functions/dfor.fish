function dfor --description "Chezmoi forget deleted files"
    set -l deleted (chezmoi status | grep '^ D' | awk '{print $2}')
    for f in $deleted
        echo "Forgetting: $HOME/$f"
        chezmoi forget "$HOME/$f"
    end
end
