function now --description "Show date, day and 12-hour time in color"
    set -l stamp (date '+%a, %d %b %Y')
    set -l day (date '+%A')
    set -l clock (date '+%-I:%M:%S %p')

    set_color '#749689'
    echo -n $stamp
    set_color '#4e4e4e'
    echo -n '  ·  '
    set_color '#d79921'
    echo -n $day
    set_color '#4e4e4e'
    echo -n '  ·  '
    set_color --bold '#e78a4e'
    echo $clock
    set_color normal
end
