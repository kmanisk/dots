function cadd-secret --description "Add encrypted secret to chezmoi"
    chezmoi add --encrypt $argv
end
