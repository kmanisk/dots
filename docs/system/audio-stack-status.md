# CachyOS Audio Stack & MicStudio Status

**Target Machine:** ASUS TUF Gaming F16 (FX608JH)  
**Hardware Codec:** Realtek ALC256 HD Audio · Bluetooth A2DP (Soundcore Q20i)  
**Display / Compositor:** Sway (Wayland) / i3wm (X11) on RTX 5050 Mobile (`AsusMuxDgpu`)  
**Core Framework:** Native PipeWire 1.6.9 + WirePlumber 0.5.18 (100% Daemonless & Headless DSP)  
**Last Updated:** October 17, 2026  

---

## 1. Executive Summary

The entire audio infrastructure is unified into a native, high-performance, daemonless PipeWire architecture:

1. **Legacy Suites Fully Retired**: All legacy Python daemons (`dusky_audio_studio.py`, `dusky-audio-dsp`), EasyEffects, and separate virtual source switching have been removed.
2. **Unified Single-Device Architecture (`ghelper-audio`)**: Games (CS2, Apex Legends, etc.), Discord, OBS, and browsers capture exclusively from node `ghelper-audio` (Priority 3000). Creative voice preset switching occurs live in-line without tearing down streams or changing devices.
3. **Universal DPDFNet Neural AI Denoising**: Upstream Ceva DeepFilterNet lineage model (`/usr/lib/ladspa/libdpdfnet_ladspa.so` via `hushmic-bin`) active across all presets with a 45 dB soft attenuation floor that eliminates keyboard and fan noise without cutting speech onset.
4. **Anti-Shout Guard & Quiet Voice Boost**: 
   - Anti-shout compressor (5ms attack, 120ms hold, 500ms release) and brickwall limiter (-2.0 dBFS ceiling) protect against clipping.
   - Low-level speech leveling (+4.0 dB boost) on Natural Clean lifts soft conversational speech into broadcast clarity.
5. **MicStudio v1.0.0 Deployed**: Native Rust binary (`~/.local/bin/micstudio` with wrapper `mic`) controlling 27 tuned voice models, 7 live audio controls, fullscreen dual-graph spectrograph, and safe sidetone monitoring.
6. **ASUS TUF DAX3 Dolby Speaker DSP**: Factory Windows DAX3 impulse response convolution (`Dolby_Speaker.irs`), 45 Hz driver excursion protection high-pass filter, and 7 tuned voicings:
   - `tuned`: Focused & Natural (default, slev 1.30 spatializer width, clean +11.6 dB presence curve).
   - `tuned-old`: Wide staging (slev 1.82 expansive soundstage).
   - `custom`: Windows Dolby Access Custom 2 profile (+11.6 dB presence peak).
   - `dynamic`: Windows DAX3 default (+9.0 dB makeup gain, slev 1.45, AutoGain Leveler + Spatial).
   - `music`: Windows DAX3 Audiophile (+11.0 dB makeup gain, uncompressed natural dynamics).
   - `balanced`: Reference Linux baseline (+9.0 dB makeup gain, slev 1.0).
   - `experimental`: Tuned curve with pre-convolver harmonic bass enhancement.
7. **Dynamic Active Target Preservation on Preset Switch**: Both `spk` and `rofi-speaker-dsp` detect the active physical destination before runner restarts. Switching presets while on Bluetooth or wired headphones preserves the default sink, keeps `Dolby_Speaker` strictly disabled (`filter.smart.disabled = true`), keeps `Dolby_Headphones` active, and never leaks or hijacks audio to laptop speakers.
8. **Self-Healing Hardware Volume Control Guardrails (`volume-notify`)**: `resolve_physical_sink()` detects true hardware endpoints (`bluez_output.*` or `alsa_output.*`) using WirePlumber default metadata and active links. Automatically heals `pactl set-default-sink` if captured by virtual nodes, ensuring keyboard volume keys and OSD sliders always adjust the active physical device. Continuously pins all filter inputs (`Dolby_Speaker`, `Dolby_Headphones`, `sink.peace_gaming`) to 1.0 (100% unmute) to preserve full digital headroom.
9. **ALSA Port Authority & Jack State Availability**: Set `api.acp.auto-port = false` in WirePlumber to give WirePlumber direct authority over port selection. Overrode ALC256 speaker path jack conditions with `state.plugged = unknown` (`~/.config/alsa-card-profile/mixer/paths/analog-output-speaker.conf`), ensuring the internal speaker port is permanently available rather than falsely marked `not available` when the 3.5mm jack is unplugged.
10. **Device-Agnostic Dolby Headphones**: Dedicated headphone chain (`42-dolby-headphones.conf`) with dialogue clarity, AutoGain leveler, and multiband dynamics.
11. **Automated WirePlumber Route Switching**:
    - `dax-speaker-route.lua` enforces strict mutual exclusion: `Dolby_Speaker` engages on laptop speakers; `Dolby_Headphones` engages on 3.5mm jack / Bluetooth. Respects `filter.smart.user_disabled` live so `spk on` / `spk off` toggles apply immediately.
    - `gaming-audio-route.lua` intercepts competitive games into `sink.peace_gaming` (Peace PUBG EQ + LoudMax limiter), bypassing Dolby processing for uncolored spatial positioning, and dynamically tracks `default.audio.sink` metadata so gaming audio hot-reloads seamlessly across devices selected via `Alt + Shift + O`.
    - Stream migration scripts (`toggle-audio-sink`, `spk`, `rofi-speaker-dsp`) strictly exclude the full competitive gaming tuple (`cs2`, `counter-strike`, `tslgame`, `pubg`, `r5apex`, `apex legends`, `discovery.exe`, `the finals`, `huntgame`).
12. **Strict Bluetooth A2DP Enforcement (RULE 10)**: Bluetooth headsets are locked to high-fidelity A2DP (`AAC`/`SBC-XQ`). Hands-free profile (HFP/HSP) is suppressed; all recording strictly uses the laptop microphone (`ghelper-audio`).
    - **Automated Reconnection**: `bt-autoconnect.service` monitors paired target devices (`Boult BassBox`, `soundcore Q20i`) via D-Bus and connects them automatically upon power-on or system resume without manual intervention.

---

## 2. Signal Routing Architecture

```
                                [ Hardware Microphone ]
                      (alsa_input.pci-0000_00_1f.3.analog-stereo)
                                           │
                                           ▼
                    ┌─────────────────────────────────────────────┐
                    │    Unified Mic Pipeline (40-mic.conf)       │
                    │─────────────────────────────────────────────┤
                    │ 1. 80 Hz Sub-Rumble High-Pass Filter        │
                    │ 2. DPDFNet Neural AI Denoiser (45 dB Floor) │
                    │ 3. Latency Alignment Delay (80 ms context)  │
                    │ 4. In-Chain Voice FX Engine (27 Models)     │
                    │    (RubberBand, RingMod, Decimator, etc.)   │
                    │ 5. Broadcast Parametric EQ Cascade          │
                    │ 6. Studio Anti-Shout Compressor             │
                    │    (+4 dB Quiet Voice Boost on Clean)       │
                    │ 7. Studio True Peak Limiter (-2 dBFS Ceiling│
                    │    +2 dB Creative Model Boost on FX)        │
                    └─────────────────────────────────────────────┘
                                           │
                                           ▼
                             [ Persistent Virtual Mic ]
                                  (ghelper-audio)
                 (Exclusive input for Games, Discord, OBS, Browsers)

                                [ Application Playback ]
                                           │
               ┌───────────────────────────┴───────────────────────────┐
               ▼                                                       ▼
    [ Competitive Games ]                                   [ Desktop & Media Apps ]
  (CS2, The Finals, Apex, PUBG)                               (Brave, Discord, Media)
               │                                                       │
               ▼                                                       ▼
      [ sink.peace_gaming ]                                [ WirePlumber Smart Filters ]
  (Peace PUBG EQ + LoudMax Limiter)                           (dax-speaker-route.lua)
               │                                           ┌───────────┴───────────┐
               │                                           ▼                       ▼
               │                                  [ Dolby Headphones ]     [ Dolby Speaker DSP ]
               │                                 (42-dolby-headphones)     (asus-speaker-dsp)
               │                                           │                       │
               └───────────────────┬───────────────────────┘                       │
                                   ▼                                               ▼
                       [ Active Hardware Sink ]                       [ ALC256 Internal Speakers ]
                  (Soundcore Q20i BT / Wired Jack)                    (Dolby_Speaker FIR Corrected)
```

---

## 3. MicStudio TUI & CLI Architecture

### User Interface & Navigation
* **Presets View**: 27 factory presets across 5 categories (*Broadcast & Natural*, *Characters*, *Sci-Fi & Cyber*, *Retro & Comms*, *Creative FX*).
* **Live Audio Controls**: 7 real-time parameters adjustable via `h`/`l`/`←`/`→` (cycle via `Tab` or `Shift+J`/`Shift+K`):
  1. `DPDFNet Denoise` (0 – 48 dB attenuation floor, default 45 dB)
  2. `Quiet Voice Boost` (0 – 12 dB speech leveling, default +4.0 dB)
  3. `Output Gain` (-12 to +12 dB master volume trim)
  4. `Effect Mix` (0% – 100% wet/dry balance)
  5. `Hear Voice` (zero-latency sidetone monitoring)
  6. `VU Meter` (real-time RMS and peak indicator with clipping hold)
  7. `Spectrograph` (frequency spectrum or waterfall heatmap)
* **Fullscreen Dual-Graph (`m` / `M` / `s`)**: Fullscreen view displaying high-res RTA spectrum on top and Waterfall heatmap on bottom.
* **Embedded Mode Switch (`g` / `G`)**: Toggles side-pane spectrograph between RTA spectrum bars and Waterfall heatmap.
* **Inspect DSP Modal (`Space`)**: Opens modal detailing the 7-stage filter chain, active parameters, and telemetry.
* **Instant Revert (`c`)**: Reverts instantly to Natural Clean.
* **Factory Reset**: `r` restores highlighted preset; `R` (`Shift+R`) resets all 27 presets & clean mic to the factory baseline.
* **Hot-Reload (`F5` / `Ctrl+R`)**: Reloads `~/.config/micstudio/presets.toml` live from disk without restarting PipeWire.

### Configuration Files
| Path | Description |
| :--- | :--- |
| `~/.config/micstudio/presets.toml` | 27 voice model parameter definitions |
| `~/.config/micstudio/settings.toml` | Clean mic preferences (DPDFNet attenuation, boost, gain, sidetone state) |
| `~/.config/pipewire/pipewire.conf.d/40-mic.conf` | PipeWire filter-chain instantiating `ghelper-audio` |
| `~/.config/pipewire/pipewire.conf.d/30-peace-gaming.conf` | Peace Gaming competitive audio sink |
| `~/.config/pipewire/pipewire.conf.d/42-dolby-headphones.conf` | Device-agnostic Dolby Headphone enhancement |
| `~/.config/wireplumber/wireplumber.conf.d/11-bluetooth-policy.conf` | Strict Bluetooth A2DP policy |
| `~/.config/bt-autoconnect/devices.json` | Configured Bluetooth auto-connect target audio devices |

---

## 4. Complete CLI Command Reference

All subcommands are accessible via `micstudio` or wrapper `mic`:

| Category | Command | Description |
| :--- | :--- | :--- |
| **Status** | `mic status` / `micstudio status` | Displays active default sink/source, DSP levels, and active preset |
| **Diagnostics** | `mic doctor` / `micstudio doctor` | Verifies ALC256 hardware mic, unified source, and speaker DSP |
| **Full Stack** | `audio doctor` | Runs 11-point health suite verifying services, routing, and invariants |
| **System Status** | `audio status` | Overview of gaming routes, smart filters, and Bluetooth profiles |
| **Bluetooth Auto** | `bt-autoconnect --status` | Live connection status of target Bluetooth audio devices |
| | `bt-autoconnect --list` | Lists configured target devices from `devices.json` |
| | `bt-autoconnect --add <MAC> <Name>` | Adds new device to auto-connect configuration |
| | `bt-autoconnect --remove <MAC>` | Removes device from auto-connect configuration |
| **Clean Mic** | `mic clean` | Reverts active microphone to Natural Clean broadcast speech |
| **Reset** | `mic reset` | Resets Natural Clean settings to default (+4dB boost, 45dB denoise) |
| | `mic reset all` | Resets all 27 voice models and clean mic to factory defaults |
| | `mic reset "<name>"` | Resets specific model parameters to factory defaults |
| **Presets** | `mic voice "<Preset>"` | Switches to named voice preset live (`mic voice "Deep Voice"`) |
| | `mic voice off` | Disables creative FX, returning to clean broadcast |
| | `mic list` | Lists all 27 presets with category headers |
| | `mic preset reload` | Hot-reloads `presets.toml` from disk |
| **Noise & Boost** | `mic noise <dB>` | Sets DPDFNet neural noise suppression attenuation (0–48 dB) |
| | `mic boost <dB>` | Adjusts Quiet Voice Boost speech leveling (+0 to +12 dB) |
| | `mic gain <dB>` | Adjusts studio master output gain |
| **Monitoring** | `mic hear on\|off` | Toggles zero-latency sidetone monitor loopback |
| | `mic spectrograph` | Opens standalone terminal FFT spectrum analyzer |
| | `mic spectrograph --waterfall` | Opens standalone waterfall heatmap spectrograph |
| **Speaker DSP** | `spk apply <profile>` | Switches ASUS TUF DAX3 speaker voicing (`music`, `dynamic`, `balanced`, `custom`, `experimental`) |
| | `spk status` | Displays active speaker profile and convolver state |
| | `rofi-speaker-dsp` | Interactive Rofi menu for live speaker profile selection |

---

## 5. Automated Health Audits (`audio doctor` 11-Point Suite)

The system verification suite confirms all invariants are satisfied:

1. **Systemd Services**: `pipewire.service`, `wireplumber.service`, `pipewire-pulse.service`, and `asus-speaker-dsp.service` active.
2. **Clock Rate & Quantum**: Fixed single clock domain at 48000 Hz, quantum bounded between 64 and 2048.
3. **Process Collision**: Zero duplicate, rogue, or orphaned audio processes.
4. **Node Duplication**: Confirms single instance of `ghelper-audio` and smart filter nodes.
5. **Double Processing**: Verifies gaming streams do not concurrently route through both Peace Gaming EQ and Dolby chains.
6. **Gaming Audio Route**: Verifies `playback.peace_gaming` routes to the active output sink.
7. **Bluetooth Policy**: Verifies no `bluez_input` nodes exist and Bluetooth is locked to A2DP.
8. **Speaker FIR Isolation**: Proves `effect_input.Dolby_Speaker` cannot link while headphones or Bluetooth are active.
9. **Microphone Invariant**: Validates `ghelper-audio` is locked as the system default source (Priority 3000).
10. **Virtual Sink Policy**: Ensures `sink.peace_gaming` has `priority.session = -1` and never captures default desktop audio.
11. **Baseline Snapshot**: Confirms backup snapshot integrity at `~/.config/pipewire/backup/20261010_unified_audit`.
