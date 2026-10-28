# ==============================================================================
# User Fish Shell Configuration
# Modular architecture:
#   ~/.config/fish/conf.d/00-env.fish      - Environment variables, PATH, cursor
#   ~/.config/fish/conf.d/10-prompt.fish   - Starship prompt & Zoxide
#   ~/.config/fish/conf.d/20-aliases.fish  - Navigation, CLI tools, pkg, git, theme
#   ~/.config/fish/conf.d/30-bindings.fish - Custom keybindings
#   ~/.config/fish/conf.d/40-login.fish    - TTY1 graphical desktop autostart
#   ~/.config/fish/functions/*.fish        - Auto/lazy-loaded standalone functions
# ==============================================================================

# CachyOS default integrations
source /usr/share/cachyos-fish-config/cachyos-config.fish 2>/dev/null || true

# CachyOS aliases ls/la/ll/lt to eza with --color=always --icons=always, which
# writes raw ANSI escapes and Nerd Font glyphs into pipes, redirects, clipboard
# captures and logs. Erase those functions and wrap eza explicitly: colours and
# icons only when stdout is a real terminal (or when NO_COLOR is unset).
# This block must stay after the source line above, because ~/.config/fish/
# conf.d/*.fish is read before config.fish and would lose to CachyOS otherwise.
functions -e ls la ll lt 2>/dev/null

function __eza_listing --description 'eza with TTY-aware colour and icon selection'
    set -l mode never
    if isatty stdout; and not set -q NO_COLOR
        set mode always
    end
    command eza --color=$mode --icons=$mode --group-directories-first $argv
end

function ls --wraps=eza --description 'List entries (eza; plain text when piped or redirected)'
    __eza_listing -al $argv
end

function la --wraps=eza --description 'List all entries (eza; plain text when piped or redirected)'
    __eza_listing -a $argv
end

function ll --wraps=eza --description 'Long listing (eza; plain text when piped or redirected)'
    __eza_listing -l $argv
end

function lt --wraps=eza --description 'Tree listing (eza; plain text when piped or redirected)'
    __eza_listing -aT $argv
end

# Profile-aware greeting: suppress fastfetch inside Neovim, IDEs, or small embedded splits
function fish_greeting
    if set -q NVIM; or set -q VIM; or set -q ZED_TERM; or test "$TERM_PROGRAM" = "vscode"
        return
    end

    if test (tput cols 2>/dev/null || echo 100) -lt 80; or test (tput lines 2>/dev/null || echo 24) -lt 15
        return
    end

    fastfetch
end
