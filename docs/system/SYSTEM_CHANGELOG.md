# System Change Log

Concise cross-agent record of durable, verified workstation/configuration changes.

This is not a replacement for Git history or subsystem documentation. Use it to answer: "What changed recently that another agent should know before touching the system?"

Rules:

- Newest entries first.
- Record only verified/applied changes, not plans.
- Keep entries short and point to the owning subsystem/file when useful.
- Do not paste large diffs, logs, or transient diagnostics here.
- If a change alters current machine assumptions, also update `SYSTEM_CONTEXT.md`.

## 2026-10-31

### Unified Codex / AGY / OpenCode automation

- Added `docs/system/SUBSYSTEM_MAP.md` so fresh agents route implementation paths to the correct active docs and optional procedural skill without loading the whole documentation tree.
- Added deterministic `scripts/check-system-docs.sh` and GitHub Actions `system-docs-check`, so local and remote/cloud system commits must carry `SYSTEM_CHANGELOG.md` plus matching semantic subsystem documentation.
- Replaced stale global Codex/AGY/OpenCode machine-state instruction copies with thin chezmoi-managed pointers back to repository `AGENTS.md`.
- Added `sync-agent-skills` and an after-apply hook to expose the single `dot_agents/skills/` library to Codex, Antigravity, and OpenCode while preserving built-in/non-managed skills.
- Brought the previously live-only `reverse-engineer-anything` skill and its references under chezmoi so all three primary agents receive the same 12 custom skills.
- Reconciled the newer live `bluetooth-autoconnect` skill changes into source before applying shared governance, preserving its 2026-10-29 foreground-only/connect-timeout fixes.
- Added a mandatory authority/freshness notice to shared skills so dated machine details cannot override live state, current repo source, `SYSTEM_CONTEXT.md`, or owning subsystem docs.

### System-wide AI documentation contract

- Generalized the repository pre-commit documentation hook from Sway/UI-only detection to all durable workstation/configuration source changes in chezmoi, package/service manifests, provisioning hooks, and system helper scripts.
- AI-authored system commits now require both `docs/system/SYSTEM_CHANGELOG.md` and at least one relevant semantic Markdown document under `docs/`; the generated `SYSTEM_CONTEXT.md` snapshot does not satisfy the semantic-document requirement by itself.
- Expanded `scripts/sync-system-context.sh` to record a verified cross-subsystem runtime snapshot: OS/kernel, GPU mode and NVIDIA driver, Sway/output/scale, PipeWire/WirePlumber/default endpoints, root/Games/Windows mounts, and failed systemd-unit counts.
- Kept subsystem-specific validation layered on top: Sway/UI changes still run `sway-check`, while other subsystems remain responsible for their own strongest safe validation before completion.
- Added `SYSTEM_DOCS_EXEMPT=1` only as an explicit manual/emergency bypass; AI agents are forbidden by `AGENTS.md` from using it unless the user explicitly authorizes bypassing documentation enforcement.

### Sway reliability and reload hardening

- Made `ui-scale` persist `99-ui-scale.conf` atomically and skip unchanged writes.
- Added read-only `sway-check` and validator-gated `sway-safe-reload`; `Win + Shift + R` now uses the safe reload path.
- Made `ui-sync` avoid unnecessary generated-file writes/reloads for Mako, Swaybar, GTK CSS, and Swaylock while preserving existing behavior.
- Removed redundant display/input defaults, simplified the Foot launcher to `footclient`, and changed one-shot Sway session initialization from `exec_always` to `exec` so ordinary reloads do not restart `swayidle`, the game workspace daemon, xscroll, or other one-shot helpers.
- Verified Sway syntax, a live safe reload, unchanged long-running helper PIDs, and live `eDP-1` at 1920x1200 ~165.004 Hz with runtime scale 1.20.

### Initial cross-agent context synchronization

- Added the first `scripts/sync-system-context.sh` and pre-commit integration as a Sway/UI-only implementation; this was generalized later the same day by the system-wide AI documentation contract above.
- Added `dots-publish` as a safe explicit commit-and-push wrapper: it commits only already-staged files and never performs a broad `git add -A`.
- Established the core rule that generated runtime context never replaces agent-authored semantic subsystem documentation.

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
