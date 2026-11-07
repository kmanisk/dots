# Native fish tab completion for the unified on-demand Windows VM command.
complete -c win -f
complete -c win -n 'test (count (commandline -opc)) -eq 1' -a '10 11' -d 'Select Windows guest'
complete -c win -n 'test (count (commandline -opc)) -eq 1' -a 'start stop force-stop status logs menu here reconnect fps-on fps-off source-status client-status help' -d 'Windows VM action'
complete -c win -n 'test (count (commandline -opc)) -eq 2; and contains -- (commandline -opc)[2] 10 win10 xlite' -a 'start stop force-stop status logs menu here reconnect fps-on fps-off source-status client-status help' -d 'Windows X-Lite action'
complete -c win -n 'test (count (commandline -opc)) -eq 2; and contains -- (commandline -opc)[2] 11 win11 nano' -a 'start stop status logs menu here restart rdp help' -d 'Windows Nano11 action'
