# AI Agent Entry Point

This repository is the chezmoi source of truth for the Linux workstation. This file is intentionally small: do not duplicate changing machine state here.

## Mandatory bootstrap

Before changing or diagnosing this system:

1. Read `docs/system/SYSTEM_CONTEXT.md`.
2. Read `docs/system/system-philosophy.md`.
3. Read only the subsystem documentation relevant to the task (`docs/audio/`, `docs/display/`, `docs/gaming/`, `docs/system/`, `docs/theme/`, `docs/virtualization/`, etc.).
4. Inspect the current chezmoi source files that implement the behavior before editing them.
5. If the live machine is available, run `agent-context system` or the relevant project context and verify runtime state. Never assume a documented version, device name, mount type, GPU mode, or service state is still current when it can be checked.

## Authority order

When information conflicts, use this order:

1. The user's explicit instruction in the current task.
2. Freshly verified live-machine output.
3. Current repository configuration/source on the working branch.
4. `docs/system/SYSTEM_CONTEXT.md`.
5. Relevant subsystem documentation.
6. Dated audits and historical reports.
7. Archived docs, old chats, cached agent memory, or assumptions.

A lower-priority source must never silently override a higher-priority source.

## Change protocol

For every durable system change:

- Make the smallest robust change in the chezmoi source of truth.
- Preserve unrelated files, local work, and working behavior.
- Validate the changed subsystem before reporting success.
- Update the relevant detailed subsystem document when architecture or behavior changed.
- Update `docs/system/SYSTEM_CONTEXT.md` when the change alters current machine state, an invariant, a protected baseline, an important path, or an agent-facing assumption.
- Append a concise verified entry to `docs/system/SYSTEM_CHANGELOG.md` for material system changes.
- Do not document an intended state as current until verification succeeds.
- If a previous document is now wrong, correct it or mark the conflicting statement stale; do not leave two apparently authoritative truths.

Implementation-only changes that do not affect agent-facing behavior do not require rewriting `SYSTEM_CONTEXT.md`.

## Automatic documentation synchronization

The local chezmoi Git repository uses `scripts/git-hooks/pre-commit` for Sway/UI commits. When staged changes touch the Sway/UI source-of-truth paths, the hook:

1. runs the read-only Sway validation path,
2. runs `scripts/sync-system-context.sh`,
3. refreshes only the auto-managed live Sway snapshot inside `docs/system/SYSTEM_CONTEXT.md`, and
4. stages that context file into the same commit.

The hook never stages unrelated configuration. Detailed subsystem prose and `SYSTEM_CHANGELOG.md` still follow the manual change contract above when behavior or architecture materially changes.

For an explicit commit-and-push workflow, stage only the intended files and run:

```sh
dots-publish "commit message"
```

`dots-publish` commits only what is already staged (plus the context file added by the pre-commit hook) and pushes the current branch. It never runs `git add -A` or silently publishes unrelated dirty files.

Agents operating only through GitHub, without the live workstation or its Git hooks, must follow the update contract manually and must not fabricate live-state values.

## Engineering rules

- Assume CachyOS/Arch, Sway/Wayland, fish, systemd, PipeWire/WirePlumber, NVIDIA, and chezmoi unless current context proves otherwise.
- Prefer minimal native Linux solutions with low CPU, RAM, wakeup, and background-service cost.
- Measure before optimizing.
- Diagnose root cause before changing configuration.
- Use exact commands, paths, package names, and expected results.
- Never use `pacman -Sy`; use a full supported upgrade path.
- Before package or high-risk system changes, follow the current Snapper/snapshot policy after verifying that policy still applies.
- Never commit plaintext secrets, tokens, private keys, or credentials.
- Use `$HOME` or `~` rather than hardcoded usernames in portable configuration.
- Do not hard-reset, clean, overwrite, or broadly reformat unrelated work.
- Do not add persistent daemons when an on-demand mechanism is sufficient.
- Keep documentation, scripts, source, comments, and README files free of emojis.

## Validation expectations

Use validation appropriate to the subsystem. Examples include:

- Sway: `sway -C` plus targeted live reload/testing when safe.
- Shell scripts: syntax check and focused execution/test.
- systemd user units: unit verification/status plus relevant journal output.
- PipeWire/WirePlumber: inspect graph/defaults/routes and perform silent routing tests where possible.
- Git/chezmoi: inspect the diff and ensure only intended source-of-truth files changed.

Do not claim a task is verified if only static files were edited.

## Remote actions

Do not commit, push, force-push, open/update/merge a PR, publish, or deploy unless the user explicitly asks for that remote action. When remote changes are requested, keep them focused and preserve unrelated history.

## Agent compatibility

Codex, OpenCode, Antigravity/AGY, and other agents that support `AGENTS.md` should start here. Claude-specific bootstrap instructions live in `CLAUDE.md`, which points back to this file and the same canonical system context.
