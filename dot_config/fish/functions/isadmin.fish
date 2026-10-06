function isadmin --description "Check if running with root privileges"
    if test (id -u) -eq 0
        set_color green; echo "Yes"; set_color normal
    else
        set_color red; echo "No"; set_color normal
    end
end
