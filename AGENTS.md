# AI Agent Entry Point

This repository is the chezmoi source of truth for the Linux workstation. This file is intentionally small: do not duplicate changing machine state here.

## Mandatory bootstrap

Before changing or diagnosing this system:

1. Read `docs/system/SYSTEM_CONTEXT.md`.
2. Read `docs/system/system-philosophy.md`.
3. Read `docs/system/SUBSYSTEM_MAP.md` and use it to select only the subsystem documentation relevant to the task.
4. If a matching agent skill is available, use it for procedure/checklists only. A skill never overrides live output, current repository source, `SYSTEM_CONTEXT.md`, or owning subsystem documentation.
5. Inspect the current chezmoi source files that implement the behavior before editing them.
6. If the live machine is available, run `agent-context system` or the relevant project context and verify runtime state. Never assume a documented version, device name, mount type, GPU mode, or service state is still current when it can be checked.

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

Documentation is part of the implementation, not a later cleanup step. For every verified durable workstation/configuration change made by an AI agent:

- Make the smallest robust change in the chezmoi source of truth.
- Preserve unrelated files, local work, and working behavior.
- Validate the changed subsystem before reporting success.
- Update at least one relevant detailed Markdown document under `docs/` so the new behavior, configuration, path, dependency, or operational rule is discoverable by the next agent.
- Update `docs/system/SYSTEM_CONTEXT.md` when the change alters current machine state, an invariant, a protected baseline, an important path, or an agent-facing assumption. Its auto-managed runtime block is refreshed by the repository hook for all system commits from the live workstation.
- Append a concise verified entry to `docs/system/SYSTEM_CHANGELOG.md` for every durable system/configuration commit. Keep trivial implementation detail out of the prose, but record what changed and what was verified.
- Correct or explicitly mark stale any older documentation that now conflicts with the verified implementation.
- Do not document an intended state as current until verification succeeds.
- Do not report the task complete until implementation, validation, and documentation are synchronized in the same change set.

This applies to Sway, audio, display/GPU, shell/terminal, launchers, input, theme/UI, networking, Bluetooth, storage/Btrfs, boot, systemd services, packages, gaming wrappers, virtualization, hardware-control tooling, agent infrastructure, and other workstation configuration in this repository.

## Automatic documentation synchronization and enforcement

The local chezmoi Git repository uses `scripts/git-hooks/pre-commit` as a system-wide documentation safety net. For any staged durable system/configuration source change, the hook:

1. detects the system change across the chezmoi source tree, package/service manifests, provisioning hooks, and system helper scripts,
2. runs extra subsystem validation when a safe validator exists (currently Sway changes use `sway-check`),
3. runs `scripts/sync-system-context.sh` to refresh the auto-managed verified live-workstation snapshot in `docs/system/SYSTEM_CONTEXT.md`,
4. stages only `SYSTEM_CONTEXT.md` automatically, and
5. refuses the commit unless `docs/system/SYSTEM_CHANGELOG.md` and at least one agent-authored subsystem Markdown document under `docs/` are already staged.

The hook never invents semantic documentation and never stages unrelated docs/configuration. `scripts/check-system-docs.sh` validates that the staged documentation matches the touched subsystem(s), using `docs/system/SUBSYSTEM_MAP.md` as the human routing reference. The same deterministic check runs in GitHub Actions (`.github/workflows/system-docs-check.yml`) so cloud/API commits cannot bypass the documentation contract simply because the local hook did not execute.

The AI that made the change is responsible for updating the correct subsystem document before commit. `SYSTEM_DOCS_EXEMPT=1` is an emergency/manual escape hatch for the local hook only; AI agents must not use it unless the user explicitly authorizes bypassing the documentation contract. GitHub CI does not honor that bypass.

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
