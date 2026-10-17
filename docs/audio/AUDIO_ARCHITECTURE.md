# CachyOS & PipeWire Unified Audio Architecture

**Target System:** CachyOS rolling · Sway (Wayland) / i3wm · Intel i5-13450HX + RTX 5050 Mobile (AsusMuxDgpu / Hybrid)  
**Primary Codec:** Realtek ALC256 HD Audio · Bluetooth A2DP (Soundcore Q20i)  
**Audio Framework:** Native PipeWire 1.6.9 + WirePlumber 0.5 (100% Daemonless & Headless DSP)  
**Document Location:** `~/.local/share/chezmoi/docs/audio/AUDIO_ARCHITECTURE.md`

---

## 1. Executive Architecture Overview

All system audio processing is managed natively inside the PipeWire multimedia graph using in-process SPA modules, LADSPA plugins, and WirePlumber 0.5 Lua event hooks. No background user daemons, external Python processes, or third-party runtime frameworks (such as HushMic or EasyEffects) run in the background.

```mermaid
flowchart TD
    subgraph CapturePipeline["Unified Microphone Capture Pipeline (40-mic.conf)"]
        HW_MIC["Internal ALC256 Mic<br/>(alsa_input.pci-0000_00_1f.3.analog-stereo)"] --> HPF_80["1. 80 Hz High-Pass Filter<br/>(bq_highpass, Q=0.707)"]
        HPF_80 --> DPDFNET["2. DPDFNet Neural Denoiser<br/>(libdpdfnet_ladspa.so, Attn=45dB)"]
        DPDFNET --> DELAY_80["3. Latency Compensation<br/>(builtin delay, 80 ms)"]
        DELAY_80 --> FX_CHAIN["4. Voice FX Processor (In-Chain Hot-Reload)<br/>(RubberBand, RingMod, Decimator, Flanger, Delay, FX EQ)"]
        FX_CHAIN --> EQ_CASCADE["5. Broadcast Parametric EQ<br/>(-2dB@80Hz, -1.5dB@400Hz, +1.5dB@3.5kHz)"]
        EQ_CASCADE --> COMP["6. Anti-Shout Compressor<br/>(LSP Mono, 5ms attack, 120ms hold, 500ms release)"]
        COMP --> LIM["7. Lookahead Peak Limiter<br/>(LSP Mono, -2 dBFS ceiling, +2dB model boost)"]
        LIM --> GHELPER_CLEAN["Virtual Source: ghelper-audio<br/>(MicStudio Unified Source, Priority 3000)"]
    end

    subgraph PlaybackPipeline["Playback & Routing Pipeline (30-peace-gaming.conf & WirePlumber)"]
        GAMES["Competitive Games<br/>(CS2, The Finals, PUBG, Apex, ARC Raiders)"] --> PEACE_SINK["sink.peace_gaming<br/>(Peace PUBG EQ + LoudMax Limiter)"]
        APPS["Desktop & Media Apps<br/>(Brave, Discord, Media Players)"] --> SMART_FILTERS["WirePlumber Smart Filters<br/>(dax-speaker-route.lua)"]
        
        SMART_FILTERS -->|Headphones / Bluetooth| DOLBY_HP["Dolby Headphone Enhancement<br/>(Dialogue EQ + AutoGain + Multiband)"]
        SMART_FILTERS -->|Internal Speakers| DOLBY_SPK["Dolby Speaker Correction<br/>(Internal ASUS Speaker Tuning)"]
        
        PEACE_SINK -->|Auto-Route| ACTIVE_SINK
        DOLBY_HP -->|Auto-Route| ACTIVE_SINK
        DOLBY_SPK -->|Auto-Route| ACTIVE_SINK
        
        ACTIVE_SINK{"Active Hardware Sink<br/>(WirePlumber Dynamic Priority)"}
        ACTIVE_SINK -->|Priority 2500: Connected| BT_SINK["Bluetooth A2DP Sink<br/>(bluez_output.B0_38_E2_78_9B_FE.1)"]
        ACTIVE_SINK -->|Priority 2000: Default Fallback| ALSA_SINK["Internal Analog Stereo<br/>(alsa_output.pci-0000_00_1f.3.analog-stereo)"]
    end

    GHELPER_CLEAN -.->|Sole Unified Input (Games, Discord, OBS, Browser)| APPS
```

---

## 2. Hardware Inventory & ALSA Base Configuration

| Device Role | Hardware Device Identifier | Driver / Node | Key Physical Settings |
| :--- | :--- | :--- | :--- |
| **Internal Mic** | Realtek ALC256 Analog Stereo | `alsa_input.pci-0000_00_1f.3.analog-stereo` | Capture: `23 (0.00 dB)`<br/>Internal Mic Boost: `1 (+10.00 dB)` |
| **Internal Speakers** | Realtek ALC256 Analog Stereo | `alsa_output.pci-0000_00_1f.3.analog-stereo` | ASUS TUF Laptop Internal Speakers |
| **Wired Headset** | Realtek ALC256 3.5mm Combo Jack | `alsa_output.pci-0000_00_1f.3.analog-stereo` | Auto-switches via ALSA jack detection |
| **Bluetooth Audio** | Soundcore Q20i (`B0:38:E2:78:9B:FE`) | `bluez_output.B0_38_E2_78_9B_FE.1` | High-fidelity A2DP (`AAC` / `SBC-XQ`) |
| **HDMI / DP Audio** | NVIDIA GB207 Audio Controller | `alsa_output.pci-0000_01_00.1` | GeForce RTX 5050 Mobile HDMI/Type-C DP |

---

## 3. Core PipeWire Clock & Latency Policies

Configured in [`~/.config/pipewire/pipewire.conf.d/10-low-latency.conf`](file:///home/manisk/.config/pipewire/pipewire.conf.d/10-low-latency.conf) and [`10-denormals.conf`](file:///home/manisk/.config/pipewire/pipewire.conf.d/10-denormals.conf):

```spa-json
context.properties = {
    default.clock.rate          = 48000
    default.clock.allowed-rates = [ 48000 ]
    default.clock.quantum       = 512       # 10.67 ms cycle @ 48 kHz
    default.clock.min-quantum   = 64        # 1.33 ms minimum
    default.clock.max-quantum   = 2048      # 42.67 ms maximum under load
    cpu.zero.denormals          = true      # Prevents DSP floating-point stalls
}
```

* **Rationale**: Quantum 512 ensures absolute glitch-free Bluetooth streaming under heavy multicore compilation or GPU load while maintaining low competitive gaming input-to-ear latency (~10.7 ms).

---

## 4. WirePlumber 0.5 Routing Policies & Device Switching

### A. Strict Bluetooth A2DP Policy (RULE 10 Enforcement)
File: [`~/.config/wireplumber/wireplumber.conf.d/11-bluetooth-policy.conf`](file:///home/manisk/.config/wireplumber/wireplumber.conf.d/11-bluetooth-policy.conf)

```spa-json
wireplumber.settings = {
  bluetooth.autoswitch-to-headset-profile = false
}

monitor.bluez.properties = {
  bluez5.roles          = [ a2dp_sink a2dp_source ]
  bluez5.hfphsp-backend = "none"
  bluez5.enable-sbc-xq  = true
  bluez5.enable-msbc    = false
  bluez5.codecs         = [ aac sbc_xq sbc ]
}

monitor.bluez.rules = [
  {
    matches = [ { node.name = "~bluez_output.*" } ]
    actions = {
      update-props = {
        priority.session               = 2500
        session.suspend-timeout-seconds = 0
        node.latency                   = "1024/48000"
      }
    }
  }
]
```
* **Behavior**:
  * Bluetooth headphones stay strictly locked in high-fidelity A2DP playback mode.
  * Auto-switching to low-bandwidth Hands-Free Profile (HSP/HFP, mSBC, CVSD) is completely disabled.
  * Voice input is always supplied by the internal laptop microphone through `ghelper-audio`.

### B. ALSA Hardware Jack Policy
File: [`~/.config/wireplumber/wireplumber.conf.d/10-alsa-policy.conf`](file:///home/manisk/.config/wireplumber/wireplumber.conf.d/10-alsa-policy.conf)

```spa-json
monitor.alsa.rules = [
  {
    matches = [ { device.name = "~alsa_card.*" } ]
    actions = { update-props = { api.acp.auto-profile = true api.acp.auto-port = true } }
  },
  {
    matches = [ { node.name = "~alsa_output.*analog-stereo" } ]
    actions = {
      update-props = {
        priority.session               = 2000
        session.suspend-timeout-seconds = 0
        api.alsa.headroom              = 1024
      }
    }
  }
]
```

### C. Output Device Priority Hierarchy
When multiple playback devices are connected, WirePlumber resolves sinks by `priority.session`:
1. **Bluetooth Headphones (`bluez_output.*`)** — Priority `2500`: Wins immediately on connection.
2. **Wired Analog Stereo (`alsa_output.*`)** — Priority `2000`: Default fallback when Bluetooth disconnects.
3. **HDMI / DisplayPort** — Priority `1000`: Secondary auxiliary display routing.

---

## 5. Output Playback DSP Pipelines

### A. Competitive Gaming Low-Latency Pipeline
File: [`~/.config/pipewire/pipewire.conf.d/30-peace-gaming.conf`](file:///home/manisk/.config/pipewire/pipewire.conf.d/30-peace-gaming.conf)  
Script: [`~/.local/share/wireplumber/scripts/gaming-audio-route.lua`](file:///home/manisk/.local/share/wireplumber/scripts/gaming-audio-route.lua)

* **Virtual Sink**: `sink.peace_gaming` (`Audio/Sink`, description: "Gaming Audio")
* **DSP Processing**:
  * Left & Right RBJ Biquad Parametric Curve (Peace PUBG Target):
    * 64 Hz High-Pass (Q = 1.41)
    * 125 Hz Peaking (−3.0 dB, Q = 1.41)
    * 250 Hz Peaking (−2.0 dB, Q = 1.41)
    * 800 Hz Footstep Peaking (+3.0 dB, Q = 1.41)
    * 1500 Hz Pinpoint Peaking (+4.0 dB, Q = 1.41)
    * 3000 Hz Peaking (+4.0 dB, Q = 1.41)
    * 4000 Hz Gunshot Crack Peaking (+2.0 dB, Q = 1.41)
  * Native Linux LoudMax LADSPA Limiter/Maximizer (`ldmx_stereo`):
    * Threshold: −15.2 dB
    * Output: −2.3 dB
    * Inter-Sample Peaks: 0.0 (OFF)
* **Automatic Game Interception**:
  * `gaming-audio-route.lua` hooks into WirePlumber stream creation and automatically routes explicitly detected games (`cs2`, `THE FINALS`, `ARC Raiders`, `Hunt: Showdown`, `PUBG`, `Apex Legends`) into `sink.peace_gaming`.
  * Outputs automatically track the currently selected user destination sink in real time via `default.audio.sink` metadata (Soundcore Q20i Bluetooth A2DP, Boult BassBox, 3.5mm wired headphones, or ALC256 internal speakers).
  * Seamlessly hot-reloads on `Alt + Shift + O` (`toggle-audio-sink`) with zero game disconnects or buffer interruptions.


### B. Device-Agnostic Dolby Enhancement & ASUS DAX3 Speaker DSP

Files & Services:
* [`~/.config/pipewire/pipewire.conf.d/42-dolby-headphones.conf`](file:///home/manisk/.config/pipewire/pipewire.conf.d/42-dolby-headphones.conf) (Dolby Headphone Filter Chain)
* [`~/.config/systemd/user/asus-speaker-dsp.service`](file:///home/manisk/.config/systemd/user/asus-speaker-dsp.service) (ASUS DAX3 Speaker Filter-Chain Runner)
* [`~/.config/pipewire/asus-tuf-dax/`](file:///home/manisk/.config/pipewire/asus-tuf-dax/) (`active-runner.conf` symlink + per-profile directories; profile selection recorded in `~/.config/asus-speakers/state.conf`)
* [`~/.config/wireplumber/wireplumber.conf.d/40-dax-speaker-route.conf`](file:///home/manisk/.config/wireplumber/wireplumber.conf.d/40-dax-speaker-route.conf) (WirePlumber 0.5 module trigger)
* [`~/.local/share/wireplumber/scripts/dax-speaker-route.lua`](file:///home/manisk/.local/share/wireplumber/scripts/dax-speaker-route.lua) (Live dynamic hardware-route switcher)
* [`~/.local/bin/rofi-speaker-dsp`](file:///home/manisk/.local/bin/rofi-speaker-dsp) & [`~/.local/bin/asus-speaker-doctor`](file:///home/manisk/.local/bin/asus-speaker-doctor) (Interactive voicing switcher & diagnostics)

#### 1. Dolby Headphone Enhancement (`effect_input.Dolby_Headphones`)
Activated automatically whenever Bluetooth (e.g. Soundcore Q20i) or 3.5mm wired headphones are connected:
* **Stage 1: Dialogue Clarity**: LSP 16-band Parametric EQ (+2 dB peaking boost centered at 3000 Hz, Q = 1.0) for vocal intelligibility in movies, shows, and podcasts.
* **Stage 2: AutoGain Leveler**: LSP AutoGain Stereo (Target: −18.0 dBFS, max boost +6.0 dB, threshold −70 dBFS) for broadcast-level consistency across disparate YouTube and media loudness standards.
* **Stage 3: Headphone Dynamics**: LSP Multiband Stereo Compressor (controlled 2:1 compression, 5 ms attack, 100 ms release) preventing harsh dynamics while keeping audio full and open.
* **Stage 4: Studio Limiter**: LSP True-Peak Limiter Stereo (ceiling −0.1 dBFS, 1 ms lookahead, 5 ms release) preventing inter-sample clipping on digital outputs.

#### 2. Dolby Speaker DSP (`effect_input.Dolby_Speaker`)
Powered by `asus-speaker-dsp.service` running a dedicated, low-overhead filter-chain instance isolated on CPU affinity 0–11:
* **Hardware FIR Convolver**: Direct convolution using factory-extracted Windows DAX3 impulse responses (`Dolby_Speaker.irs`), correcting chassis resonance and frequency response nulls inherent to laptop bottom-firing speakers.
* **16-Band Parametric EQ**: Frequency-tailored per voicing (`custom`, `dynamic`, `balanced`, `music`, `tuned`, `tuned-old`, `experimental`; historical voicings archived in `archive/`).
* **Multiband Compression & Loudness Limiter**: Maximizes perceived loudness and clarity from laptop drivers without causing distortion or excursion rattle.
* **Voicing Management**: Live-swappable on the fly via `rofi-speaker-dsp` or `spk` without restarting system audio.
* **Main-Graph Client Scheduling (verified 2026-10-17)**: `asus-speaker-dsp.service` runs `pipewire -c active-runner.conf`, which connects to the default server as a client and exports `effect_input/output.Dolby_Speaker` into the primary graph (confirmed via `pw-top` + client-PID match). The chain is therefore scheduled by the main server clock: 48 kHz, quantum 512. No separate clock tuning in `runner.conf` is required or effective.

#### 3. Strict Mutual Exclusion Routing (`dax-speaker-route.lua`)
WirePlumber dynamically monitors physical ALSA jack routes and Bluetooth states:
* **Headphones / Bluetooth Active**:
  * `Dolby_Headphones` `filter.smart.disabled = false` (Active target set to current sink).
  * `Dolby_Speaker` `filter.smart.disabled = true` (Speaker FIR completely bypassed).
* **Internal Laptop Speakers Active**:
  * `Dolby_Speaker` `filter.smart.disabled = false` (Targeted directly to `alsa_output.pci-0000_00_1f.3.analog-stereo`).
  * `Dolby_Headphones` `filter.smart.disabled = true` (Headphone processing bypassed).
* **Competitive Gaming Exemption & Dynamic Tracking**:
  * When any competitive game (`cs2`, `THE FINALS`, `Apex Legends`, `PUBG`, `ARC Raiders`) launches, `gaming-audio-route.lua` routes it directly to `sink.peace_gaming`, entirely bypassing both Dolby filters for absolute zero-latency, unaltered binaural positioning.
  * In turn, `playback.peace_gaming` routes directly to the physical hardware sink selected via `Alt + Shift + O` (`default.audio.sink` metadata), re-linking live and seamlessly when switching across Soundcore, Boult BassBox, or internal speakers.


---

## 6. Krisp-Grade Microphone Stack (`40-mic.conf`)

Configured in [`~/.config/pipewire/pipewire.conf.d/40-mic.conf`](file:///home/manisk/.config/pipewire/pipewire.conf.d/40-mic.conf):

### A. Processing Stages & Verified Parameters

```text
[Hardware Microphone] (alsa_input.pci-0000_00_1f.3.analog-stereo)
        │
        ▼
Stage 1: 80 Hz Rumble Cut Highpass Filter (bq_highpass, Q = 0.707)
        │  • Eliminates mechanical desk vibration and laptop chassis fan rumble.
        ▼
Stage 2: DPDFNet Neural Noise Suppressor (libdpdfnet_ladspa.so, Attenuation Limit = 45 dB)
        │  • Upstream Ceva DeepFilterNet lineage model running via in-process ONNX.
        │  • 45 dB soft attenuation floor prevents digital-zero gating and consonant dropouts.
        ▼
Stage 3: Latency Alignment Delay Node (builtin delay, latency = 0.08 s)
        │  • Accurately reports the model's 80 ms declared context window to PipeWire.
        ▼
Stage 4: In-Chain Voice FX Engine (Single Linear PipeWire Filter Chain):
        │  • RubberBand Mono (pitch/formant), SWH RingMod, SWH Decimator, LSP Flanger Mono,
        │    SWH Delayorama (Delay/Echo), Biquad HPF/LPF/Peak Filters.
        │  • Pure single linear pipeline: zero parallel branch divergence, zero unaligned latency warnings.
        │  • Fully dry/bypassed on Natural Clean (Dry/Wet = 0.0, pitch = 0.0, delay = 0.0, flanger bypass);
        │    instantaneously engages on Creative Presets.
        ▼
Stage 5: Broadcast Parametric EQ Cascade (RBJ Biquads):
        │  • 80 Hz Low Shelf    : -2.0 dB (Q = 0.707)  — Sub-rumble control
        │  • 400 Hz Peaking     : -1.5 dB (Q = 1.0)    — ALC256 capsule boxiness cut
        │  • 3500 Hz Peaking    : +1.5 dB (Q = 0.8)    — Vocal clarity & intelligibility
        │  • 6k, 9k, 12k Highs  :  0.0 dB              — 100% neutral top end (zero hiss)
        │  • Automatically flattened to 0.0 dB when Creative Presets are active to preserve FX voicing.
        ▼
Stage 6: Studio Anti-Shout Compressor (LSP LADSPA compressor_mono):
        │  • Attack: 5.0 ms  |  Hold: 120.0 ms  |  Release: 500.0 ms  |  Ratio: 2.0:1  |  Knee: 3.0 dB
        │  • Clean Quiet Voice Boost (+4 dB Default on Natural Clean):
        │      Threshold dynamically drops to -18 dBFS (0.126 G) with +7.0 dB makeup gain (2.239 G)
        │      Lifts distant (~1 ft) or soft speech into audible broadcast range.
        │  • Dynamic FX Isolation: Makeup gain locked to 0.0 dB (1.0 G) on Creative Presets to eliminate noise floor rise.
        │  • Anti-Shout Protection: 5 ms attack + 120 ms hold + 500 ms release prevents shout distortion and pumping.
        ▼
Stage 7: Studio Lookahead Peak Limiter (LSP LADSPA limiter_mono):
        │  • Threshold: -2.0 dBFS (0.794 G)  |  Lookahead: 1.5 ms  |  Attack: 2.0 ms  |  Release: 30.0 ms
        │  • Reduced lookahead buffer from 5.0 ms to 1.5 ms saves 3.5 ms delay with unchanged -2.0 dBFS ceiling guard.
        │  • Sample-peak mode (0x oversampling to preserve lowest latency / CPU overhead).
        │  • Creative Model Voice Boost: +2.0 dB output gain (1.2589 G) on creative presets for punch & presence.
        │  • -2.0 dBFS sample-peak ceiling provides practical headroom guard against digital clipping.
        ▼
[Virtual Source: ghelper-audio] (media.class = Audio/Source, priority.session = 3000)
```

### B. Why 45 dB Attenuation Won Over 100 dB
In the engine code (`hushmic-denoiser/src/denoiser.rs`), `Attenuation Limit (dB)` blends the latency-aligned input back in:
* **100 dB (Hard Gate)**: Causes 35.0% exact digital silence in pauses and cuts word onset energy to only 14.3% (chopping word attacks).
* **28 dB (Under-suppressed)**: Allows laptop fan hum and room noise to leak through behind speech.
* **45 dB (Optimal Soft Floor)**: Wipes out mechanical typing and fan hum completely while preserving natural word beginnings (120.1% onset energy) and fading tails.

### C. Live Measured Performance (ITU P.835)
* **DNSMOS Speech Quality (SIG)**: `3.39`
* **DNSMOS Background Rejection (BAK)**: `4.12` *(Krisp-grade rejection)*
* **DNSMOS Overall Score (OVRL)**: `3.12`
* **Peak Output**: `-4.9 dBFS` *(0 clipping samples)*
* **Speech RMS**: `-31.3 dBFS`

---

## 7. Unified Voice FX Engine & Instant Hot Reload (MicStudio)

Formerly, creative effects ran in a secondary filter chain (`41-mic-fx.conf`). In competitive games like Counter-Strike 2, The Finals, and Apex Legends, audio streams lock to their initial capture node upon launch and do not follow OS default source changes. To solve this, all Voice FX stages have been **fully unified into `40-mic.conf`** directly feeding `ghelper-audio`.

1. **Architecture & Zero-Dropout Parameter Hot Reload**:
   * All voice morphing (RubberBand, RingMod, Decimator, Flanger, Delayorama, and Biquad FX filters) runs in-line inside `capture.ghelper-audio`.
   * When switching presets in MicStudio or via CLI (`mic voice "<Preset>"`), PipeWire parameters are updated atomically in sub-milliseconds without stream restarts, buffer drops, or device re-selection.
2. **Single Pure Linear DSP Architecture**:
   * All processing occurs in a unified sequential pipeline with zero branch divergence, ensuring 100% phase alignment and zero unaligned latency warnings across all 27 presets.
   * On Natural Clean, RubberBand is placed in pure dry passthrough mode (`pitch = 0.0, wet/dry = 1.0 (dry)`), SWH Delayorama is locked to `0.0`, and Flanger/RingMod/Decimator are bypassed.
3. **Sidetone Feedback Protection & Device Support**:
   * Sidetone monitoring (`v` key in MicStudio TUI or `mic hear on` CLI) routes the unified capture node to the default playback device (Bluetooth headsets/speakers, 3.5mm wired headphones).
   * Built-in laptop chassis speakers (`analog-output-speaker`) are suppressed to protect the hardware and user against high-frequency acoustic feedback loops, while 3.5mm wired headphones (`analog-output-headphones`) and Bluetooth endpoints (`bluez_output.*`) are fully supported.
4. **27 Production Presets**:
   * *Natural Clean, Deep Voice, Radio Announcer, Higher Voice, Gruff Growl, Chipmunk, Darth Vader, Megatron, Giant, Goblin, Child, Robot, Cylon, Daft Punk, Kraftwerk, Dalek, Walkie Talkie, Old Telephone, Megaphone, Cave, Stadium Echo, Sci-Fi Alien, Ghost, Demon, Cyber Chopper, Underwater, Lo-Fi Static.*
5. **Preset Level & Gain Architecture**:
   * **Isolated Quiet Voice Boost (+4 dB)**: Pre-FX compressor threshold lowering and +7.0 dB makeup gain is strictly isolated to **Natural Clean**, lifting soft conversational speech into nominal broadcast range.
   * **Creative Preset Isolation**: Creative presets inherit **0.0 dB** compressor makeup gain to prevent noise floor amplification, with a clean **+2.0 dB** boost applied post-effect at the limiter output stage (`limiter:Output gain = 1.2589 G`).
   * **Zero Repeating Voice / Echo Elimination**: SWH Delayorama `Dry/wet mix` is hard-coded to `0.0` on all 25 non-echo presets. Only dedicated delay presets (*Cave*, *Stadium Echo*) activate the delay tap matrix.
6. **Runtime Preset Hot Reloading**:
   * **TUI Hotkey**: Press **`F5`** or **`Ctrl+R`** in the MicStudio TUI to reload `~/.config/micstudio/presets.toml` from disk into memory without restarting PipeWire or MicStudio.
   * **CLI Command**: Run `mic preset reload` or `micstudio preset reload`.

---

## 8. On-Demand WebRTC Acoustic Echo Cancellation (AEC)

For scenarios where internal laptop speakers are used during voice calls, native WebRTC AEC is supported without permanent background overhead:

* **Engine**: Native PipeWire module [`libpipewire-module-echo-cancel`](file:///usr/lib/pipewire-0.3/libpipewire-module-echo-cancel.so) via [`libspa-aec-webrtc.so`](file:///usr/lib/spa-0.2/aec/libspa-aec-webrtc.so).
* **Added Latency**: 10.0 ms (WebRTC algorithmic framing).
* **CPU Usage**: ~1.4% of a single CPU core.
* **On-Demand Load Command**:
  ```bash
  pw-cli load-module libpipewire-module-echo-cancel '{
    library.name = "aec/libspa-aec-webrtc"
    monitor.mode = true
    capture.props = { target.object = "alsa_input.pci-0000_00_1f.3.analog-stereo" }
    source.props  = { node.name = "ghelper-audio-aec" media.class = "Audio/Source" }
  }'
  ```
* **Unload / Destroy Command**:
  ```bash
  pw-cli destroy <module-id>
  ```
  *(Leaves zero DSP or latency overhead during gaming or headphone listening).*

---

## 9. Operational Verification Runbook

### Fast Status Inspection
```bash
# Check all active audio sinks, sources, filters, and streams
wpctl status

# Trace active PipeWire links
pw-link -l

# View live DSP parameters on the clean microphone capture node
pw-cli e $(pw-cli list-objects Node | grep -B1 'capture.ghelper-audio"' | head -n1 | awk '{print $2}' | tr -d ',') Props

# Check real-time PipeWire cycle latency and CPU consumption
pw-top
```

### Gaming & Voice Changer Configuration ("Set-and-Forget" Single Device)
* **Competitive Games (Counter-Strike 2, The Finals, Apex Legends, PUBG, Overwatch)**:
  * In the game's Audio Settings, set **Audio Input Device / Microphone** to **`MicStudio Unified (ghelper-audio)`** (or Default).
  * **Instant Voice Hot-Reload**: The entire DSP effect chain runs directly on `ghelper-audio`. You **never need to switch audio devices or restart the game**.
  * While playing, select any preset in MicStudio (`micstudio`) or via CLI/keybinding (e.g., `mic voice "Deep Voice"`). The transformed voice plays through the game immediately with sub-millisecond atomic property updates and zero buffer drops.
  * Return to pristine studio speech anytime with `mic clean`.

### Discord Configuration
* Under **User Settings → Voice & Video**:
  * **Input Device**: Set to `MicStudio Unified (ghelper-audio)` (or Default).
  * **Noise Suppression**: Set to **"None" / Disabled**.  
    *(DPDFNet in `40-mic.conf` already provides 45 dB Krisp-grade suppression; stacking Discord's internal suppressor causes double-denoising, dulling consonants and wasting CPU).*
  * **Echo Cancellation**: Disable if using headphones.

---

## 10. Complete Software Dependencies & Package Matrix

Every package, shared library, and neural model utilized across the audio subsystem:

| Package / Component | Exact Installed Version | Architecture / Type | Primary Purpose & Role in Subsystem |
| :--- | :--- | :--- | :--- |
| **`pipewire`** | `1:1.6.9-1` | Native Arch/CachyOS | Core multimedia graph server, SPA module host, real-time scheduling. |
| **`pipewire-audio`** | `1:1.6.9-1` | Native Arch/CachyOS | Audio subsystem support, filter-chain module, delay & convolver nodes. |
| **`pipewire-pulse`** | `1:1.6.9-1` | Native Arch/CachyOS | PulseAudio protocol server replacement (`pactl` compatibility layer). |
| **`pipewire-alsa`** | `1:1.6.9-1` | Native Arch/CachyOS | ALSA plugin redirecting legacy ALSA applications directly into PipeWire. |
| **`wireplumber`** | `0.5.18-1.1` | Native Arch/CachyOS | Modular session manager running Lua policy hooks & route monitors. |
| **`alsa-lib` & `alsa-utils`** | `1.2.16.1-1.1` / `1.2.16-1.1` | Native Arch/CachyOS | ALSA kernel userspace interface, mixer tools (`amixer`, `alsamixer`). |
| **`bluez` & `bluez-utils`** | `5.87-2.1` | Native Arch/CachyOS | Linux Bluetooth protocol stack daemon (`bluetoothd`) and CLI (`bluetoothctl`). |
| **`bluetui`** | `0.8.1-2.1` | Native Rust CLI / AUR | Interactive TUI for Bluetooth device scanning, pairing, and connection. |
| **`hushmic-bin`** | `0.10.3-1` | Pre-built binary package | Supplies `/usr/lib/ladspa/libdpdfnet_ladspa.so`, `/usr/lib/hushmic/libonnxruntime.so.1.27.0`, and DPDFNet ONNX models (`dpdfnet2_48khz_hr.onnx`, `dpdfnet8_48khz_hr.onnx`). *(App/GUI disabled; purely used as shared LADSPA plugin)*. |
| **`lsp-plugins-ladspa`** | `1.2.35-1.1` | Native Arch/CachyOS | Linux Studio Plugins LADSPA bundle: Vocal Compressor Mono, True-Peak Limiter Mono. |
| **`lsp-plugins-lv2`** | `1.2.35-1.1` | Native Arch/CachyOS | Linux Studio Plugins LV2 bundle: Parametric EQ 16-band, AutoGain Stereo, Multiband Dynamics. |
| **`la_LoudMax64.so`** | `LoudMax v1.44` | LADSPA Shared Library | Thomas Mundt's lookahead brickwall peak limiter/maximizer for gaming footstep curve (`~/.ladspa/`, `/usr/lib/ladspa/`). |
| **`swh-plugins`** | `0.4.17-7.1` | Native Arch/CachyOS | Steve Harris LADSPA plugins: Ringmod (`ringmod_1188.so`), Decimator (`decimator_1202.so`), Delayorama (`delayorama_1402.so`), Vocoder (`vocoder_1337.so`). |
| **`rubberband-ladspa`** | `4.0.0-2.1` | Native Arch/CachyOS | Breakfast Quay high-quality formant/pitch shifting LADSPA plugin for voice FX. |
| **`deepfilternet-ladspa`** | `0.5.6-1.1` | Native Arch/CachyOS | DeepFilterNet 3 neural noise suppressor fallback plugin. |
| **`rnnoise`** | `1:0.2-1.1` | Native Arch/CachyOS | Recurrent neural network noise reduction library (`librnnoise_ladspa.so`). |
| **`calf`** | `0.90.9-2.1` | Native Arch/CachyOS | Calf Studio Gear plugins (Filter, spatial effects). |
| **`webrtc-audio-processing-1`** | `1.3-5.1` | Native Arch/CachyOS | WebRTC acoustic echo cancellation library used in on-demand AEC module. |
| **`pavucontrol`** | `1:6.2-1.1` | Native Arch/CachyOS | GTK GUI volume mixer and per-application stream route manager. |
| **`upower`** | `1.91.5-1.1` | Native Arch/CachyOS | D-Bus system power service querying Bluetooth headphone battery levels. |
| **`rofi`** | `2.0.0-1.1` | Native Arch/CachyOS | Dynamic menu launcher powering `rofi-speaker-dsp`. |
| **`kitty`** | `0.49.2-1.1` | Native Arch/CachyOS | GPU-accelerated terminal running `bluetui` and `micstudio` TUI sessions. |

---

## 11. Bluetooth Management Suite, TUI & Auto-Routing Policies

### A. Dedicated Bluetooth TUI (`bluetui`)
Rather than relying on heavy GNOME or KDE Bluetooth daemons, the system uses **`bluetui`**:
* **Invocation:** Launched via kitty with class `bluetui`:
  ```bash
  kitty --class bluetui -e bluetui
  ```
* **Hotkey:** `$mod + Alt + 2` (`Super + Alt + 2`)
* **Capabilities:**
  * Real-time device scanning with RSSI signal indicators.
  * Instant one-key pairing, trusting, connecting, and disconnecting.
  * Device property inspection (battery percentage, MAC address, supported UUIDs).
  * Consumes 0.0% CPU and zero RAM when closed.

### B. Bluetooth Automation Scripts & Daemons
* **`bt-auto-trust` (`~/.local/bin/bt-auto-trust`)**:
  * Event-driven Python D-Bus hook that monitors BlueZ `org.bluez.Device1` interfaces.
  * Automatically sets `Trusted = True` on all paired audio peripherals so they never hang on connection authorization prompts.
  * Instantly sets the newly connected Bluetooth device as the default audio sink.
* **`bt-battery-notify` (`~/.local/bin/bt-battery-notify`)**:
  * Dual-layer battery query tool: checks UPower `/org/freedesktop/UPower/devices/headset_*` first, falling back to `bluetoothctl info` battery percentages.
  * Dispatches desktop notifications via Mako with zero dropped devices.
* **`toggle-headset-mic` (`~/.local/bin/toggle-headset-mic`)**:
  * Hotkey: `$mod + Ctrl + M` (`Super + Ctrl + M`)
  * Dynamically toggles BlueZ card profile between:
    * **Hi-Fi Stereo Mode (AAC 48 kHz A2DP)**: Default playback mode, default recording locked to laptop array.
    * **Headset Mic Mode (mSBC Wideband Speech)**: Low-bitrate hands-free duplex mode when headset mic testing is required.
* **`toggle-audio-sink` (`~/.local/bin/toggle-audio-sink`)**:
  * Hotkey: `Alt + Shift + O` (`Mod1 + Shift + O`)
  * Sequentially cycles across connected audio endpoints:
    1. Laptop Speakers (ALC256 + Dolby DAX3 DSP)
    2. Wired Headphones (ALC256 3.5mm jack — verified with hardware jack detection)
    3. Bluetooth Devices (Soundcore Q20i)
    4. USB DAC / External HDMI
* **`bt-profile` (`~/.local/bin/bt-profile`)**:
  * One-shot script to inspect or switch active PulseAudio card profiles.

---

## 12. Interactive Control Tools & Diagnostic Utilities

| Utility | Location | Key Commands & Syntax | Description |
| :--- | :--- | :--- | :--- |
| **`micstudio`** | `~/.local/bin/micstudio` | `micstudio`<br/>`micstudio voice "<name>"`<br/>`micstudio gain <dB>`<br/>`micstudio noise <dB>` | Native compiled Rust Ratatui TUI & CLI (`~/micstudio`). Controls 27 presets across 5 categories (DPDFNet attenuation 0–48 dB), 7 live audio controls, interactive DSP stage pipeline graph, parameter breakdown with units, peak & clip indicator, per-preset factory reset (`r`) & all-preset baseline reset (`R`), live write (`w`), hot-reload (`F5`/`Ctrl+R`), and real-time audio spectrograph (dual fullscreen `m`/`M`/`s`, embedded `g`/`G`, sidetone `v`). |
| **`mic`** | `~/.local/bin/mic` | `mic clean`<br/>`mic fx`<br/>`mic voice "Darth Vader"`<br/>`mic status`<br/>`mic doctor` | High-level CLI wrapper for `micstudio`. Zero background daemons. |
| **`spk`** | `~/.local/bin/spk` | `spk apply dynamic`<br/>`spk apply music`<br/>`spk apply custom`<br/>`spk status` | ASUS TUF DAX3 Dolby Speaker DSP profile switcher and state manager. |
| **`rofi-speaker-dsp`** | `~/.local/bin/rofi-speaker-dsp` | Executed via hotkey | Interactive Rofi menu for live DAX3 speaker DSP voicing switching. |
| **`asus-speaker-doctor`** | `~/.local/bin/asus-speaker-doctor` | `asus-speaker-doctor` | Deep diagnostics for ALC256 DMI hardware detection, convolver nodes, and WirePlumber bindings. |
| **`audio`** | `~/.local/bin/audio` | `audio status`<br/>`audio doctor`<br/>`audio rollback` | Unified audio system status, 11-point health check, and backup snapshot rollback. |
| **`volume-notify`** | `~/.local/bin/volume-notify` | `volume-notify up`<br/>`volume-notify down`<br/>`volume-notify mute` | On-screen display (OSD) feedback for volume and mute events with visual progress bar. |

---

## 13. System Keybindings & Hotkeys Matrix (Sway / i3wm)

Configured in [`~/.config/sway/config.d/40-keybindings.conf`](file:///home/manisk/.config/sway/config.d/40-keybindings.conf):

| Shortcut | Bound Command | Functional Action |
| :--- | :--- | :--- |
| **`$mod + Alt + 2`** | `kitty --class bluetui -e bluetui` | Launch Bluetooth TUI in terminal window |
| **`$mod + Alt + 3`** | `pavucontrol` | Launch GTK audio mixer GUI |
| **`$mod + Alt + 4`** | `~/.local/bin/rofi-speaker-dsp` | Open ASUS DAX3 Dolby Speaker Voicing Menu |
| **`$mod + Alt + O`** | `~/.local/bin/rofi-speaker-dsp` | Open ASUS DAX3 Dolby Speaker Voicing Menu (mnemonic) |
| **`Alt + Shift + O`** | `~/.local/bin/toggle-audio-sink` | Seamlessly cycle active audio sink (Speakers / 3.5mm / BT) |
| **`$mod + Ctrl + M`** | `~/.local/bin/toggle-headset-mic` | Toggle Bluetooth Mode (Hi-Fi AAC Stereo ↔ Headset mSBC Mic) |
| **`XF86AudioRaiseVolume`** | `~/.local/bin/volume-notify up` | Volume Up (+5%) with Mako OSD |
| **`XF86AudioLowerVolume`** | `~/.local/bin/volume-notify down` | Volume Down (-5%) with Mako OSD |
| **`XF86AudioMute`** | `~/.local/bin/volume-notify mute` | Toggle Audio Output Mute with Mako OSD |
| **`XF86AudioMicMute`** | `pactl set-source-mute @DEFAULT_SOURCE@ toggle` | Toggle Hardware Microphone Mute |

---

## 14. Automated Health Audits (`audio doctor` 11-Point Suite)

The `audio doctor` command performs 11 automatic audits on every run to ensure system invariants remain 100% intact:

1. **Systemd Audio Services:** Verifies `pipewire.service`, `wireplumber.service`, `pipewire-pulse.service`, and `asus-speaker-dsp.service` are active.
2. **Clock Rate & Quantum:** Confirms synchronization at 48000 Hz and quantum within configured boundaries (64–2048).
3. **Process Collision:** Ensures zero rogue, orphaned, or duplicated audio processes.
4. **Node Duplication:** Checks for duplicate smart filter nodes.
5. **Double Processing:** Verifies that streams do not route through both Peace Gaming EQ and Dolby chains concurrently.
6. **Gaming Audio Route:** Verifies `playback.peace_gaming` links to the valid physical hardware sink.
7. **Bluetooth Policy:** Verifies no `bluez_input` nodes exist and BlueZ is locked strictly to A2DP playback.
8. **Speaker FIR Isolation:** Proves `effect_input.Dolby_Speaker` cannot be linked while on headphones or Bluetooth.
9. **Microphone Invariant:** Validates `ghelper-audio` is locked as the system default source (Priority: 3000).
10. **Virtual Sink Policy:** Ensures `sink.peace_gaming` has `priority.session = -1` and never captures default desktop audio.
11. **Baseline Snapshot:** Confirms backup integrity in `~/.config/pipewire/backup/20261010_unified_audit`.

---

## 15. Production Guard Rails: Anti-Shout Protection & Honest Hardware ADC Detection

### A. The Challenge & Physical Acoustics
With **Quiet Voice Boost** active at `+4.0 dB` (threshold lowered to −18.0 dBFS, +7.0 dB makeup gain), soft conversational speech (~1 foot away from the laptop chassis) is cleanly lifted into the nominal conversational zone (−18 to −14 dBFS). However, during intense gaming moments (clutches in CS2, shoutouts in The Finals), users may suddenly shout or laugh near the microphone.

Without proper guard rails, aggressive speech spikes can either cause heavy compressor pumping (breathing artifacts) or drive the hardware analog pre-amplifier into clipping.

### B. Implemented Production Guard Rails

1. **Anti-Shout Compressor Envelope (Hold Window & Fast Attack)**:
   * **5.0 ms Fast Attack**: Catches sudden shouting, screams, and sharp consonant bursts before they blast through Discord or game voice chat.
   * **120.0 ms Hold Window (`hold_samples = 5760` at 48kHz)**: Prevents the compressor from releasing between vocal pulses. Shouts are smoothly held in attenuation rather than "pumping" or "flapping" during vocal pauses.
   * **500.0 ms Logarithmic Release**: Smoothly returns to nominal gain without jarring volume jumps.
   * **Soft Knee (3.0 dB)**: Transitions smoothly into gain reduction, avoiding audible compression onset artifacts.

2. **Input Clipping Detection vs Digital Limiting**:
   * **Physical Context**: High acoustic SPL or excessive analog capture gain can push incoming samples to digital full-scale rails ($\pm 1.0$). While flat-topped samples indicate probable preamplifier saturation or digital full-scale clipping, software analysis cannot definitively isolate analog ADC saturation from upstream digital boundary limits.
   * **Input Flat-Top Detector**: MicStudio's native DSP telemetry inspects raw incoming audio blocks. If **$\ge 3$ consecutive flat-topped samples** hit digital full-scale ($\pm 1.0$), it triggers:
     * Displayed in TUI Top-Bar as: `[Input clipping suspected — check microphone gain]` in bright Red/Yellow with a 1.5s visual hold.
     * Informs the user to inspect physical input levels (`amixer -c 0 sset Capture 23`) before altering digital DSP parameters.
   * **Digital Limiting Telemetry**: In contrast, when legitimate vocal peaks exceed −2.0 dBFS, the LSP limiter sample-peak mode clamps them. MicStudio displays `[DIGITAL LIMITING]` in Yellow (0.8s hold), confirming digital headroom protection is active.

3. **Dynamic Clean vs FX Leveling Isolation**:
   * **Natural Clean**: Inherits the Quiet Voice Boost (+4 dB leveling, −18 dBFS threshold, +7.0 dB makeup gain). Soft speech is amplified while normal speech stays balanced.
   * **Creative Presets**: Compressor makeup gain is locked to **0.0 dB** (1.0 G) and threshold to −12.0 dBFS. This prevents creative voice models from lifting background room noise or double-amplifying already modulated signals.
   * **Model Volume Boost**: Each creative preset receives a dedicated **+2.0 dB** boost via the stage 7 limiter output gain (`limiter:Output gain = 1.2589 G`), ensuring clear presence against game sound effects without clipping.

4. **Runtime Preset Hot Reloading**:
   * Users can tweak `~/.config/micstudio/presets.toml` (changing pitch semitones, EQ bands, resonance, delay times, etc.) at any time.
   * Pressing **`F5`** or **`Ctrl+R`** in the TUI or running **`mic preset reload`** re-reads the configuration file from disk into memory and applies the updated parameters live without restarting PipeWire, closing MicStudio, or disconnecting games.

---

## 16. Gaming Audio Zero-Tear Invariant & ALC256 Output Routing

### A. The Core Invariant: Zero Stream Interruption on Output Toggle
On ASUS TUF Gaming laptops (Realtek ALC256 codec), internal laptop speakers and wired 3.5mm headphones are exposed as two distinct routes/ports (`analog-output-speaker` and `analog-output-headphones`) on the exact same underlying hardware audio sink:
`alsa_output.pci-0000_00_1f.3.analog-stereo`

When cycling audio targets via `Alt + Shift + O` (`toggle-audio-sink`), the following invariants are strictly preserved:

1. **Same-Sink Link Preservation**:
   - Switching between `alsa:speaker` and `alsa:headphones` does **not** alter the destination hardware sink.
   - The competitive gaming stream (`playback.peace_gaming`) **must never be unlinked or re-linked** during this transition.
   - Brute-force `pw-link -d` operations are strictly forbidden when `NEXT_SINK == CURRENT_SINK`. This prevents broken pipe / socket teardowns in SDL3/CS2 and eliminates the need to "hard reload" games during output switching.

2. **Make-Before-Break External Sink Migration**:
   - When transitioning between the internal ALSA sink and an external sink (e.g. Bluetooth A2DP `bluez_output...`):
     - New links (`playback.peace_gaming:output_FL/FR -> target:playback_FL/FR`) are created **first**.
     - Old links are pruned only after the new target connection is established.
     - Games stream continuously across audio handoffs without audio thread stalls or xruns.

3. **Gaming Sink Volume Lock (100% / 1.0 Gain Ceiling)**:
   - `sink.peace_gaming` volume is pinned to `1.0` (0 dB) upon every sink toggle.
   - Ensures tactical game equalization (Peace PUBG EQ + LoudMax LADSPA limiter) operates with nominal digital headroom and is never inadvertently attenuated by system volume keys.

4. **Strict 100% Volume Ceiling for OSD (`volume-notify`)**:
   - Keybindings for `XF86AudioRaiseVolume` invoke `wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+`.
   - The `-l 1.0` flag guarantees audio volume strictly clamps at 100% (0 dBFS), preventing software over-amplification, digital clipping, and hearing strain.

5. **ASUS DAX3 Dolby Speaker Filter Chain Dynamic Re-attachment**:
   - Speaker DSP filter runner configurations (`custom`, `dynamic`, `balanced`, `music`) declare `target.object = "alsa_output.pci-0000_00_1f.3.analog-stereo"` in `playback.props`.
   - WirePlumber's `dax-speaker-route.lua` registers dynamic `object-added` and `object-removed` listeners on all filter nodes (`speaker_node_om`, `spk_playback_om`, `hp_node_om`, `hp_playback_om`).
   - Profile switches via `spk <profile>` or `rofi-speaker-dsp` re-attach instantly with zero silence or need to cycle devices.


