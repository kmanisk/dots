# System Subsystem Map

This file routes workstation changes to the smallest relevant documentation set and, where available, a reusable agent skill.

Use it after `AGENTS.md`, `docs/system/SYSTEM_CONTEXT.md`, and `docs/system/system-philosophy.md`. Do not read every document listed here by default. Select only the subsystem(s) touched by the task.

Skills are procedural helpers, not machine-state authorities. Any machine-specific value inside a skill is subordinate to fresh live output, current repository source, `SYSTEM_CONTEXT.md`, and current subsystem documentation.

| Subsystem | Typical implementation paths / identifiers | Read or update | Preferred skill when available |
| --- | --- | --- | --- |
| Agent infrastructure | `AGENTS.md`, `CLAUDE.md`, `dot_agents/skills/**`, `dot_codex/**`, `dot_gemini/**`, `dot_config/opencode/**`, `scripts/git-hooks/**`, `scripts/*agent*`, `.github/workflows/system-docs-check.yml` | `docs/system/agent-control-plane.md`, this file | `documentation-style` |
| Audio / microphone | `dot_config/pipewire/**`, `dot_config/wireplumber/**`, audio/mic/speaker DSP helpers and units | `docs/audio/AUDIO_ARCHITECTURE.md`, `docs/system/audio-pipewire.md`, `docs/system/audio-stack-status.md`, ASUS DSP docs when relevant | `micstudio-audio` |
| Bluetooth | `bt-*`, BlueZ/WirePlumber Bluetooth policy, Bluetooth service helpers | `docs/audio/2026-10-20_BLUETOOTH_AUDIO_STUTTER.md`, `docs/audio/AUDIO_ARCHITECTURE.md`, audio status docs as needed | `bluetooth-autoconnect` |
| Display / GPU / vibrance | NVIDIA, `supergfxctl`, `prime-*`, `nvibrant`, `ctm-*`, brightness/backlight helpers, display-specific Sway configuration | `docs/display/`, `docs/system/vibrance.md` | `intel-drm-ctm-vibrance` only when the live topology actually uses the Intel display path; `cachyos-performance` for broader GPU/performance work |
| Sway / compositor | `dot_config/sway/**`, Sway helpers, scratchpads, idle/reload/window-management helpers | `docs/system/sway.md`, `docs/system/swayidle-locking-wakeup.md` when relevant | `60pct-keyboard-workflow` for keybinding/layout work |
| Input / keyboard | `dot_config/xremap/**`, keymaps, cursor/input helpers, Sway input and keybindings | `docs/system/xremap.md`, `docs/system/sway.md`, `docs/system/clipboard-shortcuts.md` when relevant | `60pct-keyboard-workflow` |
| Terminal / shell / editor | `dot_config/fish/**`, `dot_config/foot/**`, Alacritty, Neovim, Emacs, terminal helpers | `docs/system/terminal-shell.md`, `docs/system/foot.md`, `docs/system/neovim.md`, relevant editor docs | `emacs-ide-performance` only for Emacs-specific work |
| Theme / launcher UI | `dot_config/theme/**`, `dot_config/fuzzel/**`, `dot_config/rofi/**`, GTK theme/CSS, theme/launcher helpers | `docs/theme/README.md`, `docs/theme/theme-implementation.md`, `docs/theme/theme-system.md`; `docs/system/sway.md` when compositor geometry changes | none required |
| Gaming / Steam / Proton | CS2, Steam, Proton, MangoHud, Gamescope, LSFG, game launch wrappers | `docs/gaming/` and the specific game's directory | `elden-ring-proton`, `gta-iv-proton`, `cachyos-performance` as applicable |
| Waydroid / virtualization | Waydroid, libvirt, QEMU, VFIO, VM helpers/configuration | `docs/virtualization/waydroid-guide.md` or `docs/virtualization/windows-vfio-setup.md` | `waydroid-cachyos-root` for Waydroid root/runtime work |
| ASUS hardware control | RogTui, ASUS platform/profile/fan/power/battery helpers | `docs/system/rogtui-hardware-control.md`, `docs/projects/rogtui/README.md` when application behavior changes | `cachyos-performance` when performance policy is involved |
| Storage / filesystem / mounts | Btrfs, Snapper, mount helpers, `/mnt/Games`, `/mnt/windows`, rclone, file-management policies | `docs/system/SYSTEM-REPRODUCIBILITY.md`, `docs/system/file-management.md`, `docs/system/rclone.md` as applicable | `cachyos-performance` only for performance-related filesystem work |
| Boot / initramfs | GRUB, Plymouth, mkinitcpio, boot assets/hooks | `docs/bootloader/` | none required |
| Networking | NetworkManager/network helpers, Wi-Fi routing, connectivity scripts | closest relevant `docs/system/` networking reference; create a focused system document if none currently owns the behavior | none required |
| Packages / services / provisioning | `packages/**`, `systemd/**`, `install.sh`, `run_once_*`, `run_onchange_*`, general machine provisioning | `docs/system/SYSTEM-REPRODUCIBILITY.md` plus the owning subsystem document | `cachyos-performance` for package/performance policy |

## Routing rules

1. A change can touch multiple subsystems. Read and update the relevant documentation for each materially affected subsystem.
2. `docs/system/SYSTEM_CHANGELOG.md` is required for every durable workstation/configuration commit.
3. Update semantic portions of `docs/system/SYSTEM_CONTEXT.md` only when a cross-agent current-state fact, invariant, protected baseline, important path, or operating assumption changes. The local hook separately refreshes its generated runtime block.
4. If no existing document owns a durable behavior, create a focused document under the most appropriate `docs/` directory instead of adding unrelated material to a convenient file.
5. `docs/archive/`, `docs/future/`, dated audits, and personal learning notes do not satisfy active subsystem documentation requirements unless the task explicitly concerns those artifacts.
6. A skill can explain how to work on a subsystem, but it never replaces the owning documentation or live verification.
