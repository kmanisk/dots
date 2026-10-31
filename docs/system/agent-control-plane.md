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

## Event-driven Git/document synchronization

The local chezmoi source repository uses `scripts/git-hooks/pre-commit` rather than a resident watcher or timer. The hook treats durable workstation/configuration source changes across the chezmoi tree, package/service manifests, provisioning hooks, and system helper scripts as documentation-bearing changes.

For every such commit it:

1. requires `docs/system/SYSTEM_CHANGELOG.md` to be staged,
2. requires at least one relevant agent-authored Markdown document under `docs/` beyond the generated context/changelog files,
3. runs extra safe validation when available (currently Sway/UI changes use `sway-check`),
4. runs `scripts/sync-system-context.sh` to refresh measured live workstation state, and
5. stages only `docs/system/SYSTEM_CONTEXT.md` automatically.

The generated block records observable runtime facts such as OS/kernel, GPU mode/driver, Sway/output/scale, PipeWire/WirePlumber/default endpoints, important mounts, and failed systemd-unit counts. It does not replace semantic subsystem documentation. The AI agent that changed the system must update the owning subsystem document itself.

`SYSTEM_DOCS_EXEMPT=1` exists only as an explicit manual/emergency bypass. AI agents must not use it unless the user specifically authorizes bypassing the documentation contract.

For a safe one-command publish after selecting the intended files:

```sh
git add <specific-files>
dots-publish "commit message"
```

`dots-publish` commits only the existing staged set plus any context file staged by the pre-commit hook, then pushes the current branch. It never stages the entire dirty working tree automatically.

GitHub-only agents do not receive the local hook or live workstation probes. They must update the semantic knowledge layer manually and must not replace verified live values with guesses.

## Knowledge update rule

After every verified durable workstation/configuration change made by an AI agent, the shared knowledge layer must be updated in the same task instead of keeping the result only in chat/session state:

1. Update the correct chezmoi/config/source implementation.
2. Validate the changed subsystem.
3. Update at least one relevant detailed subsystem Markdown document under `docs/`.
4. Update semantic portions of `docs/system/SYSTEM_CONTEXT.md` if cross-agent assumptions/current state changed; local commits also refresh its generated live snapshot automatically.
5. Append a concise verified entry to `docs/system/SYSTEM_CHANGELOG.md`.
6. Correct or clearly mark older conflicting documentation as stale when encountered.
7. Do not report completion until implementation, validation, and documentation agree.

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
