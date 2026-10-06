function cdwhich --description "cd into directory of command binary"
    set -l p (type -p $argv[1] 2>/dev/null)
    if test -n "$p"
        cd (dirname "$p")
    else
        echo "Command not found: $argv[1]"
    end
end
