# Claude Code Bootstrap

Use the repository's shared agent contract instead of maintaining a separate Claude-specific copy of system state.

Mandatory reading order:

1. `AGENTS.md`
2. `docs/system/SYSTEM_CONTEXT.md`
3. `docs/system/system-philosophy.md`
4. Only the subsystem documentation and source files relevant to the current task

All authority, safety, validation, documentation-update, and remote-action rules in `AGENTS.md` apply here.

Do not duplicate changing hardware, driver, service, package, mount, audio, GPU, or desktop state in this file. Update `docs/system/SYSTEM_CONTEXT.md` after verified changes that affect cross-agent assumptions, and append material changes to `docs/system/SYSTEM_CHANGELOG.md`.
