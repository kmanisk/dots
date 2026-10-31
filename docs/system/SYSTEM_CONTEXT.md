# Canonical System Context

This is the primary machine-context document for AI agents working on this repository.

It is not a replacement for the detailed subsystem documentation. Its job is to provide one current entry point, resolve conflicts between older documents, record important invariants, and tell an agent what must be verified before making changes.

Last synchronized with repository state: 2026-10-31.
Material change history is tracked in `docs/system/SYSTEM_CHANGELOG.md` and Git; this file intentionally does not pin itself to a commit hash.
Latest broad live-system audit used as an evidence baseline: `docs/system/workstation-audit-2026-10-23.md`.

## 1. Authority and freshness

Use the following precedence when facts disagree:

1. Explicit instruction from the user in the current task.
2. Fresh live-machine command output.
3. Current source/configuration in this repository.
4. This file.
5. Relevant subsystem documentation.
6. Dated audit/report documents.
7. Archived documentation, old conversations, cached agent memory, or assumptions.

Version numbers and runtime state in this file are snapshots, not promises. Re-check them when the exact value matters.

Never copy a changing fact into multiple agent instruction files. Update it here and keep agent entry files as pointers.

## 2. Machine identity

Primary machine:

- Laptop: ASUS TUF Gaming F16 FX608JH family.
- CPU: Intel Core i5-13450HX, 16 logical threads.
- Integrated GPU: Intel UHD Graphics.
- Discrete GPU: NVIDIA GeForce RTX 5050 Laptop GPU, 8 GB VRAM.
- RAM: 16 GB installed at the current baseline.
- Internal display: 1920x1200, 165 Hz class panel.
- OS family: CachyOS / Arch Linux, x86-64-v3.
- Primary desktop: Sway on Wayland.
- Shell: fish.
- Dotfile/configuration manager: chezmoi.
- Repository: `kmanisk/dots`, default branch `master`.

The repository source under `~/.local/share/chezmoi` is the configuration source of truth where a file is chezmoi-managed.

## 3. Current verified desktop/GPU baseline

The 2026-10-23 workstation audit verified:

- Kernel: `7.3.0-2-cachyos` at audit time.
- Sway: `1.12`.
- GPU mode: `AsusMuxDgpu`.
- NVIDIA driver: `615.78.08` at audit time.
- Active internal output: `eDP-2` in that boot.
- Output mode: 1920x1200 at approximately 165.004 Hz.
- Output scale: 1 at audit time.
- Adaptive sync: disabled at audit time.
- Tearing: allowed.
- NVIDIA was the direct display GPU in the audited dGPU-only session.

Do not treat DRM card numbers, connector enumeration, or an old `eDP-1`/`eDP-2` name as permanent. Query the running compositor before scripts depend on a connector name.

### UI scaling

Sway output scaling is the central application/UI scale source. Fresh live verification on 2026-10-31 found `eDP-1` at 1920x1200, approximately 165.004 Hz, runtime scale `1.20`, with GPU mode `AsusMuxDgpu`.

Relevant files include:

- `dot_config/sway/config.d/45-ui-scale.conf`
- generated runtime `~/.config/sway/config.d/99-ui-scale.conf` (not pinned as a tracked fixed scale)
- generated runtime `~/.config/sway/config.d/99-ui-chrome.conf`
- `dot_config/ui-metrics.conf`
- `dot_local/bin/executable_ui-scale`
- `dot_local/bin/executable_ui-sync`
- `dot_local/bin/executable_sway-check`
- `dot_local/bin/executable_sway-safe-reload`
- `dot_config/theme/hooks.d/executable_50-ui-chrome`

`ui-scale` writes scale state atomically and skips replacing unchanged content. `ui-sync` skips unchanged generated-file writes/reloads. Sway maintenance should use read-only `sway-check` and validated `sway-safe-reload`; `Win + Shift + R` is bound to the latter.

Do not reintroduce stacked Chromium/device-scale overrides unless there is a measured reason. Inspect the current generated scale state before changing font or chrome sizes.

### Auto-synchronized live workstation snapshot

The block below is maintained by `scripts/sync-system-context.sh` for every durable workstation/configuration commit made from the live chezmoi repository. It records measured runtime facts across the desktop/GPU, audio stack, mounts, kernel, and basic system health. The repository pre-commit hook refreshes and stages only this generated block automatically; agents must still update the relevant semantic subsystem documentation and changelog themselves.

<!-- AUTO:SYSTEM_STATE:BEGIN -->
> Auto-synchronized from the live workstation by `scripts/sync-system-context.sh`. This is measured runtime state, not semantic documentation. Do not edit inside these markers.

- Last live sync: **2026-10-31**.
- OS/kernel: `CachyOS` / `7.3.0-4-cachyos`.
- GPU mode: `AsusMuxDgpu`.
- NVIDIA: `NVIDIA GeForce RTX 5050 Laptop GPU`, driver `615.78.08`.
- Sway: `sway version 1.12`; validation: **not required for this commit**.
- Active output: `eDP-1, 1920x1200 @ 165.004 Hz, scale 1.20, adaptive sync disabled`.
- Persisted generated UI scale: `1.20`.
- Sway reload path: `sway-safe-reload` (validates before `swaymsg reload`).
- Audio: PipeWire `1.6.10`, WirePlumber `0.5.18`.
- Default audio sink: `alsa_output.pci-0000_00_1f.3.analog-stereo`.
- Default audio source: `ghelper-audio`.
- Root mount: `/dev/nvme0n1p6[/@] btrfs /`.
- Games mount: `/dev/nvme0n1p5 ntfs3 /mnt/Games`.
- Windows mount: `/dev/nvme0n1p3 ntfs3 /mnt/windows`.
- Failed systemd units: system `0`, user `0`.

These values are a convenience snapshot for cross-agent context. Exact runtime-sensitive values must still be re-queried before diagnosis or modification.
<!-- AUTO:SYSTEM_STATE:END -->








## 4. System design invariants

The stable design philosophy is defined in `docs/system/system-philosophy.md`. Important operational invariants are:

- Gaming latency, stable frametimes, and a responsive terminal-first desktop take priority over visual effects.
- Avoid animations, blur, shadows, and unnecessary compositor/UI overhead.
- Prefer on-demand tools over resident processes.
- Do not add a daemon merely for convenience when a one-shot/event-driven mechanism works.
- Preserve the direct dGPU MUX path when it is intentionally active.
- P-core-only launch policies may be used for latency-sensitive games such as CS2 where the existing launcher requires them.
- Keep Snapper retention lean and avoid destructive Btrfs operations.
- Preserve portable chezmoi configuration: no hardcoded personal usernames, secrets, or machine-private credentials.
- Make the smallest robust fix and preserve unrelated work.

## 5. Audio baseline and freshness warning

The 2026-10-23 audit verified:

- PipeWire `1.6.9`.
- WirePlumber `0.5.18`.
- 48 kHz graph rate with quantum 512 in the audited setup.
- A persistent processed microphone path named `ghelper-audio` was functioning at that audit.
- ASUS speaker DSP, gaming audio routing, and A2DP-only Bluetooth policy were functioning in that audit.

Important freshness warning: audio/Dolby reverse-engineering work continued after the 2026-10-23 audit. Therefore, before changing microphone defaults, virtual sources, PipeWire filters, WirePlumber rules, or OBS routing, always inspect the live graph and current repo source. Do not assume the audit's default source is still active.

Primary references:

- `docs/audio/`
- `docs/system/audio-pipewire.md`
- `docs/system/audio-stack-status.md`
- `docs/ASUS_SPEAKER_DSP_MANIFEST.md`
- `docs/ASUS_SPEAKER_DSP_PARITY_REPORT.md`

## 6. Storage and filesystem caution

Storage documentation has changed over time and older documents may conflict with the actual current layout.

In particular, `docs/system/SYSTEM-REPRODUCIBILITY.md` contains historical assumptions about `/mnt/Games`, Btrfs, Hybrid GPU operation, and bootstrap behavior that must not be treated as current runtime truth without verification.

Before filesystem, mount, Steam-library, CoW/NoCoW, Snapper, or partition changes, verify at minimum:

```sh
lsblk -f
findmnt /
findmnt /home
findmnt /mnt/Games 2>/dev/null || true
findmnt /mnt/windows 2>/dev/null || true
sudo snapper list-configs 2>/dev/null || true
```

Never recommend `chattr +C`, Btrfs repair operations, filesystem conversion, or mount-option changes based solely on an older document.

## 7. Core workflow and tools

The workstation is intentionally keyboard-first and terminal-heavy.

Common components include:

- Sway/Wayland.
- Foot and Alacritty terminals.
- fish shell.
- Neovim/NvChad and Zed.
- Fuzzel/Rofi-style launch workflows.
- xremap for keyboard remapping.
- PipeWire/WirePlumber for audio.
- Steam/Proton/native Wayland gaming tools.
- systemd user services only where persistent behavior is justified.

Iosevka Nerd Font is the current preferred UI/terminal family in recent configuration.

## 8. Protected and high-risk areas

Before touching these areas, inspect current docs and source carefully:

- CS2 launcher and game-specific launch wrappers.
- MangoHud configuration.
- GPU/MUX switching and NVIDIA environment variables.
- PipeWire/WirePlumber routing and DSP.
- Btrfs/Snapper/filesystem operations.
- bootloader/initramfs configuration.
- systemd services that affect login, audio, GPU, suspend, or hardware control.
- encrypted chezmoi source and age identities.

Do not remove protection, immutability, or safety wrappers just to make an edit easier.

## 9. Agent control plane

For agents with live-machine access, prefer the existing control-plane commands:

```sh
agent-context system
agent-refresh
agent-check system
```

`agent-context` is the preferred bootstrap because it combines durable repo rules with fresh runtime state.

Runtime-generated state such as `~/.local/share/agent/environment.json` is evidence about the current machine, not permanent configuration. Do not commit generated runtime state into this repository.

See `docs/system/agent-control-plane.md` for the control-plane architecture.

## 10. Documentation map

Use this file to choose the next source, not as a reason to load the entire documentation tree.

- `docs/README.md`: global documentation index.
- `docs/system/system-philosophy.md`: stable goals and non-negotiable design principles.
- `docs/system/workstation-audit-2026-10-23.md`: last broad measured workstation audit at this sync.
- `docs/system/SYSTEM-REPRODUCIBILITY.md`: provisioning/recovery reference; verify stale assumptions before using.
- `docs/system/SYSTEM_CHANGELOG.md`: concise material system-change history for agents.
- `docs/audio/`: audio architecture and detailed DSP/routing docs.
- `docs/display/`: Wayland, dGPU, display, vibrance, brightness.
- `docs/gaming/`: game-specific launch/runtime configuration.
- `docs/theme/`: Base46/theme synchronization architecture.
- `docs/virtualization/`: Waydroid and Windows virtualization.
- `docs/bootloader/`: boot and Plymouth/GRUB customization.
- `docs/projects/`: custom project documentation.

Read only the relevant branch of documentation for a task.

## 11. Required update contract for every agent

For every verified durable workstation/configuration change made by an AI agent, documentation is part of the same implementation task:

1. Update the implementation in the correct source-of-truth file.
2. Validate the changed subsystem with the strongest safe check available.
3. Update at least one relevant detailed Markdown document under `docs/` so the resulting behavior and operational assumptions are discoverable without chat history.
4. Update the semantic portions of this file when a current-state fact, invariant, important path, protected baseline, or cross-agent assumption changes. The auto-managed runtime snapshot is refreshed by the local pre-commit hook for every durable system commit.
5. Append a concise verified entry to `docs/system/SYSTEM_CHANGELOG.md` for the commit.
6. If an older document now conflicts, correct it or explicitly mark the conflicting portion historical/stale.
7. Do not report the system change complete until the implementation, validation, and documentation are synchronized.

The repository pre-commit hook enforces steps 3 and 5 for local system commits and refreshes the generated runtime snapshot automatically. It does not write semantic documentation on behalf of the agent. Do not update current-state documentation for speculative plans; put future work in the appropriate roadmap/future document.

## 12. Known documentation conflicts to resolve gradually

The following are explicitly not authoritative when they disagree with fresher evidence:

- Older Hybrid/iGPU-desktop descriptions versus the verified `AsusMuxDgpu` baseline.
- Old internal-panel connector names versus live `swaymsg -t get_outputs` results.
- Old storage filesystem assumptions versus live `findmnt`/`lsblk` results.
- Old usernames or absolute `/home/<name>` paths in documentation versus portable `$HOME`/`~` configuration policy.
- Old audio defaults versus live PipeWire/WirePlumber state after ongoing Dolby/DSP work.

Agents should fix these conflicts opportunistically when working in the affected subsystem, rather than performing broad unrelated documentation rewrites.
