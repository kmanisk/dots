# Custom Software Projects Index

This directory catalogs custom-built, native Linux terminal, web, and desktop applications engineered specifically for performance, keyboard efficiency, and zero daemon bloat on this machine.

---

## Projects Directory

| Project | Type | Description | Key Technologies | Documentation |
| :--- | :--- | :--- | :--- | :--- |
| **`tele`** | TUI (Telegram) | Terminal Telegram client with inline Sixel previews (PR #318) and progressive range-based video streaming (PR #321) | Go, Bubble Tea, gotd, Sixel, mpv | [tele/README.md](file:///home/onyx/docs/projects/tele/README.md) |
| **`rogtui`** | TUI | Lightweight hardware control center for ASUS TUF and ROG laptops (v0.1.3 on crates.io) | Rust, Ratatui, D-Bus, asusd, supergfxd | [rogtui/README.md](file:///home/onyx/docs/projects/rogtui/README.md) |
| **`micstudio`** | TUI + CLI + Audio | Low-latency voice studio and PipeWire DSP manager with 27 models (v1.0.1 on crates.io) | Rust, Ratatui, PipeWire, LADSPA, DPDFNet | [micstudio/README.md](file:///home/onyx/docs/projects/micstudio/README.md) |
| **`watchparty`** | Web Application | Self-hostable synchronized video playback room with millisecond drift correction and live chat | TypeScript, React 19, Express, Socket.IO | [watchparty/README.md](file:///home/onyx/docs/projects/watchparty/README.md) |
| **`sentinel`** | Web + Daemon | Real-time API health, latency, uptime telemetry, and incident alerting platform | TypeScript, Fastify, React 18, PostgreSQL, Redis | [sentinel/README.md](file:///home/onyx/docs/projects/sentinel/README.md) |
| **`fetchit`** | TUI | Fast download manager and multi-pattern CDN resolver with aria2c and auto-unarchive | Go, Bubble Tea, aria2c, xtractr, chromedp | [fetchit/README.md](file:///home/onyx/docs/projects/fetchit/README.md) |
| **`ytui` & `ytui-gui`** | TUI + GUI | Keyboard-first YouTube client with embedded libmpv, SponsorBlock, and RYD | Rust, Ratatui, GTK4, libmpv, InnerTube | [ytui/README.md](file:///home/onyx/docs/projects/ytui/README.md) |
| **`legendary-tui`** | TUI | Keyboard-driven Epic Games Store manager and download queue | Rust, Ratatui, Legendary CLI, Sixel/Kitty | [legendary-tui/README.md](file:///home/onyx/docs/projects/legendary-tui/README.md) |
| **`launcher-runner-bridge`** | CLI / Bridge | Process bridge chaining systemd user scopes, GameMode, Gamescope, and UMU Proton | Python, systemd, Gamescope, UMU | [launcher-runner-bridge/README.md](file:///home/onyx/docs/projects/launcher-runner-bridge/README.md) |
| **`ssh`** | Scripts | Idempotent remote SSH setup over Tailscale for Windows and Linux | PowerShell, Bash, OpenSSH, Tailscale | [ssh/README.md](file:///home/onyx/docs/projects/ssh/README.md) |

---

## Common Architectural Principles

1. **Native Performance:** Written strictly in Rust or Go for minimal startup latency (<5ms) and low memory footprint (<300 MB for GUI, <20 MB for TUIs).
2. **Keyboard-First Workflow:** Every application supports Vim navigation keys (`j`, `k`, `h`, `l`, `gg`, `G`, `/`) without requiring mouse interaction.
3. **Zero Daemon Bloat:** Applications do not spawn standing background daemons, running only when invoked by the user or as scoped, headless systemd user services.
4. **Hardware Acceleration:** Full support for direct MUX dGPU mode, VA-API iGPU decoding, and Vulkan presentation pipelines.
5. **Centralized Documentation Integration:** Project subdirectories maintain a dedicated overview `README.md` alongside direct symlinks to the source repositories (`source-README.md`, `SPEC.md`, `DESIGN.md`, etc.).
