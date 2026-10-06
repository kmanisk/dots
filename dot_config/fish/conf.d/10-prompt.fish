# ==============================================================================
# 10-prompt.fish — Starship Prompt & Zoxide Integration
# ==============================================================================

if type -q starship
    starship init fish | source
end

if type -q zoxide
    zoxide init --cmd cd fish | source
end
