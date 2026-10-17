# Audio Stack Hardening & Gaming Pipeline Baseline Report

**Date:** October 16, 2026  
**Target Hardware:** ASUS TUF Gaming F16 FX608JH (Intel i5-13450HX + NVIDIA RTX 5050 Mobile)  
**Audio Codec:** Realtek ALC256 (HDA Intel PCH)  
**Audio Framework:** Native PipeWire 1.6.9 + WirePlumber 0.5  
**Document Location:** `~/.local/share/chezmoi/docs/audio/2026-10-16_GAMING_AUDIO_BASELINE.md`

---

## 1. Executive Summary

This baseline establishes a rock-solid, zero-dropout audio architecture across competitive gaming (CS2 / `sink.peace_gaming`), upstream ASUS DAX3 Dolby Speaker DSP, and system volume controls. 

Key issues resolved:
1. **Eliminated Game Audio Drops / "Hard Reload" Requirements**:
   - `Alt + Shift + O` (`toggle-audio-sink`) no longer severs `playback.peace_gaming` links when cycling between internal speakers and wired 3.5mm headphones.
   - Competitive games (CS2 SDL3) now transition between speakers and headphones seamlessly without thread stalls, broken pipe errors, or needing to restart the game.
2. **Volume Clamped to Strict 100% Ceiling**:
   - `volume-notify` capped at `-l 1.0` (100%), preventing digital clipping, distortion, and ear fatigue.
3. **Instant Dolby DAX3 Preset Switching**:
   - Filter-chain runner profiles declare explicit hardware target endpoints (`target.object`).
   - WirePlumber `dax-speaker-route.lua` dynamically tracks node lifecycle (`object-added`/`object-removed`) events, eliminating silence on profile changes.
4. **Gaming Audio Headroom & Volume Lock**:
   - `sink.peace_gaming` volume is automatically pinned to `1.0` (100%) during sink transitions, ensuring in-game sound effects (footsteps, reloads) are never quietly attenuated.

---

## 2. Root Cause & Architectural Analysis

### A. The CS2 "Hard Reload" Dilemma
- **Mechanism**: CS2 on Linux connects to PipeWire through SDL3. When `cs2-launch` binds `PIPEWIRE_NODE="sink.peace_gaming"`, SDL3 feeds into `sink.peace_gaming` (LoudMax + Peace EQ), which outputs via `playback.peace_gaming` to `alsa_output.pci-0000_00_1f.3.analog-stereo`.
- **Fault**: The legacy audio switcher ran an unconditional `pw-link -d` on `playback.peace_gaming` output ports on every invocation.
- **Impact**: When toggling between internal laptop speakers and the 3.5mm headphone jack, both targets reside on the **same physical ALSA sink**. Severing the stream mid-game caused an SDL3 buffer underflow / xrun, resulting in permanent game silence until CS2 was killed and re-launched.

### B. Volume Exceeding 100%
- **Mechanism**: The fast Dunst OSD volume handler invoked `wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+`.
- **Impact**: Allowed the master hardware volume to reach 150%, driving software over-amplification into analog preamp distortion.

### C. Dolby DAX3 Preset Silence on Switch
- **Mechanism**: Changing speaker DSP voicings via `spk <profile>` restarts `asus-speaker-dsp.service`.
- **Fault**: WirePlumber's `dax-speaker-route.lua` only hooked into the `installed` signal for speaker filter nodes, failing to execute `syncFilterStates()` when nodes were dynamically destroyed and re-created. Additionally, `playback.props` in runner configurations lacked explicit `target.object` directives.
- **Impact**: Newly spawned filter outputs were unlinked, sending audio into a void until audio devices were manually cycled.

---

## 3. Implemented Fixes & Architectural Hardening

### Component 1: `toggle-audio-sink` (`~/.local/bin/toggle-audio-sink`)
- **Same-Sink Link Bypass**: Added guard `[[ -n "$CURRENT_SINK" && "$NEXT_SINK" != "$CURRENT_SINK" ]]`. Cycling between `alsa:speaker` and `alsa:headphones` performs ALSA port switching and unmuting **without touching the active gaming stream**.
- **Make-Before-Break External Routing**: If routing to Bluetooth, the new destination ports are linked *before* existing links are pruned, preventing audio pipeline collapse.
- **Unconditional 3.5mm Jack Inclusion**: Headphone target is always present in rotation, independent of physical sensor quirks.
- **Hardware Port Unmute Sequence**: Runs `pactl set-sink-port` followed by explicit ALSA hardware unmuting (`amixer -c 0 sset Headphone 100% unmute`, `amixer -c 0 sset Speaker 100% unmute`, `amixer -c 0 sset Master unmute`, and `wpctl set-mute`).
- **Gaming Volume Pinning**: Pins `sink.peace_gaming` volume to `1.0` (100%).

### Component 2: `volume-notify` (`~/.local/bin/volume-notify`)
- Replaced `-l 1.5` with `-l 1.0` in `wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+`.
- Clamps maximum volume strictly at 100%.

### Component 3: PipeWire DAX3 Speaker Filter Runners (`~/.config/pipewire/asus-tuf-dax/*/runner.conf`)
- Added explicit `target.object = "alsa_output.pci-0000_00_1f.3.analog-stereo"` in `playback.props` across all 4 production profiles:
  - `custom/runner.conf` (Windows Dolby Access Custom 2 profile)
  - `dynamic/runner.conf` (Default DAX3 profile)
  - `balanced/runner.conf` (Balanced baseline)
  - `music/runner.conf` (Audiophile profile)

### Component 4: WirePlumber Route Policy (`~/.local/share/wireplumber/scripts/dax-speaker-route.lua`)
- Added `object-added` and `object-removed` signal handlers to `speaker_node_om`, `spk_playback_om`, `hp_node_om`, and `hp_playback_om`.
- Guarantees immediate filter re-attachment and routing synchronization upon any service restart.

### Component 5: Speaker DSP Control (`~/.local/bin/spk`)
- In `apply_voicing()`, added a node detection loop followed by explicit fallback `pw-link` commands.

---

## 4. Verification & Validation Audit

| Audit Item | Test Method | Result | Status |
| :--- | :--- | :--- | :--- |
| **CS2 In-Game Output Switch** | Cycled `Alt + Shift + O` continuously during live gameplay | Zero drops, zero underruns, sound continuous | **PASS** |
| **3.5mm Headphone Jack** | Toggled to `Wired Headphones (3.5mm)` | Clean high-fidelity stereo via ALC256 DAC | **PASS** |
| **Volume Ceiling** | Held `Volume Up` key on keyboard | Strictly clamped at `Volume: 1.00` (100%) | **PASS** |
| **Dolby Preset Switching** | Switched `spk custom` ↔ `spk dynamic` ↔ `spk music` | Instant profile transition without silence | **PASS** |
| **Audio Doctor 11-Point Suite** | Ran `audio doctor` audit command | 11/11 tests passed with 0 errors, 0 warnings | **PASS** |
| **Sway Configuration Syntax** | Executed `sway -C` | 0 syntax errors, clean live reload | **PASS** |

---

## 5. File Inventory of Changes

- `~/.local/bin/toggle-audio-sink` (`dot_local/bin/executable_toggle-audio-sink`)
- `~/.local/bin/volume-notify` (`dot_local/bin/executable_volume-notify`)
- `~/.local/bin/spk` (`dot_local/bin/executable_spk`)
- `~/.local/share/wireplumber/scripts/dax-speaker-route.lua` (`dot_local/share/wireplumber/scripts/dax-speaker-route.lua`)
- `~/.config/pipewire/asus-tuf-dax/*/runner.conf` (`dot_config/pipewire/asus-tuf-dax/*/runner.conf`)
- `~/docs/audio/AUDIO_ARCHITECTURE.md` (`docs/audio/AUDIO_ARCHITECTURE.md`)
- `~/docs/audio/2026-10-16_GAMING_AUDIO_BASELINE.md` (`docs/audio/2026-10-16_GAMING_AUDIO_BASELINE.md`)

---

## 6. Addendum (2026-10-17 Follow-up Audit)

- Speaker profiles expanded beyond the 4 listed at baseline: `tuned`, `tuned-old`, and `experimental` are now available; historical voicings archived in `~/.config/pipewire/asus-tuf-dax/archive/`.
- Redundant state copies (`active.conf`, `active.irs`) removed. Profile deploy is now symlink-only (`active-runner.conf` -> `<profile>/runner.conf`), with the selection recorded in `~/.config/asus-speakers/state.conf`.
- The DAX3 speaker DSP chain is verified to run as a client of the main PipeWire server (`pw-top` + client PID match with `asus-speaker-dsp.service`), scheduled by the main clock: 48 kHz, quantum 512. No separate clock configuration is required or effective in `runner.conf`.
- LSP `cr_0` confirmed as compression ratio via the installed plugin metadata (`/usr/lib/lv2/lsp-plugins.lv2/mb_compressor_stereo.ttl`: `a lv2:CompressorPlugin`, `cr_0` = "Ratio 1", minimum 1.0). The headphone multiband stage (`cr_0 = 2.0`) is therefore 2:1 compression, not expansion.
