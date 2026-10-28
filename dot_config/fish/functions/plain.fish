function plain --description "Strip ANSI escapes and Nerd Font icons from captured output"
    if test (count $argv) -gt 0
        cat -- $argv
    else
        cat
    end | string replace -ra '\e\][^\a\e]*(\a|\e\x5c)' '' \
        | string replace -ra '\e\[[0-9;?]*[a-zA-Z]' '' \
        | string replace -ra '\x5e\[\[[0-9;?]*[a-zA-Z]' '' \
        | string replace -ra '[\x{E000}-\x{F8FF}\x{F0000}-\x{FFFFD}\x{100000}-\x{10FFFD}] ?' ''
end
