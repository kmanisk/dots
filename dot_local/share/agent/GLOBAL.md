# Shared ChatGPT / Desktop Commander Rules

## Authoritative roots
- Home: `/home/onyx`
- Projects: `/home/onyx/Projects`
- System documentation: `/home/onyx/docs`
- Shared agent state: `/home/onyx/.local/share/agent`

## Source of truth
- Treat Desktop Commander and the live filesystem as authoritative for machine state.
- Do not trust old conversation state for branches, services, paths, displays, packages, ports, builds, or running processes.
- Start local coding/system work with `agent-context <project>` (or `agent-context system`).
- Preserve unrelated working-tree and system changes.

## Coding
- Read `/home/onyx/Projects/AGENTS.md`, then the project `AGENTS.md`, then `HANDOFF.md`.
- Prefer `rg`, `fd`, `git grep`, targeted reads, and batched diagnostics.
- Do not recursively inspect `.git/`, `target/`, `node_modules/`, `dist/`, caches, or generated build trees unless explicitly needed.
- Run the validation commands declared by the project before claiming a fix is complete.
- Update `HANDOFF.md` when a coding session leaves meaningful unfinished state.

## Persistent rules and environment changes
- When the user establishes a durable cross-project rule, update this file.
- When the rule applies only to coding, update `/home/onyx/Projects/AGENTS.md` instead.
- When the rule applies to one repo, update that repo's `AGENTS.md`.
- Persistent system changes should be documented under `/home/onyx/docs` and in chezmoi when the affected config is chezmoi-managed.
- `agent-context` refreshes live environment facts automatically; do not manually copy volatile machine state into this file.

## Remote safety
- Never commit, push, force-push, update/open a PR, merge, publish, or deploy unless the user explicitly requests that remote action.
- Do not modify another project/worktree just because it is nearby.
- Do not expose credentials, OAuth secrets, recovery codes, tokens, or private keys.
