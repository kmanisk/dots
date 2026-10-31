# Global agent routing

- For Linux workstation, dotfiles, chezmoi, Sway, audio, GPU, gaming-runtime, service, or `kmanisk/dots` work, the canonical repository is `~/.local/share/chezmoi`.
- Before diagnosing or changing that workstation, read `~/.local/share/chezmoi/AGENTS.md` and follow its bootstrap, authority order, validation rules, subsystem map, and documentation contract.
- Do not duplicate mutable machine state in this global file. Current state belongs in the repository and live-system evidence.
- For unrelated repositories, follow their repository-local instructions and preserve unrelated working-tree changes.
- Do not commit or push unless explicitly requested.
