# ==============================================================================
# 00-env.fish — Environment Variables, PATH & Terminal Cursor
# ==============================================================================

# Locale & Editors
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

# LS_COLORS highlight discipline: strip solid background boxes on other-writable & sticky dirs
if not set -q LS_COLORS
    if type -q dircolors
        set -gx LS_COLORS (dircolors -c 2>/dev/null | string match -r "setenv LS_COLORS '([^']*)'")[2]
    end
end
set -gx LS_COLORS (string replace -r 'ow=[0-9;]*' 'ow=01;34' "$LS_COLORS")
set -gx LS_COLORS (string replace -r 'tw=[0-9;]*' 'tw=01;34' "$LS_COLORS")
set -gx LS_COLORS (string replace -r 'st=[0-9;]*' 'st=01;34' "$LS_COLORS")
