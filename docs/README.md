# System & Architecture Documentation Index

Welcome to the documentation tree for this **ASUS TUF Gaming F16 (FX608JH)** running **CachyOS (BORE/EEVDF, x86-64-v3)** with **Sway (Wayland)** and **i3wm (X11)**.

---

## Directory Structure

```
docs/
├── audio/               # Native PipeWire 1.6.9 + WirePlumber 0.5 unified audio architecture
├── display/             # Display pipeline, hardware vibrance (nvibrant), Wayland architecture
├── gaming/              # Native Linux & Proton configurations, modpacks, Gamescope & LSFG
│   ├── cs2/
│   ├── dark-souls-3/
│   ├── elden-ring/
│   └── gta-iv/
├── system/              # Philosophy, audio stack status, Sway, xremap, terminal, reproducibility
├── theme/               # Dynamic base46 theming engine & application templates
├── virtualization/      # Waydroid NVIDIA container (Venus/vtest) & Windows VFIO setup
├── bootloader/          # Dark Souls boot stack (GrubSouls III menu, DS3 Plymouth)
├── personal/            # Personal engineering guides (networking, Btrfs FHS architecture)
├── projects/            # Native Linux workstation & web software (tele, rogtui, micstudio, watchparty, sentinel, fetchit, ytui, legendary-tui)
├── archive/             # Retired/superseded subsystems (tgt Telegram TUI, intel-hardware-vibrance)
└── future/              # Future roadmap & optimization plans
```

---

## Category Overview

Current cross-system verification: [Workstation audit, 2026-10-23](system/workstation-audit-2026-10-23.md).
It distinguishes measured runtime state, implemented fixes, and remaining limitations.

### 1. [Audio (`docs/audio/`)](file:///home/onyx/docs/audio)
- [`AUDIO_ARCHITECTURE.md`](file:///home/onyx/docs/audio/AUDIO_ARCHITECTURE.md) (or `README.md`) — Complete architectural specification of the native PipeWire audio stack:
  - Single persistent virtual microphone (`ghelper-audio`, Priority 3000) with in-chain DPDFNet neural denoising (45 dB floor), 80 Hz HPF, broadcast EQ, and anti-shout limiting.
  - MicStudio v1.0.1 Ratatui TUI & CLI controlling 27 voice models, 7 live audio controls, dual fullscreen spectrograph, and feedback-protected sidetone.
  - ASUS TUF DAX3 Dolby Speaker DSP (`40-asus-speakers.conf` / `dax-speaker-route.lua`) with factory IR convolution (`Dolby_Speaker.irs`) and multi-voicing profiles (`music`, `dynamic`, `balanced`, `custom`, `experimental`).
  - Device-Agnostic Dolby Headphones (`42-dolby-headphones.conf`) with dialogue clarity EQ, AutoGain, and multiband dynamics.
  - Competitive gaming low-latency bypass (`sink.peace_gaming` / `gaming-audio-route.lua`).
  - Strict Bluetooth A2DP enforcement (`11-bluetooth-policy.conf`) suppressing handsfree HFP/HSP profiles (RULE 10).
  - Bluetooth A2DP stability: [`2026-10-20_BLUETOOTH_AUDIO_STUTTER.md`](file:///home/onyx/docs/audio/2026-10-20_BLUETOOTH_AUDIO_STUTTER.md) - daemonless manual control (`bt-select`, `bt-refuse-toggle`), applied WiFi power-save fix (A1), and pending SBC preference (A2) plus rtw89/btusb power-state proposals (B).

### 2. [Display (`docs/display/`)](file:///home/onyx/docs/display)
- [`dgpu-mode.md`](file:///home/onyx/docs/display/dgpu-mode.md) — Permanent `AsusMuxDgpu` hardware MUX topology, CS2 A/B latency findings.
- [`nvidia-vibrance.md`](file:///home/onyx/docs/display/nvidia-vibrance.md) — Active hardware Digital Vibrance via `nvibrant` directly through NVIDIA direct ioctl (zero daemon, zero shader overhead).
- [`wayland.md`](file:///home/onyx/docs/display/wayland.md) — Sway Wayland compositor baseline, environment variables, toolkit configuration.
- [`brightness-backlight.md`](file:///home/onyx/docs/display/brightness-backlight.md) — Direct sysfs backlight control (`change-brightness`), fast OSD notifications, and Workspace 4 suppression.

### 3. [Gaming (`docs/gaming/`)](file:///home/onyx/docs/gaming)
- [`README.md`](file:///home/onyx/docs/gaming/README.md) — Gaming architecture hub: dynamic GPU modes, Gamescope nested sessions, Btrfs no-CoW rules, and MangoHud protection (RULE 9).
- **Counter-Strike 2 ([`gaming/cs2/`](file:///home/onyx/docs/gaming/cs2))**: Native Linux Vulkan engine, 400+ FPS benchmark telemetry, automatic `sink.peace_gaming` routing.
- **Dark Souls III ([`gaming/dark-souls-3/`](file:///home/onyx/docs/gaming/dark-souls-3))**: Eden CYCLES ReShade graphics overhaul, Mod Engine 3 asset loader, Souls3Mod FPS unlock, Camera Fix (auto-rotate disabled), DS3 Randomizer GUI.
- **Elden Ring ([`gaming/elden-ring/`](file:///home/onyx/docs/gaming/elden-ring))**: Proton CachyOS-SLR, LSFG-VK 3x frame generation, ModEngine 2, EldenModLoader, CameraFix, Item & Enemy Randomizer GUI (.NET 8.0 runtime).
- **Grand Theft Auto IV ([`gaming/gta-iv/`](file:///home/onyx/docs/gaming/gta-iv))**: Complete Edition modpack, FusionFix, DXVK async configuration, Gillian's Guide reference.
- [`proton-prefix-dependency-management.md`](file:///home/onyx/docs/gaming/proton-prefix-dependency-management.md) — Runtimes, VC++, and .NET prefix management guide.

### 4. [System (`docs/system/`)](file:///home/onyx/docs/system)
- [`clipboard-shortcuts.md`](file:///home/onyx/docs/system/clipboard-shortcuts.md) — System clipboard & screenshot cheatsheet (Win+V, Caps+c, Caps+., multi-screenshot AI buffer, sleep display).
- [`desktop-commander-remote.md`](file:///home/onyx/docs/system/desktop-commander-remote.md) — Remote ChatGPT development bridge, headless systemd daemon, unrestricted filesystem access, Win+Alt+D live monitor scratchpad, and Clamshell integration.
- [`agent-control-plane.md`](file:///home/onyx/docs/system/agent-control-plane.md) — Shared `agent-context`/`agent-refresh`/`agent-check` layer for cross-chat rules, live environment state, repo handoffs, and phone-first remote coding.
- [`SUBSYSTEM_MAP.md`](system/SUBSYSTEM_MAP.md) — Cross-agent routing table from managed implementation paths to the smallest relevant documentation set and optional skill.
- [`system-philosophy.md`](file:///home/onyx/docs/system/system-philosophy.md) — Anti-bloat, performance invariants, headless-first design principles.
- [`audio-stack-status.md`](file:///home/onyx/docs/system/audio-stack-status.md) — Current state of MicStudio, 27 voice models, live audio controls, DAX3 speaker DSP, and WirePlumber routing policies.
- [`audio-pipewire.md`](file:///home/onyx/docs/system/audio-pipewire.md) — PipeWire low latency, clock/quantum policies, in-process filter chains, and Cava visualizer theming.
- [`sway.md`](file:///home/onyx/docs/system/sway.md) — Modular Sway configuration (`config.d/`), 60% ergonomic workspace layout, window rules, and fuzzel/rofi launchers.
- [`swayidle-locking-wakeup.md`](file:///home/onyx/docs/system/swayidle-locking-wakeup.md) — Screen locking (`swaylock`), display power-saving (`swayidle` DPMS off), hardware sleep (`s2idle`), and peripheral wakeup mechanics (USB mouse vs internal keyboard vs Katana BT).
- [`xremap.md`](file:///home/onyx/docs/system/xremap.md) — 60% keyboard architecture, CapsLock virtual layer, and full remap reference.
- [`terminal-shell.md`](file:///home/onyx/docs/system/terminal-shell.md) — Fish shell configuration, Alacritty and Kitty terminals, Starship prompt, and helper scripts.
- [`foot.md`](file:///home/onyx/docs/system/foot.md) — Foot terminal emulator architecture, client-server benchmarks, and memory comparison.
- [`tele-sixel.md`](system/tele-sixel.md) — Tele Sixel source branch, correctness fixes, validation, and upstream contribution status (PR #318). Centralized Tele hub: [`docs/projects/tele/`](file:///home/onyx/docs/projects/tele/README.md).
- [`neovim.md`](file:///home/onyx/docs/system/neovim.md) — Custom NvChad setup, base46 disk cache, keybindings, runners, and plugins.
- [`file-management.md`](file:///home/onyx/docs/system/file-management.md) — Yazi terminal file manager, Zed typography standards & Vim chords, and Thunar.
- [`rclone.md`](file:///home/onyx/docs/system/rclone.md) — On-demand Google Drive mount, zero idle RAM, fstab automounting, and storage taxonomy.
- [`vibrance.md`](file:///home/onyx/docs/system/vibrance.md) — Display vibrance state and hardware control mechanisms.
- [`SYSTEM-REPRODUCIBILITY.md`](file:///home/onyx/docs/system/SYSTEM-REPRODUCIBILITY.md) — Clean reinstall guide, Snapper snapshots, package list.
- [`reference.md`](file:///home/onyx/docs/system/reference.md) — Fast command reference and hardware specifications.
- [`future-plans.md`](file:///home/onyx/docs/system/future-plans.md) — Upcoming system optimizations and features.

### 5. [Theme (`docs/theme/`)](file:///home/onyx/docs/theme)
- [`README.md`](file:///home/onyx/docs/theme/README.md) — Architecture of the dynamic Base46 theme sync engine (sub-100ms switching, ephemeral sandboxing, zero daemons).

### 6. [Virtualization (`docs/virtualization/`)](file:///home/onyx/docs/virtualization)
- [`waydroid-guide.md`](file:///home/onyx/docs/virtualization/waydroid-guide.md) — Waydroid with proprietary NVIDIA GPU passthrough via `waydroid-nvidia-bin` (Venus over vtest socket on RTX 5050 Mobile), LineageOS 20 GAPPS, Magisk Delta root, and Houdini ARM translation.
- [`windows-vfio-setup.md`](file:///home/onyx/docs/virtualization/windows-vfio-setup.md) — KVM/QEMU GPU passthrough setup and IOMMU configuration.

### 7. [Bootloader (`docs/bootloader/`)](file:///home/onyx/docs/bootloader)
- [`dark-souls-boot.md`](file:///home/onyx/docs/bootloader/dark-souls-boot.md) — Active Dark Souls boot stack (GrubSouls III menu, DS3 Plymouth splash, mkinitcpio hooks, restore procedure).
- [`minecraft.md`](file:///home/onyx/docs/bootloader/minecraft.md) — Preserved Minecraft boot stack (MineGRUB World Selection menu, `mc` Plymouth splash, font/pango mkinitcpio hooks, activation procedure). Backup: `~/.backup/minecraft-boot-20261003/`.

### 8. [Future Roadmap (`docs/future/`)](file:///home/onyx/docs/future)
- [`interview.md`](file:///home/onyx/docs/future/interview.md) — Real-time AI interview assistant & screen cloaking architecture (Meetingly AI Windows WASAPI loopback & Win32 WDA cloaking, Linux Sway virtual headless display mirror, and PipeWire audio).
- [`localllm.md`](file:///home/onyx/docs/future/localllm.md) — Local LLM hardware performance map & MoE offload roadmap (RTX 5050 8 GB GDDR7 @ 384 GB/s, 16 GB single-channel vs 32 GB dual-channel DDR5-4800, Qwen3.5-9B sweet spot, and Qwen3.6-35B-A3B CPU-MoE offloading).
- [`performance-audit-plan.md`](file:///home/onyx/docs/future/performance-audit-plan.md) — Latency and kernel performance audit methodology.
- [`voice-models-roadmap.md`](file:///home/onyx/docs/future/voice-models-roadmap.md) — High-fidelity neural voice synthesis and RVC/DDSP TensorRT exploratory roadmap.
- [`system-audit-2026-10-17.md`](file:///home/onyx/docs/future/system-audit-2026-10-17.md) — Full-system audit: boot, Bluetooth, Btrfs scrub, initramfs, and storage findings with prioritized fix playbook.

### 9. [Personal Guides (`docs/personal/`)](file:///home/onyx/docs/personal)
- [`real-world-networking.md`](file:///home/onyx/docs/personal/real-world-networking.md) — Real-world networking and troubleshooting reference: MTU, TCP vs UDP, DNS pipelines (UDP 53 vs DoT 853 vs DoH 443), ISP DPI censorship mechanics (plaintext SNI vs ECH), and socket programming primitives.
- [`linux-filesystem-btrfs.md`](file:///home/onyx/docs/personal/linux-filesystem-btrfs.md) — Linux Root Filesystem, Filesystem Hierarchy Standard (FHS), and Btrfs subvolume architecture reference.
- [`wayland-screen-share-overlay-cloaking.md`](file:///home/onyx/docs/personal/wayland-screen-share-overlay-cloaking.md) — Wayland screen sharing & overlay cloaking architecture (Sway virtual headless display decoupling, wlroots screencopy mechanics, borderless tiling stacking order, and zero-leak interview setups).
- [`meetingly-windows-setup.md`](file:///home/onyx/docs/meetingly-windows-setup.md) — Meetingly AI and local Ollama setup guide on Windows (RTX 5050 8 GB VRAM budget, WASAPI loopback routing, Win32 window cloaking, and hybrid cloud web search).

### 10. [Projects (`docs/projects/`)](file:///home/onyx/docs/projects)
- [`README.md`](file:///home/onyx/docs/projects/README.md) — Centralized directory index of custom-built applications with symlinked repository documentation.
- **[Tele (`docs/projects/tele/`)](file:///home/onyx/docs/projects/tele/README.md)** — Terminal Telegram client (Bubble Tea) with upstream contributions: PR #318 (Sixel inline previews) and PR #321 (progressive range-based video streaming to mpv).
- **[rogtui (`docs/projects/rogtui/`)](file:///home/onyx/docs/projects/rogtui/README.md)** — Hardware control center for ASUS TUF and ROG laptops (fan curves, MUX switch, power limits; v0.1.3 on crates.io).
- **[MicStudio (`docs/projects/micstudio/`)](file:///home/onyx/docs/projects/micstudio/README.md)** — PipeWire virtual microphone (`ghelper-audio`), 27 voice models, DPDFNet neural denoising, live controls, and dual spectrograph (v1.0.1 on crates.io).
- **[WatchParty (`docs/projects/watchparty/`)](file:///home/onyx/docs/projects/watchparty/README.md)** — Self-hostable synchronized video playback room with millisecond drift correction, live chat, and Rosé Pine interface.
- **[Sentinel (`docs/projects/sentinel/`)](file:///home/onyx/docs/projects/sentinel/README.md)** — High-throughput API health, latency, and uptime telemetry monitoring platform with WebSocket streaming.
- **[FetchIt (`docs/projects/fetchit/`)](file:///home/onyx/docs/projects/fetchit/README.md)** — High-performance TUI download manager and multi-pattern CDN resolver with aria2c and auto-unarchive.
- **[ytui & ytui-gui (`docs/projects/ytui/`)](file:///home/onyx/docs/projects/ytui/README.md)** — Keyboard-first YouTube client combining Ratatui TUI and GTK4 GUI with embedded libmpv, SponsorBlock, and RYD.
  - [`future.md`](file:///home/onyx/docs/projects/ytui/future.md) — SmartTube parity matrix, ExoPlayer-style chunk streaming architecture, and GUI roadmap.
- **[legendary-tui (`docs/projects/legendary-tui/`)](file:///home/onyx/docs/projects/legendary-tui/README.md)** — Fast Ratatui TUI frontend for Legendary Epic Games Store CLI with background queue and cloud saves.
- **[launcher-runner-bridge (`docs/projects/launcher-runner-bridge/`)](file:///home/onyx/docs/projects/launcher-runner-bridge/README.md)** — Execution bridge chaining systemd user scopes, GameMode, Gamescope, and UMU Proton.
- **[ssh-bootstrap (`docs/projects/ssh/`)](file:///home/onyx/docs/projects/ssh/README.md)** — Idempotent remote SSH setup over Tailscale for Windows and Linux.


