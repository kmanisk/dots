# Cross-Agent System Control Plane

This repository and the live-machine agent helpers form one shared control plane for ChatGPT, Codex, OpenCode, Claude Code, Antigravity/AGY, and other coding agents.

The goal is to let different agents work on the same workstation without relying on private chat history or each agent maintaining its own copy of system facts.

## Architecture

### Durable repository knowledge

- `AGENTS.md` — shared agent behavior, safety, validation, and documentation-update contract.
- `CLAUDE.md` — Claude-specific bootstrap pointer to the shared contract.
- `docs/system/SYSTEM_CONTEXT.md` — canonical current-system context and source-precedence rules.
- `docs/system/SYSTEM_CHANGELOG.md` — concise material change history for cross-agent handoff.
- `docs/system/system-philosophy.md` — stable design philosophy and system priorities.
- `docs/` — detailed subsystem documentation.
- chezmoi-managed source files — actual configuration source of truth.

### Live runtime overlay

- `agent-context <project>` — preferred conversation/session bootstrap.
- `agent-refresh` — regenerates current runtime state.
- `agent-check <project>` — runs registered validation for a project.
- `~/.local/share/agent/environment.json` — generated runtime evidence; never treat it as permanent configuration or commit it.
- `~/.local/share/agent/projects.json` — project registry used by the helper scripts.

### Task-local continuity

- `<repo>/HANDOFF.md` may hold temporary/current task state for a specific software project.
- Git remains the implementation history and change source of truth.

## Bootstrap sequence

An agent working on the workstation should:

1. Read the repository `AGENTS.md`.
2. Read `docs/system/SYSTEM_CONTEXT.md`.
3. If live-machine access is available, run `agent-context system` or the relevant project context.
4. Read only the detailed documentation for the subsystem being changed.
5. Inspect the actual current source/configuration before editing.

Fresh runtime evidence overrides stale documentation. Current repository source overrides old prose documentation when the two disagree.

## Commands

### `agent-context <project>`

Primary bootstrap command for a new agent session. It should combine current runtime information with shared repository rules and project context.

Examples:

```sh
agent-context system
agent-context ytui
agent-context watchparty
agent-context tele-sixel
```

### `agent-refresh`

Regenerates `~/.local/share/agent/environment.json` from the live machine. It is a runtime snapshot, not a durable knowledge file.

### `agent-check <project>`

Runs the standard validation sequence registered for that project and stops at the first failure.

## Knowledge update rule

After a verified durable system change, every agent must update the shared knowledge layer instead of keeping the result only in its own chat/session:

1. Update the correct chezmoi/config/source implementation.
2. Validate the change.
3. Update the detailed subsystem documentation if behavior or architecture changed.
4. Update `docs/system/SYSTEM_CONTEXT.md` if cross-agent assumptions/current state changed.
5. Append a concise entry to `docs/system/SYSTEM_CHANGELOG.md` for material changes.
6. Correct or clearly mark older conflicting documentation as stale when encountered.

Never write an unverified intended state into the canonical current context.

## Scope rules

Use the narrowest durable scope:

1. Cross-agent workstation behavior: root `AGENTS.md`.
2. Current workstation facts and important assumptions: `docs/system/SYSTEM_CONTEXT.md`.
3. Detailed subsystem architecture: relevant document under `docs/`.
4. Material cross-agent history: `docs/system/SYSTEM_CHANGELOG.md`.
5. Temporary software-project task state: that project's `HANDOFF.md`.
6. Generated live state: `~/.local/share/agent/environment.json` only; do not commit.

Do not maintain separate duplicated hardware/version tables for individual agents.

## Remote safety

Remote actions remain distinct from local edits. Do not commit, push, force-push, update/open a pull request, merge, publish, or deploy unless the user explicitly requests that remote action.
