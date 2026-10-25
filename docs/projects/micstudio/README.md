# MicStudio: Low-Latency Linux Voice & Audio Studio

**High-performance native Rust audio studio, voice preset manager, and real-time DSP pipeline for PipeWire.**

- **Project Path:** [`/home/onyx/micstudio`](file:///home/onyx/micstudio)
- **Version:** `1.0.1` ([crates.io](https://crates.io/crates/micstudio/1.0.1), [GitHub Release](https://github.com/kmanisk/micstudio/releases/tag/v1.0.1))
- **Installed Binary:** `~/.local/bin/micstudio`
- **Architecture Invariant:** Governed by AI System Rule 10 (Strict internal microphone and Bluetooth A2DP enforcement).

---

## 1. Architecture & Invariants

MicStudio solves Linux microphone management and real-time DSP processing without requiring manual GUI interactions or unstable jack routing daemons:

```
[ Internal Laptop Mic: alsa_input.pci-0000_00_1f.3.analog-stereo ]
                         │
                         ▼
             [ DPDFNet Neural Denoiser ]
                         │
                         ▼
          [ DSP Chain: HPF 80Hz + EQ + Limiter ]
                         │
                         ▼
        [ Virtual Node: ghelper-audio (Priority 3000) ]
                         │
        ┌────────────────┴────────────────┐
        ▼                                 ▼
[ Games (CS2 / Apex) ]           [ Communication (Discord / OBS) ]
```

### Core Invariants
1. **Single Persistent Virtual Microphone (`ghelper-audio`)**:
   All communication apps, games (Counter-Strike 2), and recording tools bind strictly to `ghelper-audio`. Switching presets or toggling neural filters never changes the capture node or interrupts stream connections.
2. **Graph-Stable In-Process Switching**:
   LADSPA and PipeWire DSP parameters update dynamically within the running filter graph. No nodes are unlinked or reconstructed during preset transitions.
3. **Hardware Microphone Lock**:
   The capture pipeline binds directly to the internal laptop analog microphone (`alsa_input.pci-0000_00_1f.3.analog-stereo`). Bluetooth headsets are strictly barred from switching into degraded HSP/HFP telephony modes.

---

## 2. Capabilities

- **27 Voice Models & Presets:** Includes *Broadcast Clean*, *Radio Comm*, *Cyberpunk Vocoder*, *Deep Pitch*, *Demon*, *Anime Helium*, *Telephone Lo-Fi*, and *Cathedral Reverb*.
- **DPDFNet Neural AI Denoising:** Deep neural network noise suppression running at 45 dB noise floor, eliminating laptop fan noise and keyboard switches while preserving vocal dynamics.
- **Dynamic Live Controls:** Real-time adjustments for Input Gain, Noise Gate Threshold, De-Esser, Low-Cut Filter, Compression Ratio, and Sidetone Volume.
- **Dual Fullscreen Spectrograph:** Real-time FFT spectrum visualizer displaying pre-DSP vs post-DSP frequencies.
- **Feedback-Protected Sidetone:** Hardware-monitored sidetone with automatic feedback suppression when speakers are active.

---

## 3. CLI & TUI Interface

```bash
# Launch interactive Ratatui studio
micstudio

# Verify system health and LADSPA dependencies
micstudio doctor

# Switch preset directly via headless CLI
micstudio preset "Broadcast Clean"
micstudio preset "Radio Comm"

# Toggle neural noise suppression
micstudio denoise on
micstudio denoise off

# Check live pipeline status
micstudio status
```

---

## 4. Key References & Documentation

- [Upstream Repository README](./source-README.md)
- [MicStudio Architecture & Pipeline Specification](./architecture.md)
- [PipeWire Unified Architecture Documentation](file:///home/onyx/docs/audio/AUDIO_ARCHITECTURE.md)
- [Audio Stack Status](file:///home/onyx/docs/system/audio-stack-status.md)
- [Source Code Directory](file:///home/onyx/micstudio)
