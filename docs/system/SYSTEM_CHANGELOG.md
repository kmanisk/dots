# System Change Log

Concise cross-agent record of material, verified workstation changes.

This is not a replacement for Git history or subsystem documentation. Use it to answer: "What changed recently that another agent should know before touching the system?"

Rules:

- Newest entries first.
- Record only verified/applied changes, not plans.
- Keep entries short and point to the owning subsystem/file when useful.
- Do not paste large diffs, logs, or transient diagnostics here.
- If a change alters current machine assumptions, also update `SYSTEM_CONTEXT.md`.

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
