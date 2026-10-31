---
name: micstudio-audio
description: Operational guidelines, architecture invariants, single persistent virtual mic contracts, DSP stage routing, and TUI workflows for MicStudio on PipeWire.
version: 1.0.0
---

## Authority and freshness

This skill is procedural guidance, not a current machine-state authority. Before using any machine-specific path, device name, GPU mode, desktop/session, filesystem, version, or service-state claim below, read `~/.local/share/chezmoi/AGENTS.md`, `~/.local/share/chezmoi/docs/system/SYSTEM_CONTEXT.md`, `~/.local/share/chezmoi/docs/system/SUBSYSTEM_MAP.md`, the owning subsystem documentation, and current repo source; verify live state when available. Higher-authority evidence overrides this skill. Treat dated verification blocks as historical evidence unless re-verified.

# MicStudio & PipeWire Audio Architecture Guidelines

## Core Invariants

1. **Single Persistent Virtual Microphone (`ghelper-audio`)**:
   - The system must expose and use a single persistent virtual microphone (`ghelper-audio`).
   - Games (Counter-Strike 2, Apex Legends, etc.), Discord, OBS, and recording applications MUST always connect exclusively to `ghelper-audio`.
   - Never create or switch between distinct clean and effect-specific virtual microphones; all 27 voice models switch internally inside the PipeWire DSP engine.

2. **Always-On Anti-Shout & Limiter Guard**:
   - The anti-shout compressor and final limiter (`-2.0 dBFS` ceiling) must remain active across every voice preset.
   - If audio levels clip, determine whether the source is analog pre-amp distortion (`[Input clipping suspected — check microphone gain]`) or digital safety limiting (`[LIMITING]`).

3. **Universal DPDFNet Neural AI Denoising**:
   - Neural noise suppression (DPDFNet) is active by default across all presets to remove laptop fan noise, room noise, and keyboard clatter without degrading speech clarity.

4. **Quiet Voice Boost (+4.0 dB baseline)**:
   - Leveler compression for low-level speech leveling is tuned to +4.0 dB on Natural Clean to ensure quiet whispers and calm callouts are easily audible without noise floor escalation.

5. **Resource & Anti-Bloat Discipline**:
   - Audio processing and UI must remain purely native Rust. Total CPU utilization should stay below 1.5% and resident memory below 40 MB.

---

## Interactive TUI Reference

* **Binary**: `~/.local/bin/micstudio`
* **Navigation**: `j` / `k` / `↑` / `↓`, `1`–`9` direct jump, `/` search.
* **Dual-Graph Fullscreen**: Press `m`, `M`, or `s` to toggle the full-screen dual graph (top: RTA spectrum analyzer, bottom: waterfall heatmap). Press `m` or `Esc` to return.
* **Preview Mode**: Press `g` to toggle embedded spectrograph between RTA spectrum and Waterfall heatmap.
* **Inspect DSP**: Press `Space` on any preset to open the full DSP chain and parameter modal.
* **Apply / Revert**: Press `Enter` to apply live, `c` to immediately revert to `Natural Clean`.
* **Reset System**: Press `r` to reset the active preset to factory defaults, `R` (`Shift+R`) to reset all 27 presets & clean mic to the factory baseline.
* **Monitoring**: Press `v` to toggle Hear Voice (zero-latency sidetone), `t` to toggle the input level VU meter, `p` to audition (5s record & play).

---

## Headless CLI Commands

```bash
# Check status
micstudio status

# Revert to Natural Clean
micstudio clean

# Reset presets to factory baseline
micstudio reset            # Natural Clean settings
micstudio reset all        # All 27 voice presets
micstudio reset <preset>   # Specific model

# Switch preset
micstudio voice <preset>
micstudio voice off

# Quiet Voice Boost
micstudio boost 4
micstudio boost off

# Sidetone monitoring
micstudio hear on|off

# Diagnostics & Verification
micstudio doctor
micstudio verify
```
