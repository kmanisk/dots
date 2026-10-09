# ==============================================================================
# 20-aliases.fish — Shell Aliases (Navigation, CLI, Git, Chezmoi, Pkg, Theme)
# ==============================================================================

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
alias dfm="yazi ~/docs/"

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
alias cods="cod"
alias cenc="cadd-secret"

# Modern CLI Replacements
if type -q lsd
    alias ls="lsd"
    alias la="lsd -A"
    alias ll="lsd -la"
else
    alias la="ls -A"
    alias ll="ls -la"
end

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
alias uall="paru && sudo pacman -Syu"
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

# Gaming & Performance Aliases
alias prun="gamemoderun prime-run"
alias gscope="gamescope -W 1920 -H 1200 -r 165 --prime -- gamemoderun"
alias cachy-sync="sudo cachyos-rate-mirrors && sudo pacman -Syu"

# GPU Mode Management (Short Aliases)
alias gm="gpu-mode"
alias gpu="gpu-mode"
alias gms="gpu-mode status"
alias gmd="gpu-mode switch dgpu"
alias gmi="gpu-mode switch hybrid"
alias gmr="gpu-mode reboot"

# aria2c / Download Management
alias a2="aria2c -x16 -s16 -k1M"
alias a2c="aria2c --conf-path=$HOME/.config/aria2/aria2.conf"
alias a2start="aria2-daemon start"
alias a2stop="aria2-daemon stop"
alias a2stat="aria2-daemon status"

