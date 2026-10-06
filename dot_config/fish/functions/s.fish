function s --description "Search official repos and AUR packages (mirrors PowerShell s)"
    if test (count $argv) -eq 0
        echo "Usage: s <query>"
        return 1
    end
    set -l query $argv[1]
    set_color cyan; echo "== Official Arch Repositories =="; set_color normal
    pacman -Ss $query
    set_color green; echo "== AUR Packages =="; set_color normal
    paru -Ssa $query 2>/dev/null
end
