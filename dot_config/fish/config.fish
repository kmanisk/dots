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
