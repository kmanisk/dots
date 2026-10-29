# Canonical System Context

This is the primary machine-context document for AI agents working on this repository.

It is not a replacement for the detailed subsystem documentation. Its job is to provide one current entry point, resolve conflicts between older documents, record important invariants, and tell an agent what must be verified before making changes.

Last synchronized with repository state: 2026-10-29.
Latest repository change considered during this sync: `1a533b95dd9d6c8661b8f617b5914c0d3f369f6f` (`feat(sway): central UI scaling with scale-aware system chrome`).
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

As of repository commit `1a533b95dd9d6c8661b8f617b5914c0d3f369f6f`, Sway output scaling is the central application/UI scale source.

Relevant files include:

- `dot_config/sway/config.d/45-ui-scale.conf`
- `dot_config/sway/config.d/99-ui-scale.conf` when generated/persisted
- `dot_config/ui-metrics.conf`
- `dot_local/bin/executable_ui-scale`
- `dot_local/bin/executable_ui-sync`
- `dot_config/theme/hooks.d/executable_50-ui-chrome`

Do not reintroduce stacked Chromium/device-scale overrides unless there is a measured reason. Inspect the current generated scale state before changing font or chrome sizes.

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

After a verified material change to the workstation or its managed configuration:

1. Update the implementation in the correct source-of-truth file.
2. Validate the behavior.
3. Update the relevant detailed subsystem document if behavior/architecture changed.
4. Update this file if any current-state fact, invariant, important path, protected baseline, or cross-agent assumption changed.
5. Append a short entry to `docs/system/SYSTEM_CHANGELOG.md`.
6. If an older document now conflicts, correct it or explicitly mark the conflicting portion historical/stale.

Do not update this file for speculative plans. Put future work in the appropriate roadmap/future document.

## 12. Known documentation conflicts to resolve gradually

The following are explicitly not authoritative when they disagree with fresher evidence:

- Older Hybrid/iGPU-desktop descriptions versus the verified `AsusMuxDgpu` baseline.
- Old internal-panel connector names versus live `swaymsg -t get_outputs` results.
- Old storage filesystem assumptions versus live `findmnt`/`lsblk` results.
- Old usernames or absolute `/home/<name>` paths in documentation versus portable `$HOME`/`~` configuration policy.
- Old audio defaults versus live PipeWire/WirePlumber state after ongoing Dolby/DSP work.

Agents should fix these conflicts opportunistically when working in the affected subsystem, rather than performing broad unrelated documentation rewrites.
