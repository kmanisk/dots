# User Fish Configuration
# Ported from PowerShell Profile
source /usr/share/cachyos-fish-config/cachyos-config.fish 2>/dev/null || true

# Environment variables
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8
set -gx EDITOR nvim
set -gx VISUAL nvim

# Ensure user binaries are prioritized in PATH
fish_add_path -m ~/.local/bin
test -d "$HOME/.cargo/bin" && fish_add_path -m "$HOME/.cargo/bin"

# Cursor Style: Line / Beam cursor instead of block
set -g fish_cursor_default line
set -g fish_cursor_insert line
set -g fish_cursor_replace_one underscore
set -g fish_cursor_visual block

# ------------------------------------------------------------------------------
# Prompt & CLI Enhancements (Starship & Zoxide)
# ------------------------------------------------------------------------------
if type -q starship
    starship init fish | source
end

if type -q zoxide
    zoxide init --cmd cd fish | source
end

# ------------------------------------------------------------------------------
# Aliases
# ------------------------------------------------------------------------------
# Navigation
alias up="cd .."
alias ...="cd ../.."
alias g.="cd .."
alias home="cd ~"
alias doc="cd ~/Documents"
alias docs="cd ~/Documents"
alias des="cd ~/Desktop"
alias dot="cd ~/.local/share/chezmoi"
alias dots="cd ~/.local/share/chezmoi"
alias local="cd ~/.local"
alias fm="yazi"

# General Utilities
alias agy="command agy --dangerously-skip-permissions"
alias q="exit"
alias :q="exit"
alias cls="clear"
alias vim="nvim"
alias vi="nvim"
alias nivm="nvim"
alias ep="nvim ~/.config/fish/config.fish"
alias editdot="nvim ~/.local/share/chezmoi"
alias rel="source ~/.config/fish/config.fish; and echo 'Fish config reloaded!'"
alias envs="echo \$PATH | tr ' ' '\n'"
alias fixtether="setup-tether-dns"
alias fixtethering="setup-tether-dns"
alias kg="killgame"
alias mhud="hudtest"
alias dsp="dsp-stat"
alias dspstat="dsp-stat"

# Modern CLI Replacements
# if type -q bat
#     alias cat="bat"
# end
if type -q lsd
    alias ls="lsd"
    alias la="lsd -A"
    alias ll="lsd -la"
else
    alias la="ls -A"
    alias ll="ls -la"
end

# LS_COLORS highlight discipline: strip solid background boxes on other-writable (ow) & sticky (tw/st) dirs
if not set -q LS_COLORS
    if type -q dircolors
        set -gx LS_COLORS (dircolors -c 2>/dev/null | string match -r "setenv LS_COLORS '([^']*)'")[2]
    end
end
set -gx LS_COLORS (string replace -r 'ow=[0-9;]*' 'ow=01;34' "$LS_COLORS")
set -gx LS_COLORS (string replace -r 'tw=[0-9;]*' 'tw=01;34' "$LS_COLORS")
set -gx LS_COLORS (string replace -r 'st=[0-9;]*' 'st=01;34' "$LS_COLORS")


# Chezmoi
alias st="chezmoi status"
alias chm="chezmoi managed"
alias chu="chezmoi update"
alias madd="chezmoi re-add"

# Git
alias gs="git status"
alias ga="git add ."
alias gp="git push"
alias lgall="git add . && git commit -m 'something' && git push -u origin master"

# Package Management (Arch / CachyOS / Paru / FZF)
alias pcheck="checkupdates; paru -Qua 2>/dev/null"
alias uall="paru -Syu"
alias pki="pkg install"
alias pkia="pkg aur"
alias pkr="pkg remove"
alias pkc="pkg clean"
alias pkl="pkg list"
alias pku="pkg update"

# Theme Management
alias thrm="theme-rm"
alias theme_rm="theme-rm"
alias thls="theme-ls"
alias theme_ls="theme-ls"
alias thset="theme-set"
alias theme_set="theme-set"
alias thmenu="rofi-theme"
alias thsync="theme-sync"
alias theme_sync="theme-sync"

# ------------------------------------------------------------------------------
# Functions Ported from PowerShell Profile
# ------------------------------------------------------------------------------
function mkcd --description "Create directory and enter it"
    mkdir -p $argv[1]; and cd $argv[1]
end

function cha --description "Add file to chezmoi"
    chezmoi add $argv
end

function cadd --description "Add file to chezmoi"
    chezmoi add $argv
end

function cadd-secret --description "Add encrypted secret to chezmoi"
    chezmoi add --encrypt $argv
end
alias cenc="cadd-secret"

function sec --description "Decrypt and view/copy secret"
    set -l file "new 1.txt"
    set -l clip 0
    for arg in $argv
        if test "$arg" = "-c" -o "$arg" = "--clip"
            set clip 1
        else
            set file $arg
        end
    end
    set -l target "$HOME/Documents/$file"
    if not test -f "$target"
        set target "$file"
    end
    set -l content (chezmoi cat "$target" 2>/dev/null)
    if test -z "$content"
        echo "Secret not found or unable to decrypt: $file"
        return 1
    end
    if test $clip -eq 1
        printf "%s" "$content" | xclip -selection clipboard
        echo "Decrypted secret copied to clipboard!"
    else
        printf "%s\n" "$content"
    end
end

function gtok --description "Extract GitHub token or secret to clipboard"
    set -l clip 0
    set -l raw 0
    for arg in $argv
        if test "$arg" = "-c" -o "$arg" = "--clip"
            set clip 1
        else if test "$arg" = "-r" -o "$arg" = "--raw"
            set raw 1
        end
    end
    set -l content (chezmoi cat "$HOME/Documents/new 1.txt" 2>/dev/null)
    if test -z "$content"
        set content (chezmoi cat "$HOME/.test-secret.txt" 2>/dev/null)
    end
    if test $raw -eq 1
        if test $clip -eq 1
            printf "%s" "$content" | xclip -selection clipboard
            echo "Full secret copied to clipboard!"
        else
            printf "%s\n" "$content"
        end
        return 0
    end
    set -l token (echo "$content" | grep -oE 'ghp_[a-zA-Z0-9]+' | head -n 1)
    if test -z "$token"
        set token "$content"
    end
    if test $clip -eq 1
        printf "%s" "$token" | xclip -selection clipboard
        echo "Token copied to clipboard!"
    else
        echo "$token"
    end
end

function dfor --description "Chezmoi forget deleted files"
    set -l deleted (chezmoi status | grep '^ D' | awk '{print $2}')
    for f in $deleted
        echo "Forgetting: $HOME/$f"
        chezmoi forget "$HOME/$f"
    end
end

function dp --description "Lazy commit and push dotfiles"
    echo "Starting automation..."
    cd ~/.local/share/chezmoi
    git add .
    git commit -m "added lazyily .files"
    git push -u origin master
    cd -
end

function dpush --description "Interactive commit and push dotfiles"
    echo "Starting automation..."
    cd ~/.local/share/chezmoi
    git add .
    read -P "Enter commit message: " msg
    if test -z "$msg"
        set msg "update dotfiles"
    end
    git commit -m "$msg"
    git push -u origin master
    cd -
end

function dall --description "Sync all changes, forget deleted, and push dotfiles"
    set -l msg $argv[1]
    echo "Changes done..."
    chezmoi status
    echo "Forgetting deleted files if any..."
    dfor
    echo "Re-adding modified files..."
    chezmoi re-add
    cd ~/.local/share/chezmoi
    git add .
    if test -z "$msg"
        git commit -m "added lazyily .files"
    else
        git commit -m "$msg"
    end
    git push -u origin master
    cd -
    echo "Dotfiles synchronized successfully!"
end

function gall --description "Commit and push dotfiles readme"
    cd ~/.local/share/chezmoi
    git add .
    git commit -m "for readme file"
    git push -u origin master
    cd -
end

function gc --description "Git commit with message"
    git commit -m "$argv"
end

function gcl --description "Git clone"
    git clone $argv
end

function gcom --description "Git add and commit"
    git add .
    git commit -m "$argv"
end

function lazyg --description "Git add, commit, and push"
    git add .
    git commit -m "$argv"
    git push
end

function gitall --description "Git add, commit, and push"
    git add .
    git commit -m "$argv"
    git push
end

# Clipboard & File Helpers
function cf --description "Copy file contents to clipboard"
    if test -f "$argv[1]"
        cat "$argv[1]" | xclip -selection clipboard
        echo "Copied $argv[1] to clipboard!"
    else
        echo "File does not exist: $argv[1]"
    end
end

function cpypath --description "Copy absolute path to clipboard"
    if test -e "$argv[1]"
        realpath "$argv[1]" | tr -d '\n' | xclip -selection clipboard
        echo "Path copied to clipboard!"
    else
        echo "Path does not exist: $argv[1]"
    end
end

function cpycmd --description "Run command and copy output to clipboard"
    eval "$argv" | xclip -selection clipboard
    echo "Command output copied to clipboard!"
end

function cdf --description "Fuzzy find directory or file parent and cd"
    set -l sel (find . -maxdepth 4 -not -path '*/.*' 2>/dev/null | fzf)
    if test -n "$sel"
        if test -d "$sel"
            cd "$sel"
        else
            cd (dirname "$sel")
        end
    end
end

function cdwhich --description "cd into directory of command binary"
    set -l p (type -p $argv[1] 2>/dev/null)
    if test -n "$p"
        cd (dirname "$p")
    else
        echo "Command not found: $argv[1]"
    end
end

function ff --description "Find file recursively by name"
    find . -iname "*$argv[1]*"
end

function fs --description "Grep search inside files"
    set -l pattern $argv[1]
    set -l path "."
    if test (count $argv) -ge 2
        set path $argv[2]
    end
    grep -rnI "$pattern" "$path"
end

function size --description "Calculate folder or file size"
    du -sh $argv[1]
end

# ------------------------------------------------------------------------------
# Ported from PowerShell 7 Profile (General Utilities)
# ------------------------------------------------------------------------------
alias edit="cd ~/.config/nvim"
alias spshell="cd ~/.config/systemd/user"
alias sysinfo="fastfetch"
alias idlebench="idle-bench"
alias sysidle="idle-bench"
alias spath="echo \$PATH | tr ' ' '\n'"
alias Show-PathValues="spath"
alias Get-PubIP="pubip"
alias Convert-WebmToMp4="webm2mp4"
alias fman="font"

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

function imginfo --description "Count photos and videos and calculate total size"
    set -l target "."
    if test (count $argv) -ge 1
        set target $argv[1]
    end
    if not test -d "$target"
        echo "Directory not found: $target"
        return 1
    end
    python3 -c "
import os, sys
target = sys.argv[1]
photo_exts = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.heic', '.webp'}
video_exts = {'.mp4', '.mov', '.avi', '.mkv', '.wmv', '.flv', '.webm', '.m4v'}
p_count, p_size = 0, 0
v_count, v_size = 0, 0
for root, _, files in os.walk(target):
    for f in files:
        ext = os.path.splitext(f)[1].lower()
        try:
            sz = os.path.getsize(os.path.join(root, f))
        except OSError:
            continue
        if ext in photo_exts:
            p_count += 1
            p_size += sz
        elif ext in video_exts:
            v_count += 1
            v_size += sz
print(f'Total Photos:      {p_count:,}')
print(f'Total Photo Size:  {p_size / (1024**3):.2f} GB ({p_size / (1024**2):.1f} MB)')
print(f'Total Videos:      {v_count:,}')
print(f'Total Video Size:  {v_size / (1024**3):.2f} GB ({v_size / (1024**2):.1f} MB)')
print(f'Total Media Files: {p_count + v_count:,}')
print(f'Total Media Size:  {(p_size + v_size) / (1024**3):.2f} GB')
" "$target"
end

function shutit --description "Sync dotfiles via dall and safely shutdown"
    echo "Synchronizing dotfiles before shutdown..."
    dall "auto sync before shutdown"
    echo "Shutting down system..."
    sudo poweroff
end

function rebootit --description "Safely restart system"
    echo "Rebooting system..."
    sudo reboot
end

function pubip --description "Print public IP address"
    curl -s https://ifconfig.me/ip
    echo ""
end

function isadmin --description "Check if running with root privileges"
    if test (id -u) -eq 0
        set_color green; echo "Yes"; set_color normal
    else
        set_color red; echo "No"; set_color normal
    end
end

function nf --description "Quick file creation"
    touch $argv[1]
end

function cod --description "Jump to coding directory"
    if test -d ~/coding
        cd ~/coding
    else if test -d ~/Coding
        cd ~/Coding
    else if test -d ~/projects
        cd ~/projects
    else
        mkdir -p ~/coding; and cd ~/coding
    end
end
alias cods="cod"

function cpytree --description "Copy clean directory tree to clipboard"
    set -l p "."
    if test (count $argv) -ge 1
        set p $argv[1]
    end
    if type -q tree
        tree -I "node_modules|next|build|.git|target|dist|__pycache__" "$p" | xclip -selection clipboard
    else
        find "$p" -maxdepth 3 -not -path '*/.*' -not -path '*node_modules*' | xclip -selection clipboard
    end
    echo "Directory tree copied to clipboard!"
end

function trash --description "Safely move files/directories to system trash"
    if type -q gio
        gio trash $argv
        echo "Moved to trash: $argv"
    else
        echo "gio command not available"
    end
end

function k9 --description "Force kill process by name"
    pkill -9 -f $argv[1]
    echo "Killed processes matching: $argv[1]"
end

function font --description "List all installed font families"
    fc-list : family | sort -u
end

function mcpedit --description "Edit MCP configuration in nvim"
    nvim ~/.gemini/antigravity-cli/mcp_config.json
end

function webm2mp4 --description "Convert WebM to MP4 with high quality using ffmpeg"
    set -l input $argv[1]
    if not test -f "$input"
        echo "File not found: $input"
        return 1
    end
    set -l output (string replace -r '\.webm$' '.mp4' "$input")
    echo "Converting $input -> $output..."
    ffmpeg -hide_banner -loglevel error -stats -i "$input" \
        -map 0:v:0 -map 0:a:0? -c:v libx264 -preset slow -crf 18 \
        -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 192k -ac 2 "$output"
    if test $status -eq 0
        echo "✔ Done: $output"
    else
        echo "✖ ffmpeg failed for $input"
    end
end

function fcd --description "Fuzzy find directory with preview and cd"
    set -l dir (find . -maxdepth 4 -type d -not -path '*/.*' 2>/dev/null | fzf --preview 'lsd -la {} 2>/dev/null || ls -la {}' --height 40% --border)
    if test -n "$dir"
        cd "$dir"
    end
end

# ------------------------------------------------------------------------------
# Keybindings
# ------------------------------------------------------------------------------
# Ctrl+b runs dall (mirrors Ctrl+Shift+b in PowerShell profile)
bind \cb "commandline -r 'dall'; commandline -f execute"

# ------------------------------------------------------------------------------
# Gaming & Performance Aliases
# ------------------------------------------------------------------------------
alias prun="gamemoderun prime-run"
alias gscope="gamescope -W 1920 -H 1200 -r 165 --prime -- gamemoderun"
alias cachy-sync="sudo cachyos-rate-mirrors && sudo pacman -Syu"

# Fuzzy find: cd to dir or open file in nvim
function f --description "Fuzzy find: cd to dir or open file in nvim"
    set -l target (
        fd --hidden --exclude .git 2>/dev/null | command fzf \
            --layout reverse \
            --border \
            --preview-window 'right,50%' \
            --preview 'if test -d {}; eza --tree --level=2 --icons {}; else; bat --color=always --style=numbers --line-range=:200 {}; end'
    )

    test -z "$target"; and return

    if test -d "$target"
        cd "$target"
    else if test -f "$target"
        nvim "$target"
    end
end

# Fuzzy find directory and cd into it
function c --description "Fuzzy find directory and cd into it"
    set -l dir (
        fd --type d --hidden --exclude .git 2>/dev/null | command fzf \
            --layout reverse \
            --border \
            --preview-window 'right,50%' \
            --preview 'eza --tree --level=2 --icons {}'
    )

    test -n "$dir"; and cd "$dir"
end

# Autostart graphical session (Plasma Wayland or i3 X11) if logging into TTY1
if status is-login
    if test -z "$DISPLAY" -a -z "$WAYLAND_DISPLAY" -a "$XDG_VTNR" = 1
        exec "$HOME/.local/bin/launch-desktop"
    end
end
