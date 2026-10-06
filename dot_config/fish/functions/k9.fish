function k9 --description "Force kill process by name"
    pkill -9 -f $argv[1]
    echo "Killed processes matching: $argv[1]"
end
