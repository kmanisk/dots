function fs --description "Grep search inside files"
    set -l pattern $argv[1]
    set -l path "."
    if test (count $argv) -ge 2
        set path $argv[2]
    end
    grep -rnI "$pattern" "$path"
end
