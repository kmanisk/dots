# ASUS TUF Gaming F16 (FX608JH) Speaker DSP & Audio Stack Manifest

## 1. Executive Summary & Provenance
- **Target Hardware**: ASUS TUF Gaming F16 FX608JH (Intel i5-13450HX + RTX 5050 Mobile).
- **Audio Codec**: Realtek ALC256 (Subsystem ID: `1043:1084`).
- **Forensic Extraction Source**: Windows 11 partition mounted at `/mnt/windows` (`/mnt/Windows`):
  - OEM Tuning XML: `Windows/System32/DriverStore/FileRepository/dax3_ext_rtk.inf_amd64_80f9d51a8c40add3/DEV_0256_SUBSYS_10431084_PCI_SUBSYS_10841043.xml`
  - Live Runtime State: `ProgramData/Dolby/DAX3/Runtime.xml`
  - APO & DAP Drivers: `dax3_swc_aposvc.inf_amd64_6c19a4caad42dde0/Dax3DapControl.dll`
- **Audio Architecture**: PipeWire 1.6.9 + WirePlumber 0.5 native smart filter chain (48 kHz / 512 quantum).
- **Reproducibility**: 100% offline, clean-room tracked in Chezmoi (`~/.local/share/chezmoi`). Zero daemons, zero polling, zero Wine.

---

## 2. Complete Profile Feature Matrix & Architecture

| Profile | Subcommand | Acoustic Target (20-Band) | Dialog Enhancer | Volume Leveler (AGC) | Surround Virtualizer | Volmax Boost | Sonic Profile & Character |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Dynamic** | `spk dynamic` / `spk dyn` | OEM Dynamic curve | +1.9 dB @ 2.5 kHz | ON (-20 dBFS target) | ON (Calf M/S +6.0 dB) | +2.5 dB | Authentic Windows default; balanced, punchy, expansive stereo |
| **Movie** | `spk movie` / `spk m` | OEM Movie curve (warm bass, soft highs) | +1.9 dB @ 2.5 kHz | ON (-20 dBFS target) | ON (Calf M/S +6.0 dB) | +2.5 dB | Cinematic presence, warm sub-bass, dialog clarity, wide soundstage |
| **Music** | `spk music` / `spk mu` | OEM Music curve (wide frequency ext) | Disabled (pure tone) | OFF (Uncompressed dynamics) | OFF (Natural stereo width) | +3.5 dB | Audiophile transparency, pristine dynamic transients, multi-band compression |
| **Game** | `spk game` / `spk g` | OEM Game curve | Disabled (flat mid) | ON (-20 dBFS target) | Directional Spatial | +6.0 dB | Maximum punch, high perceived volume, pin-point audio cues |
| **Voice** | `spk voice` / `spk v` | OEM Voice curve (-15 dB sub-rumble cut) | +3.0 dB @ 2.5 kHz | ON (-20 dBFS target) | OFF (Mono center focus) | +3.0 dB | Podcasts & meetings; eliminates laptop vibrations, emphasizes vocals |
| **Custom 2** | `spk custom` / `spk c` | Dynamic base + User2 GEQ (+11.6 dB presence) | +3.8 dB @ 2.5 kHz | ON (-20 dBFS target) | ON (Calf M/S +3.0 dB) | +6.0 dB | Live user Dolby Access preset recovered from `Runtime.xml` |
| **Balanced** | `spk balanced` / `spk b` | Upstream DAX3 Reference | +1.9 dB @ 2.5 kHz | OFF (Manual headroom) | OFF (Clean stereo) | +2.5 dB | Clean Linux reference tuning baseline |
| **Detailed** | `spk detailed` / `spk d` | Upstream DAX3 Detailed | +1.9 dB @ 2.5 kHz | OFF (Manual headroom) | OFF (Clean stereo) | +2.5 dB | High-frequency clarity and crispness |
| **Warm** | `spk warm` / `spk w` | Upstream DAX3 Warm | +1.9 dB @ 2.5 kHz | OFF (Manual headroom) | OFF (Clean stereo) | +2.5 dB | Bass contour emphasis without loudness leveler |

---

## 3. Audio Processing Stack & Routing Topology

```text
Normal Desktop Audio (Brave, Spotify, MPV, System Sounds)
             │
             ▼
   [ Built-in Audio Analog Stereo ]
             │
             ▼ (Transparent WirePlumber 0.5 Smart Filter)
   [ effect_input.Dolby_Speaker ]
             │
   ┌─────────┴───────────────────────────────────────────┐
   │ Native PipeWire Filter Chain:                       │
   │ 1. Built-in Stereo Convolver (4096-tap FIR .irs)    │
   │ 2. LSP Para Equalizer x16 LR (Dialog Enhancer)      │
   │ 3. LSP Autogain Stereo (Volume Leveler / DRC)       │
   │ 4. Calf StereoTools (M/S Surround Virtualizer)      │
   │ 5. LSP Multiband Compressor (Acoustic Regulator)    │
   │ 6. LSP Limiter Stereo (Peak Overdrive Clamping)     │
   └─────────┬───────────────────────────────────────────┘
             │
             ▼
   [ ALC256 Internal Laptop Speakers ]
```

### Auto-Bypass Behavior:
- **Headphones Plugged (3.5mm)**: `dax-speaker-route.lua` automatically detects route `analog-output-headphones` and sets `filter.smart.disabled = true`. Applications bypass DSP directly to flat headphone output.
- **External Outputs (Bluetooth / USB / HDMI)**: Completely uninhibited and unrouted through the laptop speaker filter.
- **Physical Sink Cycling (`Alt+Shift+O` / `toggle-audio-sink`)**: Dynamically cycles across all active physical outputs (Boult BassBox, Bluetooth headsets, ALC256, HDMI) while properly filtering virtual effect nodes.

---

## 4. Strict Gaming Audio & Microphone Invariants

The gaming audio processing chain and Dusky studio mic capture are isolated and completely untouched:

```text
Game (CS2, ARC Raiders, The Finals, Hunt, Apex)
             │
             ▼
     [ sink.peace_gaming ]
             │
   ┌─────────┴───────────────────────────────────────┐
   │ Native LADSPA/PipeWire Gaming DSP:              │
   │ 1. Peace Gaming Parametric EQ (Footstep Curve)  │
   │ 2. Native LoudMax LADSPA v1.47 Limiter          │
   └─────────┬───────────────────────────────────────┘
             │
             ▼
     [ Current Output Sink (Headphones / Speakers) ]
```

- **Microphone Capture**: Managed independently by `dusky-audio-dsp.service` with RNNoise DSP.

---

## 5. Tracked Component Directory Structure

| File Path | Description |
| :--- | :--- |
| `~/.config/pipewire/asus-tuf-dax/dynamic/` | Windows DAX3 Dynamic profile (`Dolby_Speaker.conf` & `.irs`) |
| `~/.config/pipewire/asus-tuf-dax/movie/` | Windows DAX3 Movie profile (`Dolby_Speaker.conf` & `.irs`) |
| `~/.config/pipewire/asus-tuf-dax/music/` | Windows DAX3 Music profile (`Dolby_Speaker.conf` & `.irs`) |
| `~/.config/pipewire/asus-tuf-dax/game/` | Windows DAX3 Game profile (`Dolby_Speaker.conf` & `.irs`) |
| `~/.config/pipewire/asus-tuf-dax/voice/` | Windows DAX3 Voice profile (`Dolby_Speaker.conf` & `.irs`) |
| `~/.config/pipewire/asus-tuf-dax/custom/` | Windows Dolby Access Custom 2 profile (`Dolby_Speaker.conf` & `.irs`) |
| `~/.config/pipewire/asus-tuf-dax/balanced/` | Linux DAX3 Balanced profile (`Dolby_Speaker.conf` & `.irs`) |
| `~/.config/pipewire/asus-tuf-dax/detailed/` | Linux DAX3 Detailed profile (`Dolby_Speaker.conf` & `.irs`) |
| `~/.config/pipewire/asus-tuf-dax/warm/` | Linux DAX3 Warm profile (`Dolby_Speaker.conf` & `.irs`) |
| `~/.config/pipewire/pipewire.conf.d/Dolby_Speaker.conf` | Active runtime PipeWire filter-chain configuration |
| `~/.config/pipewire/pipewire.conf.d/Dolby_Speaker.irs` | Active runtime minimum-phase FIR impulse response (48 kHz) |
| `~/.config/pipewire/pipewire.conf.d/30-peace-gaming.conf` | Dedicated gaming audio DSP chain (LoudMax + Peace EQ) |
| `~/.config/wireplumber/wireplumber.conf.d/40-dax-speaker-route.conf` | WirePlumber configuration hook for speaker route monitor |
| `~/.config/wireplumber/wireplumber.conf.d/50-gaming-audio.conf` | WirePlumber configuration hook for game stream routing |
| `~/.local/share/wireplumber/scripts/dax-speaker-route.lua` | WirePlumber 0.5 Lua route monitor (Speaker vs Headphone auto-toggle) |
| `~/.local/share/wireplumber/scripts/gaming-audio-route.lua` | WirePlumber 0.5 Lua game stream routing monitor |
| `~/.local/bin/spk` | POSIX CLI utility for instant profile switching and state management |
| `~/.config/fish/functions/spk.fish` | Fish shell function wrapper for `spk` |
| `~/.config/fish/completions/spk.fish` | Fish tab completions for `spk` subcommands |
| `~/.local/bin/toggle-audio-sink` | Physical audio sink cycling utility with smart filter avoidance |
| `~/.local/bin/asus-speaker-doctor` | Comprehensive verification and diagnostic tool (23/23 tests pass) |
| `~/.local/bin/rofi-speaker-dsp` | Interactive Rofi menu for ASUS Speaker DSP (symlinked to `rofi-spk`) |
| `~/.local/share/applications/rofi-speaker-dsp.desktop` | Desktop application entry for application launchers |
| `~/.config/asus-speakers/state.conf` | Persistent state storage (`ACTIVE_VOICING`, `ENABLED`) |

---

## 6. CLI & Rofi Usage Reference

### CLI Commands (`spk`)
```bash
# View current status and active telemetry
spk
spk status

# Switch to authentic Windows DAX3 modes
spk dynamic   # or: spk dyn (Windows default)
spk movie     # or: spk m (Cinema soundstage)
spk music     # or: spk mu (Audiophile dynamics)
spk game      # or: spk g (+6dB loudness boost)
spk voice     # or: spk v (Speech clarity / low-cut)
spk custom    # or: spk c (Recovered User 2 preset)

# Switch to Linux reference voicings
spk balanced  # or: spk b
spk detailed  # or: spk d
spk warm      # or: spk w

# Bypass / Re-enable without service restart
spk off       # Sets filter.smart.disabled=true
spk on        # Sets filter.smart.disabled=false

# Full system diagnostic (23 test suite)
asus-speaker-doctor
```

### Rofi Interactive Controls
- **Launcher Script**: `rofi-speaker-dsp` (or `rofi-spk`)
- **Keybindings**:
  - `Super + Alt + 4`
  - `Super + Alt + O`
- **Features**:
  - Displays live physical route & smart filter bypass status in the boxed message bar.
  - Radio button visual indicators for active profile across all 9 modes.
  - Pre-selected cursor positioned on the active preset for instant selection.
  - Allows cycling physical audio devices (`Alt+Shift+O`) directly within the menu.
