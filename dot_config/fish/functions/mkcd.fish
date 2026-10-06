function mkcd --description "Create directory and enter it"
    mkdir -p $argv[1]; and cd $argv[1]
end
