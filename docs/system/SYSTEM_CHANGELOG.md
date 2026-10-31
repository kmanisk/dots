# System Change Log

Concise cross-agent record of material, verified workstation changes.

This is not a replacement for Git history or subsystem documentation. Use it to answer: "What changed recently that another agent should know before touching the system?"

Rules:

- Newest entries first.
- Record only verified/applied changes, not plans.
- Keep entries short and point to the owning subsystem/file when useful.
- Do not paste large diffs, logs, or transient diagnostics here.
- If a change alters current machine assumptions, also update `SYSTEM_CONTEXT.md`.

## 2026-10-31

### Sway reliability and reload hardening

- Made `ui-scale` persist `99-ui-scale.conf` atomically and skip unchanged writes.
- Added read-only `sway-check` and validator-gated `sway-safe-reload`; `Win + Shift + R` now uses the safe reload path.
- Made `ui-sync` avoid unnecessary generated-file writes/reloads for Mako, Swaybar, GTK CSS, and Swaylock while preserving existing behavior.
- Removed redundant display/input defaults, simplified the Foot launcher to `footclient`, and changed one-shot Sway session initialization from `exec_always` to `exec` so ordinary reloads do not restart `swayidle`, the game workspace daemon, xscroll, or other one-shot helpers.
- Verified Sway syntax, a live safe reload, unchanged long-running helper PIDs, and live `eDP-1` at 1920x1200 ~165.004 Hz with runtime scale 1.20.

### Automatic cross-agent context synchronization

- Added `scripts/sync-system-context.sh` to refresh the auto-managed live Sway snapshot in `SYSTEM_CONTEXT.md` only after successful live validation.
- Added a repository pre-commit hook for staged Sway/UI changes; it validates Sway, refreshes the canonical snapshot, and stages only `SYSTEM_CONTEXT.md` in addition to the user's existing staged set.
- Added `dots-publish` as a safe explicit commit-and-push wrapper: it commits only already-staged files and never performs a broad `git add -A`.
- Kept detailed subsystem documentation and material changelog entries agent-maintained; the generated snapshot does not replace semantic documentation.

### Desktop Commander command interface

- Updated `dc-start` so plain `dc` ensures the service is running and shows status, while `dc status` is strictly read-only.
- Preserved explicit `dc start`, `dc stop`, `dc restart`, and `dc logs`; unknown subcommands now fail with usage text instead of implicitly starting the service.

## 2026-10-29

### Centralized cross-agent system knowledge

- Added `docs/system/SYSTEM_CONTEXT.md` as the canonical AI-facing current-system entry point.
- Reworked root `AGENTS.md` into a small shared bootstrap/behavior contract instead of duplicating mutable machine state.
- Added `CLAUDE.md` as a Claude-specific pointer to the same shared rules and context.
- Updated `docs/system/agent-control-plane.md` so live runtime state overlays, rather than replaces, repository documentation.
- Established explicit source precedence and a mandatory documentation-update contract for future agents.

### Current repository baseline incorporated

- Accounted for the central Sway UI-scaling architecture introduced by commit `1a533b95dd9d6c8661b8f617b5914c0d3f369f6f`.
- Kept the 2026-10-23 workstation audit as the latest broad measured-system baseline while explicitly flagging post-audit audio/Dolby work for live revalidation.
