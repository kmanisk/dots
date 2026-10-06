function trash --description "Safely move files/directories to system trash"
    if type -q gio
        gio trash $argv
        echo "Moved to trash: $argv"
    else
        echo "gio command not available"
    end
end
