# Dusky Audio Studio & Native Stack Import Audit

**Date:** 2026-10-09  
**Platform:** ASUS TUF Gaming F16 (FX608JH_FX608JH)  
**Audio Hardware:** Realtek ALC256 (PCI Subsystem 1043:1084)  
**Core Stack:** PipeWire 1.6.9 + WirePlumber 0.5.18  

---

## 1. Upstream Dusky DSP Pipeline (Order & Real Code Parameters)

Analysis of `dusky_audio_studio/audio-helper/main.c` (3,582 lines) and `protocol.h`:

The capture callback `cb_in_process()` executes the following DSP stages strictly in sequence:

| Step | Stage | Real Implementation in Code | Real Defaults & Parameters |
| :--- | :--- | :--- | :--- |
| **1** | **Pre-RNNoise High-Pass Filter** | Single 2nd-order Biquad Highpass (`g_rt.rnn_hpf`, `main.c:1201`) | $f_0 = 70\text{ Hz}$, $Q = 0.707$, Sample Rate $48{,}000\text{ Hz}$. Cuts sub-rumble/fan hum before the neural net. Only active when RNNoise is ON. |
| **2** | **RNNoise Neural Network Core** | Fixed-frame recurrent neural network (`rnnoise_process_frame`) | Frame size = 480 samples ($10\text{ ms}$ @ $48\text{ kHz}$). Runs on float audio scaled to $[-32768, 32768]$. Emits raw denoised audio and VAD (0.0 to 1.0). Unconditionally computes VAD. |
| **3** | **VAD Asymmetric EMA** | Exponential Moving Average on VAD probability (`main.c:1624`) | $\alpha_{\text{up}} = 0.6$ (instant rise on speech onset), $\alpha_{\text{down}} = 0.05$ ($\sim 200\text{ ms}$ slow decay across syllables). |
| **4** | **Post-RNNoise Soft Gate & Hangover** | Hysteresis state machine + 1-pole gain smoothing (`main.c:1639`) | $\text{open\_th} = 0.50$ (50%), $\text{close\_th} = 0.15$ (15%). Hangover = 12,000 samples ($250\text{ ms}$). Smoothing time constant $\tau = 5\text{ ms}$. Attenuation target: $1.0 - 0.98 \times \text{aggro}$ (at default aggro $960$, close gain $= 0.0592 \approx -24.5\text{ dB}$). Dry/wet blend: $s = (1 - \text{aggro}) \times \text{dry} + \text{aggro} \times \text{processed}$. |
| **5** | **Pitch Tracker** | Autocorrelation / AMDF pitch estimator (`pitch_tracker_push`) | Reads post-denoised signal. Outputs fundamental pitch $F_0$ (`tracked_hz`). Valid range $50\text{ Hz} - 880\text{ Hz}$. |
| **6** | **Granular Pitch Shifter / Autotune** | Time-domain granular overlap-add (`psh_tick`, `main.c:1728`) | Centi-semitones ($-2400$ to $+2400$). Ratio smoothing: $\tau = 20\text{ ms}$ (manual shift), $\tau = 3\text{ ms}$ (autotune quantize snap). Autotune chromatic or monotone snap target (`voice_autotune_target_hz`). |
| **7** | **Vocoder & Matrix Ring-Mod** | 16-band filterbank carrier synthesizer (`vocoder_tick`, `main.c:1740`) | Dual detuned saw waves ($50 - 880\text{ Hz}$, detune $0 - 200$‰). Attack $1 - 200\text{ ms}$, release $5 - 500\text{ ms}$. Optional pitch-follow mode with transpose ($-24$ to $+24$ st). Matrix ring-mod: $35\text{ Hz}$ carrier + tanh non-linear saturation. |
| **8** | **9-Band Parametric Equalizer** | Cascade of 9 Robert Bristow-Johnson Biquads (`main.c:1748`) | Fixed frequencies: $80, 120, 250, 400, 1500, 3500, 6000, 9000, 12000\text{ Hz}$. Types: Highpass/Shelf, Peaking, Highshelf. Post-EQ uniform makeup gain ($-36\text{ dB}$ to $+36\text{ dB}$). |
| **9** | **Feedback Delay** | Circular buffer with fractional delay (`delay_tick`, `main.c:1759`) | Delay time $0 - 1000\text{ ms}$, feedback $0 - 950$‰, mix $0 - 1000$‰. |
| **10** | **Schroeder Reverb** | 4 parallel comb filters + 2 series allpass filters (`reverb_tick`, `main.c:1761`) | Room size $0 - 1000$‰, damp $0 - 1000$‰, width $0 - 1000$‰, wet mix $0 - 1000$‰. |
| **11** | **Master Volume Gain** | Linear scalar multiplier (`main.c:1769`) | $0 - 2000$‰ ($0 = \text{mute}, 1000 = 0\text{ dB unity}, 2000 = +6\text{ dB}$). Applied before ring buffers. |
| **12** | **Voice Bandpass Filter** | Series 2nd-order Biquad HPF + Biquad LPF (`main.c:1776`) | Resonant telephone/helmet band. HPF cutoff $0 - 2000\text{ Hz}$, LPF cutoff $0 - 20000\text{ Hz}$. ($0 = \text{bypass}$). |
| **13** | **Stutter Gate** | Rhythmic square-wave amplitude modulation (`main.c:1786`) | Frequency $0 - 40\text{ Hz}$, duty cycle $50 - 950$‰ (default 500‰). 1-pole anti-click smoothing $\tau = 5\text{ ms}$. |
| **14** | **Bitcrusher** | Staircase quantization + sample-and-hold (`bitcrush_tick`, `main.c:1807`) | Bit depth $1 - 15$ bits ($0 = \text{bypass}$), downsampling factor $1 - 64\times$. |

---

## 2. Character Preset Parameter Map

Extracted from `dusky_audio_studio.py` (`PRESETS` dictionary, lines 616–839):

| Preset Name | Vocoder | Mix | Carrier Hz | Detune | Atk/Rel (ms) | Follow / Shift | Pitch Shift (st) | Autotune | HPF / LPF (Hz) | Stutter (Hz) | Matrix (%) | Bitcrush (bits/ds) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Natural Clean** | OFF | 0% | 110 | 0 | 5 / 30 | OFF / 0 | 0 | OFF | 0 / 0 | 0 | 0% | 0 / 1x |
| **Daft Punk** | ON | 90% | 110 | 50 | 2 / 12 | YES / 0 | 0 | OFF | 0 / 0 | 0 | 15% | 0 / 1x |
| **Darth Vader** | ON | 0% | 110 | 0 | 5 / 30 | OFF / 0 | -5 st | OFF | 80 / 2500 | 0 | 0% | 0 / 1x |
| **Chipmunk** | ON | 0% | 110 | 0 | 2 / 15 | OFF / 0 | +12 st | OFF | 150 / 0 | 0 | 0% | 0 / 1x |
| **Cylon Robot** | ON | 90% | 90 | 160 | 10 / 70 | OFF / 0 | 0 | OFF | 0 / 0 | 6 Hz | 45% | 0 / 1x |
| **Kraftwerk** | ON | 95% | 140 | 10 | 3 / 15 | OFF / 0 | 0 | OFF | 0 / 0 | 0 | 0% | 0 / 1x |
| **Matrix Agent**| ON | 90% | 70 | 90 | 10 / 55 | OFF / 0 | -2 st | OFF | 300 / 3400 | 0 | 100% | 0 / 1x |
| **Robot Phone** | ON | 0% | 110 | 0 | 5 / 25 | OFF / 0 | 0 | OFF | 300 / 3400 | 0 | 0% | 8 bit / 2x |
| **Sci-Fi Alien** | ON | 50% | 110 | 130 | 2 / 10 | OFF / 0 | +7 st | OFF | 700 / 3200 | 0 | 70% | 0 / 1x |
| **T-Pain** | ON | 0% | 110 | 0 | 5 / 30 | OFF / 0 | 0 | Chromatic | 0 / 0 | 0 | 0% | 0 / 1x |
| **Stephen Hawking**| ON | 0% | 110 | 0 | 5 / 30 | OFF / 0 | 0 | 120 Hz Monotone | 0 / 0 | 0 | 0% | 0 / 1x |
| **Megatron** | ON | 65% | 80 | 80 | 4 / 40 | OFF / 0 | -7 st | OFF | 90 / 4000 | 0 | 65% | 0 / 1x |

---

## 3. IPC Command Set & Engine Node Names

### IPC Stdin Commands (`main.c:2730-3229`)
- `SRC <node_name>`: Points input capture stream to target hardware microphone.
- `SINK_TGT <node_name>`: Points output stream to target hardware sink.
- `MON <0|1>`: Toggle side-tone mic monitor.
- `RNN <0|1>`, `AGG <0..1000>`: Input RNNoise enable and soft gate aggressiveness.
- `EQ <0|1>`, `EGN <centidb>`, `EQB <idx> <type> <freq> <q> <gain>`: 9-band input EQ.
- `VOP <mix> <hz> <atk> <rel> <det> <follow> <shift>`: Vocoder carrier parameters.
- `VOC <0|1>`, `PSH <centisemis>`, `ATN <0|1>`, `ATT <hz>`, `BCR <bits> <ds>`, `BPF <hpf> <lpf>`, `STT <hz> <duty>`, `MTX <intensity>`: Voice transformers.
- `DLY <0|1>`, `DLP <ms> <fb> <mix>`, `RVB <0|1>`, `RVP <room> <damp> <width> <mix>`: Delay/Reverb.
- `VOL <0..2000>`: Master gain.
- `QUIT`: Engine graceful termination.

### PipeWire Node Names & Media Classes Created by Engine
- `ghelper-audio-capture` (`Stream/Input/Audio`) — Captures from hardware mic.
- `ghelper-audio` (`Audio/Source`) — Virtual Microphone exposed to apps.
- `ghelper-audio-monitor` (`Stream/Output/Audio`) — Headphone side-tone monitor.
- `ghelper-audio-sink` (`Audio/Sink`) — Virtual output playback sink.
- `ghelper-audio-sink-out` (`Stream/Output/Audio`) — Playback stream to physical speakers/headphones.

**Hardcoded or Configurable?**
Node names are **strictly hardcoded string literals** in `main.c` (`PW_KEY_NODE_NAME, "ghelper-audio"` etc.). They cannot be configured via CLI flags or arguments without patching and recompiling the C source.

---

## 4. Replication Mapping: Native PipeWire Filter-Chain vs. Dusky Engine

| DSP Stage | Replicable in Native Filter-Chain? | Exact Plugin / Module | Rationale |
| :--- | :---: | :--- | :--- |
| **70 Hz Highpass Filter** | **YES** | Built-in `bq_highpass` | Direct Robert Bristow-Johnson biquad built into PipeWire (`builtin`). Zero CPU, native. |
| **RNNoise Suppression** | **YES** | `librnnoise_ladspa.so` (`noise_suppressor_mono`) | Upstream package `noise-suppression-for-voice`. Exact same Xiph neural net with configurable VAD threshold and grace. |
| **Adaptive Soft Gate** | **YES** | `noise_suppressor_mono` + `http://lsp-plug.in/plugins/ladspa/gate_mono` | RNNoise LADSPA provides VAD threshold/grace; LSP Gate Mono provides exact hysteresis and hold. |
| **Vocal 9-Band EQ** | **YES** | Built-in `bq_peaking`, `bq_lowshelf`, `bq_highshelf` (or LSP EQ) | PipeWire built-in biquads match Dusky's exact RBJ filter code with zero overhead. |
| **Compressor & Limiter** | **YES** | `http://lsp-plug.in/plugins/ladspa/compressor_mono`, `limiter_mono` | Broadcast vocal leveling, prevents speech clipping and maintains clean volume. |
| **Static Pitch Shift** | **YES** | `ladspa-rubberband.so` (`rubberband-pitchshifter-mono`) | Static deep/high pitch shifting with formant preservation. Replicable as a separate static filter-chain. |
| **Vocoder & Saw Carrier**| **NO** | Dusky Engine (`main.c`) | Requires dual-input synthesis, internal saw carrier tracking, detuning, and formant filterbank. LADSPA vocoders (`vocoder_1337`) lack integrated dynamic saw oscillators and pitch tracking. |
| **Real-time Autotune** | **NO** | Dusky Engine (`main.c`) | Requires real-time pitch detection + instant phase-locked pitch quantization. No standalone LADSPA equal-temperament quantizer exists in core repos. |
| **Cylon Stutter Gate** | **NO** | Dusky Engine (`main.c`) | Custom variable-duty LFO amplitude chopper with smooth 5ms transitions. |
| **Bitcrusher + Matrix** | **NO** | Dusky Engine (`main.c`) | Custom sample-and-hold + 35 Hz ring mod + tanh drive combination. |

---

## 5. Potential Conflicts with User System Stack

1. **Node Name Collision:** Dusky C engine creates `ghelper-audio`. If a native filter-chain also defines `ghelper-audio`, PipeWire will reject or duplicate the node name.  
   $\rightarrow$ *Resolution:* Patch Dusky engine to create `ghelper-fx` and `ghelper-fx-capture`. The native clean filter-chain owns `ghelper-audio`.
2. **Buffer Quantum & Sample Rates:** Dusky engine hardcodes `SAMPLE_RATE 48000` and buffers in 480-sample blocks. System `10-low-latency.conf` sets `default.clock.quantum = 512` and rate `48000`.  
   $\rightarrow$ *Resolution:* Both operate at $48\text{ kHz}$. $480$ samples fits cleanly inside $512$ quantum buffers without resampling drift.
3. **Session Interruption on Engine Restart:** If Dusky runs as an always-on service, it competes for the default mic route.  
   $\rightarrow$ *Resolution:* Disable `dusky-audio-dsp.service`. Native filter-chain is always on; Dusky runs only on-demand when character presets are active.

---

## 6. System Audit Findings (Phase 2)

- **PipeWire:** `1.6.9`, **WirePlumber:** `0.5.18`.
- **Raw ALC256 Hardware Mic:** `alsa_input.pci-0000_00_1f.3.analog-stereo`.
- **Verified Plugin Ports:**
  - `librnnoise_ladspa.so` (`noise_suppressor_mono`): Ports `"Input"`, `"Output"`, `"VAD Threshold (%)"`, `"VAD Grace Period (ms)"`, `"Retroactive VAD Grace (ms)"`, `"Dry Mix"`.
  - `lsp-plugins-ladspa.so` (`http://lsp-plug.in/plugins/ladspa/compressor_mono`): Ports `"Input"`, `"Output"`, `"Attack threshold (G)"`, `"Attack time (ms)"`, `"Release time (ms)"`, `"Ratio"`, `"Knee (G)"`, `"Makeup gain (G)"`.
  - `lsp-plugins-ladspa.so` (`http://lsp-plug.in/plugins/ladspa/limiter_mono`): Ports `"Input"`, `"Output"`, `"Threshold (G)"`, `"Lookahead (ms)"`, `"Attack time (ms)"`, `"Release time (ms)"`, `"Gain boost"`.
  - `ladspa-rubberband.so` (`rubberband-pitchshifter-mono`): Ports `"Input"`, `"Output"`, `"Semitones"`, `"Octaves"`, `"Crispness"`, `"Formant Preserving"`.
