function ff --description "Find file recursively by name"
    find . -iname "*$argv[1]*"
end
