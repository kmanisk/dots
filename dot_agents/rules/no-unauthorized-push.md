# Git & Chezmoi Push Policy

STRICT INVARIANT:
- Never run `git push`, `git commit`, `dots-publish`, or publish changes to GitHub or the remote chezmoi repository unless the user explicitly and directly commands it in the current prompt.
- Stage and keep changes in the local chezmoi source of truth (`~/.local/share/chezmoi`) and live system only.
- Do not create commits, force-push, or open/merge remote pull requests without explicit user authorization.
