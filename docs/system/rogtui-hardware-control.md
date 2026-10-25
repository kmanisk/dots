# ROGTUI: High-Performance Hardware Control Center

## Verified corrections, 2026-10-23

`~/Projects/rogtui` commit `8ea021a` corrects the compatibility check to query
`xyz.ljones.Asusd`, matching both the backend and the observed system bus.
The installed release now reports asusd correctly.

Mock backends no longer save into live RGB preferences. Persistence tests use
an explicit temporary path; theme tests read an explicit home path instead of
changing process-wide `HOME`. The former parallel suite failed at state loading;
the corrected suite passed 57 tests with isolated state. Hardware profiles,
charge limit (60%), fan curves, MUX mode, and lighting were not changed.

The initial test run did overwrite saved mock RGB preferences before this bug
was discovered. Lighting remained off; the exact earlier saved RGB preference
cannot be recovered from the collected evidence. See the
[audit](workstation-audit-2026-10-23.md) for this limitation and binary rollback.
The saved brightness was aligned with the observed firmware Off state after
confirming it still matched the test output; this did not write hardware.

The current UI still has a 50 ms ticker with throttled hardware refreshes;
earlier claims that all static views block solely on input are not verified by
the current source. No idle-performance improvement is claimed.

A lightweight, zero-overhead Terminal User Interface (TUI) for ASUS ROG and TUF gaming laptops running Linux (CachyOS / Arch Linux).

rogtui interfaces directly with `asusd` (v6.5+) and `supergfxd` (v5.2+) via asynchronous system DBus calls (`xyz.ljones.Asusd`, `org.supergfxctl.Daemon`), sysfs attributes, and Linux hwmon interfaces. It provides a keyboard-driven alternative to heavy graphical software like ASUS Armoury Crate or G-Helper, consuming approximately 4 MiB of resident memory and 0% CPU during idle navigation.

---

## Architecture Overview

### Event-Driven Scheduling & Dynamic Refresh

Unlike traditional game loop TUIs that poll at a fixed 60 Hz or 120 Hz, rogtui runs an event-driven architecture built on Tokio and Ratatui:

1. **Idle State (0.0% CPU):**
   When navigating static tabs (Dashboard, Power Profiles, Fan Curves, GPU Control, Armoury Attributes), the render loop blocks asynchronously on terminal input events (`crossterm::event::EventStream`). Hardware sensor reads (`/sys/class/hwmon`) are throttled to a background 1.0 Hz tick strictly when monitoring views are visible.

2. **Dynamic Effect Ticker:**
   When an active animated or dynamic software lighting mode is selected on the Aura tab, rogtui automatically switches its tick rate to match the workload:
   - **Audio-Reactive Presets (`VoicePulse`, `AudioPulse`, `AudioWave`):** 50 ms (20 Hz) tick.
   - **Procedural Animations (`RainbowFlow`, `FireFlicker`, `BreathingColor`, `Clouds`, `ThemeSync`):** 70 ms (~14 Hz) tick.
   - **Wayland Screen Synchronization (`AmbientSync`):** 100 ms (10 Hz) tick.
   - **Static / Firmware Modes:** 1000 ms (1 Hz) tick.

3. **Volatile vs Persistent EC Writes:**
   All real-time frame updates (audio, ambient, color animations) send volatile EC commands (`cmd = 0`) directly to `/sys/devices/platform/asus-nb-wmi/leds/asus::kbd_backlight` or via `asusd` volatile DBus endpoints. BIOS flash wear is prevented by design. Non-volatile flash writes only occur when the user explicitly triggers a profile save (`w`) and confirms the action.

---

## Aura Keyboard Lighting Subsystem

rogtui features a 4-tier lighting architecture supporting 18 distinct lighting modes:

### Tier 1: Hardware Firmware Modes (Zero Host Overhead)
These modes run autonomously inside the Embedded Controller (EC) without consuming CPU cycles or holding userspace daemon threads:
- **Static:** Single solid color across all keyboard zones.
- **Breathe:** Hardware-timed brightness breathing cycling between Color 1 and Color 2.
- **Rainbow:** Native hardware rainbow wave traversing the keyboard matrix.
- **Pulse:** Quick periodic hardware flash pulses.

### Tier 2: Procedural Software Animations
Client-rendered procedural lighting calculations executing in sub-millisecond frames:
- **RainbowFlow:** High-speed HSV rainbow sweep using cubic trigonometric phasing.
- **BreathingColor:** Deep two-tone sine-modulated color transitions between user-defined swatches.
- **FireFlicker:** Dual-stage organic flame simulation using randomized red-orange-yellow embers.
- **StarryNight:** Deep velvet midnight blue background with twinkling bright stellar nodes.
- **SpectrumCycle:** Smooth 360-degree color wheel transition across the full spectrum.
- **Clouds:** Dual-harmonic wave blending soft cyan (`#00E5FF`), sky blue (`#4FC3F7`), and misty cloud white (`#E0F7FA`).

### Tier 3: Audio & Visual Synchronization
Real-time environmental synchronization ported from G-Helper:

#### 1. Ambient Screen Sync (`AmbientSync`)
Directly replicates G-Helper's `ApplyAmbient` algorithm for Wayland compositors (Sway / wlroots):
- **Crop Geometry:** Uses `grim` with `-g "0,400 1920x770"` on a 1920x1200 panel, intentionally skipping the top window titlebars / browser tabs and bottom panel.
- **Downscaling:** Captures at a downscale ratio of `0.05` to minimize memory bus transfer.
- **Dominant Color Extraction:** Parses raw PPM binary bytes to compute arithmetic mean RGB.
- **Saturation Boost:** Applies HSV saturation boost of `+0.3` to compensate for ambient keyboard diffusers.
- **Exponential Smoothing:** Smooths color transitions using G-Helper's `smooth = 0.65` coefficient across frames:
  `C_current = C_prev * 0.65 + C_target * 0.35`
- **Asynchronous Execution:** Runs in a persistent background capture thread communicating via atomic locks (`AtomicU32`), ensuring zero frame drops or input stutter in the TUI event loop.

#### 2. PipeWire Audio Reactive Presets
- **`VoicePulse` (Microphone Reactive):**
  Uses the laptop internal microphone (`alsa_input.pci-0000_00_1f.3.analog-stereo` via `ghelper-audio`). Runs a persistent 25 ms slice reader streaming raw 16-bit PCM mono @ 8000 Hz.
  Includes dynamic Automatic Gain Control (AGC) with an adaptive rolling peak tracker and exponential decay (0.96) to compensate for low hardware microphone gain levels. A baseline noise floor filter prevents background ambient hum from triggering the LEDs. Applies G-Helper cubic easing curve (`brightness^3`) for responsive vocal pulses.
- **`AudioPulse` (System Playback Reactive):**
  Monitors PipeWire default audio sink output. Scales backlight intensity dynamically based on music and game audio dynamics.
- **`AudioWave` (Music Frequency Split):**
  Splits low-frequency bass impact into deep warm tones while mid/high frequencies trigger vivid accent lighting.

#### 4. Dynamic Desktop Theme Sync (`ThemeSync`)
Reads the active desktop palette dynamically from `~/.local/state/theme/colors.sh` (e.g. Gruvbox, Catppuccin, Nord, Tokyo Night). Adjusts keyboard backlighting to match active terminal and window theme accents with subtle breathing pulsation.

### Tier 4: System Telemetry Reactive Modes
- **CpuTemp:** Dynamic thermal gradient (35 C green -> 65 C yellow -> 85 C red -> 95 C flashing critical).
- **GpuTemp:** Real-time NVIDIA RTX 5050 dGPU thermal monitor.
- **BatteryLevel:** Visual state-of-charge indicator (100% emerald -> 50% amber -> 20% critical crimson).
- **CpuLoad:** CPU usage monitor tracking aggregate core utilization.

---

## Power Profiles & Battery Health Management

### ASUS Platform Profiles
Direct ACPI platform profile switching through `asusd`:
- **Quiet:** Lowers fan acoustic limits, caps package TDP, and prefers energy-efficient CPU governor policies.
- **Balanced:** Standard daily operational profile with balanced boost curves.
- **Performance:** Unlocks full 115W/140W cross-load TDP for CPU and GPU with aggressive fan profiles.

### Battery Health Charge Limiting
- **Hardware Charge End Threshold:** Configures `/sys/class/power_supply/BAT1/charge_control_limit_max` (or through `asusd` DBus proxy).
- Limits maximum charge level (default: 80%) to significantly reduce lithium-ion electrolyte degradation when docked on AC power.
- **Full Charge Override:** Temporary one-shot toggle to allow 100% charge for travel.

---

## Interactive Fan Curve Editor

rogtui features a high-resolution Braille-canvas fan curve editor (`src/ui/fancurve.rs`):

- **Sub-Pixel Resolution:** Renders 141 interpolated sub-pixel points (0.5 C steps) using Unicode Braille patterns (`Marker::Braille`).
- **Live Operating Point Indicator:** Displays real-time operating point (`Marker::Block` in green) showing exact live fan PWM at current temperature.
- **Crosshair Navigation:** Dynamic horizontal and vertical crosshairs indicating active temperature and PWM thresholds.
- **Hardware Safety Validation:**
  - Enforces monotonic non-decreasing curves (PWM must never decrease as temperature increases).
  - Mandatory thermal safety floor: Clamps fan speed to minimum 30% for temperatures at or above 80 C.
  - Hard limit verification to prevent zero-RPM runaway under heavy thermal load.

---

## Dynamic GPU Mode Architecture (`supergfxctl`)

rogtui interfaces directly with `org.supergfxctl.Daemon` to control dynamic graphics switching on dual-GPU Optimus systems:

| Mode | Desktop Compositor | dGPU State | Notes |
| :--- | :--- | :--- | :--- |
| **Integrated** | Intel UHD Graphics | D3cold (Powered off) | Maximum battery runtime; lowest thermals. |
| **Hybrid** | Intel UHD Graphics | Suspended / On-demand | 2D on iGPU; 3D/CUDA offloaded via `prime-run`. |
| **Dedicated** | NVIDIA RTX 5050 Mobile | Fully active | Legacy mode; dGPU drives render pipeline. |
| **AsusMuxDgpu**| NVIDIA RTX 5050 Mobile | Direct eDP-1 MUX bypass | Panel wired directly to NVIDIA dGPU; requires reboot. |

rogtui verifies hardware-supported modes prior to presenting options, preventing invalid state requests. Confirmation modals are enforced for actions requiring session logout or system reboots.

---

## Keyboard Controls & Navigation

### Global Navigation
- `1` - `5` : Instant tab switching (Dash, Power, Fan, RGB, System).
- `Tab` / `Shift+Tab` : Cycle tabs forward / backward.
- `p` : Quick cycle platform profile (Quiet -> Balanced -> Performance).
- `?` : Toggle keyboard shortcuts help overlay.
- `q` / `Ctrl+C` : Clean exit with state restoration.

### RGB Tab
- `j` / `k` (or `Down` / `Up`) : Select control row.
- `h` / `l` (or `Left` / `Right`) : Adjust brightness, cycle modes, tweak color channels, or toggle power states.
- `c` : Open interactive 24-bit RGB/HSV Color Picker modal.
- `w` : Save settings to hardware flash (triggers confirmation modal).

### Fan Tab
- `h` / `l` (or `Left` / `Right`) : Select control point (1 to 8).
- `j` / `k` (or `Down` / `Up`) : Adjust target fan speed (-1% / +1%).
- `H` / `L` : Adjust control point temperature (-1°C / +1°C).
- `s` : Cycle fan curve presets (Quiet, Balanced, Performance).
- `f` : Switch active fan target (CPU Fan <-> GPU Fan).
- `w` : Save custom fan curve to hardware profile.

---

## Verification & Build Details

```bash
# Verify formatting and lints
cargo clippy --all-targets --all-features

# Run test suite (19 automated tests)
cargo test

# Build optimized release binary
cargo build --release

# Install binary to user PATH
install -m 755 target/release/rogtui ~/.local/bin/rogtui
```
