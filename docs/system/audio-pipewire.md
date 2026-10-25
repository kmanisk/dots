# Audio & PipeWire Architecture Reference

Comprehensive reference for the system's low-latency audio stack, PipeWire configuration, headless DSP microphone filtering, and WirePlumber routing policies.  
Use this document as the single source of truth for all audio routing and latency invariants.

---

## 1. Core Audio Architecture

* **Sound Server:** PipeWire (with `wireplumber` session manager and `pipewire-pulse` compatibility daemon).
* **Clock & Quantum Tuning (`~/.config/pipewire/pipewire.conf.d/10-low-latency.conf`):**
  * Sampling Rate: `48000 Hz` (fixed single clock domain).
  * Default Quantum: `512` (10.7ms buffer @ 48kHz).
  * Allowed Rates: `[ 48000 ]`.
  * Quantum Range: Min `64`, Max `2048`.
  * **Rationale:** Provides rock-solid Bluetooth audio stability without dropouts under heavy CPU/GPU load while delivering ultra-low latency for competitive gaming (CS2).
* **Denormals Mitigation (`~/.config/pipewire/pipewire.conf.d/10-denormals.conf`):**
  * `cpu.zero.denormals = true` prevents CPU floating-point underflow stalls across LADSPA and LV2 DSP plugins.

---

## 2. Headless Microphone Processing (`40-mic.conf`)

* **Role:** High-performance, in-process LADSPA neural denoiser and vocal DSP chain hosted directly inside PipeWire's `libpipewire-module-filter-chain`.
* **Virtual Source Node:** `ghelper-audio` (Priority 3000, locked as default system recording device).
* **Footprint:** Extremely lightweight:
  * Memory: **< 40 MB RSS** (in-process shared memory).
  * CPU Usage: **< 1.5%** of a single CPU core.
* **DSP Processing Stages:**
  1. 80 Hz Sub-Rumble High-Pass Filter (RBJ biquad)
  2. DPDFNet Neural AI Denoiser (`libdpdfnet_ladspa.so` from `hushmic-bin`, 45 dB soft attenuation floor)
  3. Latency Compensation (80 ms model context reporting)
  4. In-Chain Creative Voice FX Engine (RubberBand pitch/formant, RingMod, Decimator, Flanger, Delayorama, FX EQ)
  5. Broadcast Parametric EQ Cascade (ALC256 capsule correction: -1.5 dB @ 400 Hz, +1.5 dB @ 3.5 kHz)
  6. Studio Vocal Compressor (Anti-shout dynamic protection: 5ms attack, 120ms hold, 500ms release, +4 dB Quiet Voice Boost leveling on Natural Clean)
  7. Studio Lookahead True Peak Limiter (-2.0 dBFS ceiling, +2 dB creative model boost)
* **System Invariant (User Rule):**
  > **NEVER spawn external background daemons or switch virtual recording nodes.**  
  > All creative voice transformations and clean microphone processing occur in-line within `ghelper-audio`. Applications (Discord, Steam, CS2, OBS) stay locked to `ghelper-audio` without stream drops.

---

## 3. Playback DSP & Dynamic WirePlumber Routing

### A. Device-Agnostic Dolby Headphones (`42-dolby-headphones.conf`)
* **Node:** `effect_input.Dolby_Headphones`
* **Stages:**
  1. Dialogue Clarity: LSP 16-band Parametric EQ (+2 dB peaking boost at 3000 Hz, Q = 1.0)
  2. AutoGain Leveler: LSP AutoGain Stereo (Target −18.0 dBFS, max boost +6.0 dB)
  3. Multiband Dynamics: LSP Multiband Compressor (2:1 dynamic control, 5ms attack, 100ms release)
  4. Studio Limiter: LSP True-Peak Limiter Stereo (−0.1 dBFS ceiling)

### B. ASUS TUF DAX3 Dolby Speaker DSP (`asus-speaker-dsp.service`)
* **Node:** `effect_input.Dolby_Speaker` via standalone user service on CPU affinity 0-11
* **Stages:** Direct convolution using factory Windows DAX3 impulse response (`Dolby_Speaker.irs`), 45 Hz driver excursion protection high-pass filter, 16-band parametric EQ per voicing, and multiband limiter.
* **Profiles:**
  1. `tuned`: Focused & Natural (default, slev 1.30 spatializer width, clean +11.6 dB presence curve).
  2. `tuned-old`: Wide staging (slev 1.82 expansive soundstage).
  3. `custom`: Windows Dolby Access Custom 2 profile (+11.6 dB presence peak).
  4. `dynamic`: Windows DAX3 default (+9.0 dB makeup gain, slev 1.45, AutoGain Leveler + Spatial).
  5. `music`: Windows DAX3 Audiophile (+11.0 dB makeup gain, uncompressed natural dynamics).
  6. `balanced`: Reference Linux baseline (+9.0 dB makeup gain, slev 1.0).
  7. `experimental`: Tuned curve with pre-convolver harmonic bass enhancement.
* **Control:** Managed via `spk` CLI or `rofi-speaker-dsp`.

### C. Competitive Gaming Low-Latency Bypass (`30-peace-gaming.conf`)
* **Node:** `sink.peace_gaming` (Priority -1, passive playback)
* **Stages:** 7-band RBJ Biquad footstep peaking curve (Peace PUBG target) + LoudMax lookahead limiter (`ldmx_stereo`, -15.2 dB threshold, -2.3 dB output).
* **Dual-Layer Interception:** `cs2-launch` initializes `PIPEWIRE_NODE="sink.peace_gaming"`; WirePlumber hook `gaming-audio-route.lua` (Hook 2) automatically routes competitive games (CS2, The Finals, Apex, PUBG, Hunt: Showdown, ARC Raiders) into `sink.peace_gaming`, completely bypassing Dolby processing.
* **Dynamic Target Tracking:** Hook 1 dynamically routes `playback.peace_gaming` directly to the active hardware sink (`bluez_output.*` on Bluetooth, `alsa_output.*` on headphones/speakers), re-linking cleanly on `Alt + Shift + O`.
* **Migration Immunity:** All stream relocation scripts (`toggle-audio-sink`, `spk`, `rofi-speaker-dsp`) strictly exclude competitive game streams.

### D. Dynamic Target Preservation & Mutual Exclusion (`dax-speaker-route.lua` & `spk`)
* **Dynamic Preset Switching:** Switching profiles via `spk` or `rofi-speaker-dsp` detects the active hardware destination. On Bluetooth or wired headphones, `Dolby_Speaker` is strictly disabled (`filter.smart.disabled = true`), `Dolby_Headphones` remains active, and audio never leaks or switches to internal laptop speakers.
* **Mutual Exclusion:** When headphones (3.5mm jack or Bluetooth) are active, `Dolby_Headphones` is enabled and `Dolby_Speaker` FIR is disabled. When internal speakers are active, `Dolby_Speaker` is enabled and `Dolby_Headphones` is disabled.
* **User Bypass Sync:** `dax-speaker-route.lua` respects `filter.smart.user_disabled` live so `spk on` / `spk off` commands take effect without restarting services.

### E. Self-Healing Hardware Volume Control (`volume-notify`)
* **Physical Sink Resolution:** Resolves the true hardware sink (`bluez_output.*` or `alsa_output.*`) via WirePlumber default metadata and active links. Never targets virtual filter nodes or gaming sinks.
* **Self-Healing Anchor:** If `pactl get-default-sink` is ever erroneously captured by a virtual node, `volume-notify` immediately restores the default sink to the physical hardware device.
* **Filter Headroom Pinning:** Volume on `effect_input.Dolby_Speaker`, `effect_input.Dolby_Headphones`, and `sink.peace_gaming` is pinned to 1.0 (100% unmute) on every volume event.

---

## 4. Visualizer: Cava Integration & Retheming

* **Configuration:** `~/.config/cava/config` (templated from `~/.config/theme/templates/cava.conf`).
* **Visual Invariants:**
  * **No Rainbow Gradients:** `gradient = 0`.
  * **Solid Accent Foreground:** Renders using the active theme's prominent primary accent color (`foreground = '{{accent}}'`).
  * **Terminal Transparency:** `background = 'default'` allows the terminal's native background and opacity to show through cleanly without solid bounding boxes.
* **Live Reloading:**
  * Whenever a new theme is applied via `theme-set`, `theme-set` dynamically rewrites the `[color]` section and issues `killall -SIGUSR2 cava`.
  * Cava reloads colors instantly without restarting the audio capture stream.

---

## 5. Bluetooth Audio: Policy & Management (RULE 10)

### 5.1 Strict A2DP Policy (`~/.config/wireplumber/wireplumber.conf.d/11-bluetooth-policy.conf`)
* **A2DP Playback Locked:** `bluez5.roles = [ a2dp_sink a2dp_source ]`
* **Hands-Free Backend Suppressed:** `bluez5.hfphsp-backend = "none"`
* **Codecs:** High-fidelity AAC and SBC-XQ (`bluez5.codecs = [ aac sbc_xq sbc ]`).
* **No Profile Degradation:** Bluetooth headphones (e.g., Soundcore Q20i) **never** switch into low-bandwidth HSP/HFP mode (`mSBC` or `CVSD`).
* **Microphone Authority:** Voice recording always uses the laptop's internal microphone via `ghelper-audio`.

### 5.2 Bluetooth TUI Manager (`bluetui`)
* Launched via kitty: `kitty --class bluetui -e bluetui`
* Bound to `$mod + Alt + 2` (`Super + Alt + 2`).
* Zero background daemons, zero resident memory when closed.

---

## 6. Maintenance & File Locations

| File | Purpose |
| :--- | :--- |
| `~/.config/pipewire/pipewire.conf.d/10-low-latency.conf` | Quantum and sampling rate latency rules |
| `~/.config/pipewire/pipewire.conf.d/10-denormals.conf` | CPU denormals zeroing for DSP plugins |
| `~/.config/pipewire/pipewire.conf.d/30-peace-gaming.conf` | Peace Gaming competitive audio sink |
| `~/.config/pipewire/pipewire.conf.d/40-mic.conf` | Unified DPDFNet microphone & voice FX filter chain |
| `~/.config/pipewire/pipewire.conf.d/42-dolby-headphones.conf` | Device-agnostic Dolby Headphone enhancement |
| `~/.config/wireplumber/wireplumber.conf.d/10-alsa-policy.conf` | ALSA auto-profile and jack policy |
| `~/.config/wireplumber/wireplumber.conf.d/11-bluetooth-policy.conf` | Strict Bluetooth A2DP policy |
| `~/.local/share/wireplumber/scripts/dax-speaker-route.lua` | Dynamic speaker / headphone mutual exclusion switcher |
| `~/.local/share/wireplumber/scripts/gaming-audio-route.lua` | Dynamic competitive game audio router |
| `~/.config/micstudio/presets.toml` | MicStudio 27 voice model definitions |
| `~/.config/micstudio/settings.toml` | MicStudio clean mic telemetry & leveling settings |
| `~/.config/cava/config` | Cava audio visualizer configuration |
| `~/.config/theme/templates/cava.conf` | Theme template for Cava |
