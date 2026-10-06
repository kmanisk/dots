function pubip --description "Print public IP address"
    curl -s https://ifconfig.me/ip
    echo ""
end
