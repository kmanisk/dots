# Cross-Agent System Control Plane

This repository and the live-machine agent helpers form one shared control plane for ChatGPT, Codex, OpenCode, Claude Code, Antigravity/AGY, and other coding agents.

The goal is to let different agents work on the same workstation without relying on private chat history or each agent maintaining its own copy of system facts.

## Architecture

### Durable repository knowledge

- `AGENTS.md` — shared agent behavior, safety, validation, and documentation-update contract.
- `CLAUDE.md` — Claude-specific bootstrap pointer to the shared contract.
- `docs/system/SYSTEM_CONTEXT.md` — canonical current-system context and source-precedence rules.
- `docs/system/SUBSYSTEM_MAP.md` — implementation-path to owning-document/skill routing table.
- `docs/system/SYSTEM_CHANGELOG.md` — concise material change history for cross-agent handoff.
- `docs/system/system-philosophy.md` — stable design philosophy and system priorities.
- `dot_agents/skills/*/SKILL.md` — canonical reusable procedural skill library managed by chezmoi.
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
2. Read `docs/system/SYSTEM_CONTEXT.md` and `docs/system/system-philosophy.md`.
3. Read `docs/system/SUBSYSTEM_MAP.md` to route the task to the smallest relevant documentation set and optional skill.
4. If a matching skill is available, use it only as a procedure/checklist; current source and live evidence remain authoritative.
5. If live-machine access is available, run `agent-context system` or the relevant project context.
6. Read only the detailed documentation for the subsystem being changed.
7. Inspect the actual current source/configuration before editing.

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

The workstation uses two deterministic enforcement layers rather than an AI writer running in the background:

1. **Local pre-commit:** `scripts/git-hooks/pre-commit` runs `scripts/check-system-docs.sh --cached`, performs any safe subsystem-specific validation (currently Sway/UI), refreshes the measured live block in `SYSTEM_CONTEXT.md`, and stages only that generated context file.
2. **GitHub Actions:** `.github/workflows/system-docs-check.yml` runs the same `scripts/check-system-docs.sh` against the pushed/PR diff. This catches Codex cloud, GitHub API, or other remote changes that never execute the laptop's Git hook.

`check-system-docs.sh` requires `SYSTEM_CHANGELOG.md` plus active semantic documentation matching the subsystem(s) touched. `docs/archive/`, `docs/future/`, `docs/personal/`, dated audits, `SYSTEM_CONTEXT.md`, and the changelog itself do not count as owning semantic documentation.

### Shared agent instructions and skills

The detailed workstation contract lives only in the repository. The global instruction files for the three primary agents are intentionally tiny chezmoi-managed routing pointers:

- `~/.codex/AGENTS.md` <- `dot_codex/AGENTS.md`
- `~/.gemini/AGENTS.md` <- `dot_gemini/AGENTS.md`
- `~/.config/opencode/AGENTS.md` <- `dot_config/opencode/AGENTS.md`

They tell an agent started outside the chezmoi directory to read the repository `AGENTS.md` before Linux-system work; they do not copy mutable hardware/runtime state.

The canonical custom skill source is `dot_agents/skills/`. `sync-agent-skills` exposes each valid skill as a symlink in:

- `~/.codex/skills/`
- `~/.gemini/config/skills/`
- `~/.config/opencode/skills/`

`run_after_90-sync-agent-skills.sh` re-runs this synchronization after every `chezmoi apply`. It preserves built-in/non-symlink agent skills and removes only stale symlinks previously managed from this repository. Every shared skill carries an authority warning: it is procedural knowledge, not a current-state source.

For a safe one-command publish after selecting the intended files:

```sh
git add <specific-files>
dots-publish "commit message"
```

`dots-publish` commits only the existing staged set plus any context file staged by the pre-commit hook, then pushes the current branch. It never stages the entire dirty working tree automatically.

The local emergency `SYSTEM_DOCS_EXEMPT=1` bypass does not affect GitHub CI. AI agents must not use it unless the user explicitly authorizes the bypass.

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
