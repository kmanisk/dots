#!/usr/bin/env python3
"""
Dusky Audio Studio & Voice DSP — Bleeding-Edge Audio Engine & GTK3 Control Studio
Target Specification: Arch Linux (Kernel 7.1+, Python 3.14.7+, PipeWire 1.6.8+)
Pure bleeding-edge Linux audio architecture with zero legacy shims.

Features:
- RNNoise Recurrent Neural Network Noise Suppression & Hysteresis Gate
- Granular Doppler Pitch Shifter (-24 to +24 semitones)
- 16-Band Formant Filterbank Robot Vocoder with Voice Pitch Tracking & Matrix Timbre Morphing
- Chromatic Autotune & Monotone Pitch Snapping (DECtalk / T-Pain)
- Lo-Fi Vintage Bitcrusher (Bit depth & Sample-and-Hold downsampling)
- Vocal Bandpass Shaping (Telephone, Helmet Resonance, Tinny Radio)
- Rhythmic Stutter Gate Amplitude Chopper (Cylon / Battlestar Galactica)
- Tape Delay & Echo Tank (0 to 1000 ms)
- 4-Comb + 2-Allpass Schroeder Reverb
- 9-Band Studio Parametric Equalizer with Uniform Post-Gain Translation
- Real-Time Hardware Microphone Auto-Discovery (Anti-Loopback / Anti-Deadlock)
- Live Binary Frame Telemetry & GTK3 Meters (VAD %, Noise Reduction dB, Input/Output Level)
- Unified UNIX Domain Socket IPC Server (Non-blocking, multi-client, zero-drop)
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Final
import json
import os
import re
import select
import shutil
import signal
import socket
import struct
import subprocess
import sys
import threading
import time

# --- Constants & Paths ---
APP_ID: Final[str] = "org.dusky.audio-studio"
HOME_DIR: Final[Path] = Path.home()
STATE_DIR: Final[Path] = HOME_DIR / ".config" / "dusky" / "settings" / "dusky_studio"
CACHE_DIR: Final[Path] = HOME_DIR / ".cache" / "dusky_studio"
CONFIG_FILE: Final[Path] = STATE_DIR / "config.json"
SOCK_PATH: Final[Path] = STATE_DIR / "dusky_audio.sock"
PID_FILE: Final[Path] = STATE_DIR / "daemon.pid"
GUI_PID_FILE: Final[Path] = STATE_DIR / "gui.pid"

# Frame Protocol v2 specification
FRAME_SIZE: Final[int] = 2596
MAGIC: Final[int] = 0x47484146  # "GHAF"
PROTOCOL_VERSION: Final[int] = 2
HEADER_STRUCT: Final[struct.Struct] = struct.Struct("<IIIIfffff")  # 36 bytes

# Sandboxed execution environment
COMMAND_ENV: Final[dict[str, str]] = os.environ.copy()
COMMAND_ENV["LC_ALL"] = "C.UTF-8"
COMMAND_ENV["LANG"] = "C.UTF-8"

# Dynamic Material You / Matugen GTK3 CSS Theme
DUSKY_CSS: Final[str] = """
window.panel-window {
    background-color: alpha(@theme_bg_color, 0.96);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 12px;
    box-shadow: 0 12px 32px rgba(0, 0, 0, 0.5);
}

* { outline: none; }
*:focus { outline: none; box-shadow: none; }

.header-title {
    font-size: 16px;
    font-weight: 800;
    letter-spacing: -0.5px;
    color: @theme_fg_color;
}

.header-subtitle-active {
    font-size: 12px;
    font-weight: 600;
    color: @theme_selected_bg_color;
}

.header-subtitle-inactive {
    font-size: 12px;
    font-weight: 500;
    color: alpha(@theme_fg_color, 0.5);
}

.section-label {
    font-size: 12px;
    font-weight: 700;
    color: alpha(@theme_fg_color, 0.9);
}

.value-label {
    font-size: 11px;
    font-weight: 600;
    color: @theme_selected_bg_color;
}

.meter-label {
    font-size: 10px;
    font-weight: 600;
    color: alpha(@theme_fg_color, 0.6);
}

.meter-val {
    font-size: 10px;
    font-weight: 700;
    color: @theme_selected_bg_color;
}

.device-combo {
    background-color: alpha(@theme_base_color, 0.6);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 8px;
    padding: 2px 6px;
    color: @theme_fg_color;
}

.preset-btn {
    border-radius: 8px;
    padding: 4px 10px;
    font-weight: 600;
    font-size: 11px;
    background-color: alpha(@theme_fg_color, 0.06);
    border: 1px solid rgba(255, 255, 255, 0.05);
    color: @theme_fg_color;
    transition: all 150ms ease;
}

.preset-btn:hover {
    background-color: alpha(@theme_selected_bg_color, 0.25);
    color: @theme_selected_bg_color;
}

.preset-btn.active-preset {
    background-color: @theme_selected_bg_color;
    color: @theme_selected_fg_color;
    border-color: @theme_selected_bg_color;
    font-weight: 700;
}

.reset-btn {
    border-radius: 8px;
    padding: 3px 10px;
    font-weight: 600;
    font-size: 11px;
    background-color: alpha(@theme_fg_color, 0.06);
    border: 1px solid rgba(255, 255, 255, 0.06);
    color: alpha(@theme_fg_color, 0.8);
    transition: all 150ms ease;
}

.reset-btn:hover {
    background-color: alpha(@theme_selected_bg_color, 0.22);
    color: @theme_selected_bg_color;
    border-color: alpha(@theme_selected_bg_color, 0.45);
}

.segmented-group {
    background-color: alpha(@theme_fg_color, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 10px;
    padding: 3px;
}

.segmented-btn {
    border-radius: 7px;
    padding: 6px 16px;
    font-weight: 700;
    font-size: 11px;
    background-color: transparent;
    border: 1px solid transparent;
    color: alpha(@theme_fg_color, 0.7);
    transition: all 150ms ease;
}

.segmented-btn:hover {
    background-color: alpha(@theme_selected_bg_color, 0.15);
    color: @theme_selected_bg_color;
}

.segmented-btn.active-preset {
    background-color: @theme_selected_bg_color;
    color: @theme_selected_fg_color;
    border-color: @theme_selected_bg_color;
    font-weight: 800;
}

.preset-chip {
    border-radius: 6px;
    padding: 3px 8px;
    font-weight: 600;
    font-size: 10px;
    background-color: alpha(@theme_fg_color, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.04);
    color: alpha(@theme_fg_color, 0.85);
    transition: all 120ms ease;
}

.preset-chip:hover {
    background-color: alpha(@theme_selected_bg_color, 0.2);
    color: @theme_selected_bg_color;
}

.preset-chip.active-preset {
    background-color: @theme_selected_bg_color;
    color: @theme_selected_fg_color;
    border-color: @theme_selected_bg_color;
    font-weight: 700;
}

notebook header {
    background-color: transparent;
    border-bottom: 1px solid alpha(@theme_fg_color, 0.08);
}

notebook tab {
    padding: 8px 14px;
    font-weight: 700;
    font-size: 12px;
    border-bottom: 2px solid transparent;
    transition: all 150ms ease;
}

notebook tab:checked {
    border-bottom: 2px solid @theme_selected_bg_color;
    color: @theme_selected_bg_color;
    background-color: alpha(@theme_selected_bg_color, 0.06);
}

notebook tab:hover:not(:checked) {
    background-color: alpha(@theme_fg_color, 0.04);
}

scale trough {
    min-height: 5px;
    border-radius: 3px;
    background-color: alpha(@theme_fg_color, 0.12);
}

scale highlight {
    border-radius: 3px;
    background-color: @theme_selected_bg_color;
}

scale slider {
    min-width: 14px;
    min-height: 14px;
    border-radius: 7px;
    background-color: @theme_selected_bg_color;
}

progressbar trough {
    min-height: 8px;
    border-radius: 4px;
    background-color: alpha(@theme_fg_color, 0.10);
    border: none;
}

progressbar progress {
    border-radius: 4px;
    background-color: @theme_selected_bg_color;
}

switch image,
switch image.on,
switch image.off,
switch image:first-child,
switch image:last-child {
    -gtk-icon-source: none;
    -gtk-icon-transform: scale(0);
    opacity: 0;
    min-width: 0px;
    min-height: 0px;
    margin: 0px;
    padding: 0px;
    color: transparent;
}

switch,
switch:checked,
switch:not(:checked),
switch:hover,
switch:hover:not(:checked),
switch:checked:hover,
switch:checked:hover:active,
switch:checked:active,
switch:checked:disabled,
switch:disabled,
switch:focus,
switch.compact-switch,
switch.compact-switch:checked,
switch.compact-switch:not(:checked),
switch.compact-switch:hover,
switch.compact-switch:active,
switch.compact-switch:disabled {
    color: transparent;
    font-size: 0px;
    text-shadow: none;
    -gtk-icon-source: none;
    -gtk-icon-shadow: none;
    background-image: none;
    outline: none;
    box-shadow: none;
}

switch label,
switch * {
    color: transparent;
    font-size: 0px;
    text-shadow: none;
    -gtk-icon-source: none;
    -gtk-icon-shadow: none;
    background-image: none;
    opacity: 0;
    min-width: 0px;
    min-height: 0px;
    margin: 0px;
    padding: 0px;
}

switch.compact-switch {
    min-width: 44px;
    min-height: 24px;
    border-radius: 12px;
    background-color: alpha(@theme_fg_color, 0.18);
    border: none;
    box-shadow: none;
    outline: none;
    color: transparent;
}

switch.compact-switch:checked {
    background-color: @theme_selected_bg_color;
    border: none;
    box-shadow: none;
    color: transparent;
}

switch.compact-switch slider {
    min-width: 18px;
    min-height: 18px;
    border-radius: 9px;
    border: none;
    box-shadow: none;
    outline: none;
    margin: 3px;
    background-color: @theme_bg_color;
}

switch.compact-switch:checked slider {
    background-color: @theme_base_color;
}

.footer-info {
    font-size: 11px;
    font-weight: 500;
    color: alpha(@theme_fg_color, 0.4);
}

.warning-banner {
    background-color: alpha(@theme_selected_bg_color, 0.12);
    border: 1px solid alpha(@theme_selected_bg_color, 0.35);
    border-radius: 8px;
    padding: 8px 12px;
}

.warning-text {
    font-size: 12px;
    font-weight: 600;
    color: @theme_selected_bg_color;
}

.telemetry-card {
    background-color: alpha(@theme_base_color, 0.4);
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 8px;
    padding: 8px 10px;
}
"""


@dataclass(slots=True, kw_only=True)
class AudioConfig:
    # Master (Disabled by default, opt-in only)
    enabled: bool = False
    source: str = "default"
    sink: str = "default"
    volume: int = 100  # 0..200%
    monitor: bool = False

    # Saved Physical Hardware Defaults for Seamless Restore on Disable/Reboot
    pre_source: str = ""
    pre_sink: str = ""

    # Noise Suppression - Input / Microphone (Enabled by default on fresh install)
    rnnoise_on: bool = True
    aggressiveness: int = 100  # 0..100%

    # Noise Suppression - Output / Speaker & Headphone (Two-Way, OFF by default)
    out_rnnoise_on: bool = False
    out_aggressiveness: int = 70  # 0..100%

    # Vocoder & Voice Character Stack
    vocoder_on: bool = False
    vocoder_mix: int = 0  # 0..100%
    vocoder_carrier_hz: int = 110  # 50..440 Hz
    vocoder_attack_ms: int = 5  # 1..100 ms
    vocoder_release_ms: int = 30  # 5..500 ms
    vocoder_detune: int = 20  # 0..200 per-mille
    vocoder_follow: bool = True
    vocoder_pitch_shift: int = 0  # -24..+24 semitones
    vocoder_matrix: int = 0  # 0..100%

    # Pitch & Modulation
    pitch_shift: int = 0  # -2400..+2400 centisemitones (-24..+24 st)
    autotune_on: bool = False
    autotune_target_hz: int = 0  # 0=chromatic snap, >0=monotone target
    bitcrush_bits: int = 0  # 0=bypass, 1..15
    bitcrush_downsample: int = 1  # 1..64
    bandpass_hpf_hz: int = 0  # 0..2000 Hz
    bandpass_lpf_hz: int = 0  # 0..20000 Hz
    stutter_hz: int = 0  # 0..40 Hz

    # Delay / Echo
    delay_on: bool = False
    delay_ms: int = 250  # 10..1000 ms
    delay_feedback: int = 35  # 0..95%
    delay_mix: int = 30  # 0..100%

    # Reverb
    reverb_on: bool = False
    reverb_room: int = 70  # 0..100%
    reverb_damp: int = 50  # 0..100%
    reverb_width: int = 80  # 0..100%
    reverb_mix: int = 35  # 0..100%

    # Microphone 9-Band EQ gains (-1200..+1200 centi-dB -> -12dB..+12dB)
    eq_on: bool = False
    eq_post_gain: int = 0  # -3600..+3600 centi-dB (±36 dB line translation)
    eq_gains: list[int] = field(
        default_factory=lambda: [0, 0, 0, 0, 0, 0, 0, 0, 0]
    )

    # Playback / Output 9-Band Stereo EQ gains
    out_eq_on: bool = False
    out_eq_post_gain: int = 0  # -3600..+3600 centi-dB
    out_eq_gains: list[int] = field(
        default_factory=lambda: [0, 0, 0, 0, 0, 0, 0, 0, 0]
    )

    # Playback / Output Vocoder & Carrier
    out_vocoder_on: bool = False
    out_vocoder_mix: int = 70  # 0..100%
    out_vocoder_carrier_hz: int = 110  # 50..880 Hz
    out_vocoder_attack_ms: int = 5  # 1..100 ms
    out_vocoder_release_ms: int = 30  # 5..500 ms
    out_vocoder_detune: int = 20  # 0..200 per-mille
    out_vocoder_follow: bool = True
    out_vocoder_pitch_shift: int = 0  # -24..+24 semitones
    out_vocoder_matrix: int = 0  # 0..100%

    # Playback / Output Pitch & Modulation
    out_pitch_shift: int = 0  # -2400..+2400 centisemitones
    out_autotune_on: bool = False
    out_autotune_target_hz: int = 0
    out_bitcrush_bits: int = 0
    out_bitcrush_downsample: int = 1
    out_bandpass_hpf_hz: int = 0
    out_bandpass_lpf_hz: int = 0
    out_stutter_hz: int = 0

    # Playback / Output Delay & Reverb
    out_delay_on: bool = False
    out_delay_ms: int = 250
    out_delay_feedback: int = 35
    out_delay_mix: int = 30
    out_reverb_on: bool = False
    out_reverb_room: int = 70
    out_reverb_damp: int = 50
    out_reverb_width: int = 80
    out_reverb_mix: int = 35


@dataclass(slots=True)
class AudioTelemetry:
    seq: int = 0
    flags: int = 0
    vad_prob: float = 0.0
    rms_in_db: float = -80.0
    rms_out_db: float = -80.0
    noise_reduction_db: float = 0.0
    tracked_pitch_hz: float = 0.0


# Microphone / Input Equalizer Presets
INPUT_EQ_PRESETS: Final[dict[str, dict[str, Any]]] = {
    "Flat (0 dB)": {
        "post_gain": 0,
        "gains": [0, 0, 0, 0, 0, 0, 0, 0, 0],
    },
    "Broadcast Warmth": {
        "post_gain": 0,
        "gains": [0, 300, 0, -200, 0, 300, 0, 200, 0],
    },
    "Vocal Presence": {
        "post_gain": 0,
        "gains": [-300, 0, 0, -100, 200, 400, 300, 200, 100],
    },
    "Crisp & Clean": {
        "post_gain": 0,
        "gains": [-600, -200, -100, -200, 100, 300, 400, 500, 300],
    },
}


# Output / Playback Equalizer Presets
OUTPUT_EQ_PRESETS: Final[dict[str, dict[str, Any]]] = {
    "Flat (0 dB)": {
        "post_gain": 0,
        "gains": [0, 0, 0, 0, 0, 0, 0, 0, 0],
    },
    "Bass Boost": {
        "post_gain": 0,
        "gains": [600, 500, 300, 100, 0, 0, 0, 0, 0],
    },
    "V-Shape (Loudness)": {
        "post_gain": 0,
        "gains": [500, 400, 200, -100, -200, 100, 300, 400, 500],
    },
    "Vocal Clarity": {
        "post_gain": 0,
        "gains": [-300, -100, 0, 100, 400, 500, 300, 100, 0],
    },
    "Treble Boost": {
        "post_gain": 0,
        "gains": [-200, -100, 0, 0, 100, 300, 500, 600, 600],
    },
    "Gaming (Footsteps)": {
        "post_gain": 0,
        "gains": [-400, -200, 100, 200, 300, 600, 500, 200, -100],
    },
}


# Comprehensive Voice Presets Palette (Aligned with C# Ground Truth)
PRESETS: Final[dict[str, dict[str, Any]]] = {
    "Natural Clean": {
        "vocoder_on": False,
        "vocoder_mix": 0,
        "pitch_shift": 0,
        "autotune_on": False,
        "autotune_target_hz": 0,
        "bitcrush_bits": 0,
        "bitcrush_downsample": 1,
        "bandpass_hpf_hz": 0,
        "bandpass_lpf_hz": 0,
        "stutter_hz": 0,
        "vocoder_matrix": 0,
    },
    "Daft Punk": {
        "vocoder_on": True,
        "vocoder_mix": 90,
        "vocoder_carrier_hz": 110,
        "vocoder_detune": 50,
        "vocoder_attack_ms": 2,
        "vocoder_release_ms": 12,
        "vocoder_follow": True,
        "vocoder_pitch_shift": 0,
        "pitch_shift": 0,
        "autotune_on": False,
        "autotune_target_hz": 0,
        "bitcrush_bits": 0,
        "bitcrush_downsample": 1,
        "bandpass_hpf_hz": 0,
        "bandpass_lpf_hz": 0,
        "stutter_hz": 0,
        "vocoder_matrix": 15,
    },
    "Darth Vader": {
        "vocoder_on": True,       # Keeps C voice-effects pipeline active
        "vocoder_mix": 0,          # 0% vocoder synth carrier = passes dry pitch-shifted voice
        "vocoder_carrier_hz": 110,
        "vocoder_detune": 0,
        "vocoder_attack_ms": 5,
        "vocoder_release_ms": 30,
        "vocoder_follow": False,
        "vocoder_pitch_shift": 0,
        "pitch_shift": -500,       # -5 semitones down
        "autotune_on": False,
        "autotune_target_hz": 0,
        "bitcrush_bits": 0,
        "bitcrush_downsample": 1,
        "bandpass_hpf_hz": 80,     # Low-cut handling rumble
        "bandpass_lpf_hz": 2500,   # Helmet resonant acoustic muffle
        "stutter_hz": 0,
        "vocoder_matrix": 0,
    },
    "Chipmunk": {
        "vocoder_on": True,
        "vocoder_mix": 0,
        "vocoder_carrier_hz": 110,
        "vocoder_detune": 0,
        "vocoder_attack_ms": 2,
        "vocoder_release_ms": 15,
        "vocoder_follow": False,
        "vocoder_pitch_shift": 0,
        "pitch_shift": 1200,       # +12 semitones (1 full octave up)
        "autotune_on": False,
        "autotune_target_hz": 0,
        "bitcrush_bits": 0,
        "bitcrush_downsample": 1,
        "bandpass_hpf_hz": 150,
        "bandpass_lpf_hz": 0,
        "stutter_hz": 0,
        "vocoder_matrix": 0,
    },
    "Cylon Robot": {
        "vocoder_on": True,
        "vocoder_mix": 90,
        "vocoder_carrier_hz": 90,
        "vocoder_detune": 160,
        "vocoder_attack_ms": 10,
        "vocoder_release_ms": 70,
        "vocoder_follow": False,
        "vocoder_pitch_shift": 0,
        "pitch_shift": 0,
        "autotune_on": False,
        "autotune_target_hz": 0,
        "bitcrush_bits": 0,
        "bitcrush_downsample": 1,
        "bandpass_hpf_hz": 0,
        "bandpass_lpf_hz": 0,
        "stutter_hz": 6,           # 6 Hz rhythmic "By Your Command" chopping
        "vocoder_matrix": 45,
    },
    "Kraftwerk": {
        "vocoder_on": True,
        "vocoder_mix": 95,
        "vocoder_carrier_hz": 140,
        "vocoder_detune": 10,
        "vocoder_attack_ms": 3,
        "vocoder_release_ms": 15,
        "vocoder_follow": False,
        "vocoder_pitch_shift": 0,
        "pitch_shift": 0,
        "autotune_on": False,
        "autotune_target_hz": 0,
        "bitcrush_bits": 0,
        "bitcrush_downsample": 1,
        "bandpass_hpf_hz": 0,
        "bandpass_lpf_hz": 0,
        "stutter_hz": 0,
        "vocoder_matrix": 0,       # Clean pure-analog saw+square
    },
    "Matrix Agent": {
        "vocoder_on": True,
        "vocoder_mix": 90,
        "vocoder_carrier_hz": 70,
        "vocoder_detune": 90,
        "vocoder_attack_ms": 10,
        "vocoder_release_ms": 55,
        "vocoder_follow": False,
        "vocoder_pitch_shift": 0,
        "pitch_shift": -200,       # -2 semitones
        "autotune_on": False,
        "autotune_target_hz": 0,
        "bitcrush_bits": 0,
        "bitcrush_downsample": 1,
        "bandpass_hpf_hz": 300,
        "bandpass_lpf_hz": 3400,
        "stutter_hz": 0,
        "vocoder_matrix": 100,     # Full Sentinel 35 Hz ring mod + drive
    },
    "Robot Phone": {
        "vocoder_on": True,
        "vocoder_mix": 0,
        "vocoder_carrier_hz": 110,
        "vocoder_detune": 0,
        "vocoder_attack_ms": 5,
        "vocoder_release_ms": 25,
        "vocoder_follow": False,
        "vocoder_pitch_shift": 0,
        "pitch_shift": 0,
        "autotune_on": False,
        "autotune_target_hz": 0,
        "bitcrush_bits": 8,        # 8-bit staircase quantisation
        "bitcrush_downsample": 2,  # 2x sample-and-hold
        "bandpass_hpf_hz": 300,    # 300-3400 Hz standard telephone band
        "bandpass_lpf_hz": 3400,
        "stutter_hz": 0,
        "vocoder_matrix": 0,
    },
    "Sci-Fi Alien": {
        "vocoder_on": True,
        "vocoder_mix": 50,
        "vocoder_carrier_hz": 110,
        "vocoder_detune": 130,
        "vocoder_attack_ms": 2,
        "vocoder_release_ms": 10,
        "vocoder_follow": False,
        "vocoder_pitch_shift": 0,
        "pitch_shift": 700,        # +7 semitones (perfect fifth)
        "autotune_on": False,
        "autotune_target_hz": 0,
        "bitcrush_bits": 0,
        "bitcrush_downsample": 1,
        "bandpass_hpf_hz": 700,
        "bandpass_lpf_hz": 3200,
        "stutter_hz": 0,
        "vocoder_matrix": 70,
    },
    "T-Pain Autotune": {
        "vocoder_on": True,
        "vocoder_mix": 0,
        "vocoder_carrier_hz": 110,
        "vocoder_detune": 0,
        "vocoder_attack_ms": 5,
        "vocoder_release_ms": 30,
        "vocoder_follow": False,
        "vocoder_pitch_shift": 0,
        "pitch_shift": 0,
        "autotune_on": True,       # Chromatic snap
        "autotune_target_hz": 0,   # 0 = chromatic equal temperament
        "bitcrush_bits": 0,
        "bitcrush_downsample": 1,
        "bandpass_hpf_hz": 0,
        "bandpass_lpf_hz": 0,
        "stutter_hz": 0,
        "vocoder_matrix": 0,
    },
    "Stephen Hawking": {
        "vocoder_on": True,
        "vocoder_mix": 0,
        "vocoder_carrier_hz": 110,
        "vocoder_detune": 0,
        "vocoder_attack_ms": 5,
        "vocoder_release_ms": 30,
        "vocoder_follow": False,
        "vocoder_pitch_shift": 0,
        "pitch_shift": 0,
        "autotune_on": True,       # Monotone snap
        "autotune_target_hz": 120, # Fixed 120 Hz monotone synth
        "bitcrush_bits": 0,
        "bitcrush_downsample": 1,
        "bandpass_hpf_hz": 0,
        "bandpass_lpf_hz": 0,
        "stutter_hz": 0,
        "vocoder_matrix": 0,
    },
    "Megatron": {
        "vocoder_on": True,
        "vocoder_mix": 65,
        "vocoder_carrier_hz": 80,
        "vocoder_detune": 80,
        "vocoder_attack_ms": 4,
        "vocoder_release_ms": 40,
        "vocoder_follow": False,
        "vocoder_pitch_shift": 0,
        "pitch_shift": -700,        # -7 semitones (deep metallic robotic growl)
        "autotune_on": False,
        "autotune_target_hz": 0,
        "bitcrush_bits": 0,
        "bitcrush_downsample": 1,
        "bandpass_hpf_hz": 90,      # Low-cut handling sub-rumble
        "bandpass_lpf_hz": 4000,    # Resonant metallic presence
        "stutter_hz": 0,
        "vocoder_matrix": 65,       # 65% metallic ring modulation + tanh saturation
    },
}


def find_helper_binary() -> Path | None:
    script_dir = Path(__file__).resolve().parent
    local_bin = script_dir / "audio-helper" / "dusky_audio_dsp"
    if local_bin.is_file() and os.access(local_bin, os.X_OK):
        return local_bin

    # Auto-compile on the fly if local source Makefile exists
    helper_dir = script_dir / "audio-helper"
    if (helper_dir / "Makefile").is_file():
        try:
            subprocess.run(["make", "-C", str(helper_dir)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if local_bin.is_file() and os.access(local_bin, os.X_OK):
                return local_bin
        except Exception:
            pass

    candidates: list[Path] = [
        script_dir / "audio-helper" / "ghelper-audio",
        CACHE_DIR / "dusky_audio_dsp",
        STATE_DIR / "dusky_audio_dsp",
        HOME_DIR / ".cache" / "ghelper" / "libs" / "ghelper-audio",
        HOME_DIR / "Documents" / "ghelper" / "audio-helper" / "ghelper-audio",
        HOME_DIR / "Documents" / "ghelper" / "build" / "embedded" / "ghelper-audio",
        HOME_DIR / ".local" / "bin" / "dusky_audio_dsp",
        Path("/usr/local/bin/dusky_audio_dsp"),
        Path("/usr/bin/dusky_audio_dsp"),
    ]
    for c in candidates:
        if c.is_file() and os.access(c, os.X_OK):
            return c

    return None


def send_desktop_notification(
    title: str, message: str, urgency: str = "normal"
) -> None:
    try:
        subprocess.run(
            [
                "notify-send",
                "-a",
                "Dusky Audio Studio",
                "-u",
                urgency,
                "-i",
                "audio-volume-high",
                title,
                message,
            ],
            stderr=subprocess.DEVNULL,
            env=COMMAND_ENV,
        )
    except Exception:
        pass


def check_system_dependencies() -> list[str]:
    missing: list[str] = []
    missing_pkgs: list[str] = []

    if not shutil.which("pw-cli") or not shutil.which("wpctl"):
        missing_pkgs.extend(["pipewire", "wireplumber"])

    bin_path = find_helper_binary()
    if not bin_path:
        if not shutil.which("gcc") and not shutil.which("clang") and not shutil.which("cc"):
            missing_pkgs.append("gcc")
        if not shutil.which("make"):
            missing_pkgs.append("make")
        try:
            res = subprocess.run(["pkg-config", "--exists", "rnnoise"], capture_output=True)
            if res.returncode != 0:
                missing_pkgs.append("rnnoise")
        except Exception:
            pass

        unique_pkgs = list(dict.fromkeys(missing_pkgs))
        if unique_pkgs:
            missing.append(f"Install required packages: sudo pacman -S {' '.join(unique_pkgs)}")
        else:
            missing.append("Native Audio DSP engine failed to compile (~/user_scripts/audio/dusky_audio_studio/audio-helper)")
    elif missing_pkgs:
        unique_pkgs = list(dict.fromkeys(missing_pkgs))
        missing.append(f"Install required packages: sudo pacman -S {' '.join(unique_pkgs)}")

    return missing


def load_config() -> AudioConfig:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                cfg = AudioConfig()
                for k, v in data.items():
                    if hasattr(cfg, k):
                        setattr(cfg, k, v)
                return cfg
        except Exception:
            pass

    old_config = HOME_DIR / ".config" / "dusky_audio_studio" / "config.json"
    if old_config.exists():
        try:
            with open(old_config, "r", encoding="utf-8") as f:
                data = json.load(f)
                cfg = AudioConfig()
                for k, v in data.items():
                    if hasattr(cfg, k):
                        setattr(cfg, k, v)
                save_config(cfg)
                return cfg
        except Exception:
            pass

    return AudioConfig()


def save_config(cfg: AudioConfig) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    # PID-unique temp name: the GUI and CLI tools can save concurrently, and
    # a shared temp path would let their writes interleave before the rename.
    tmp = CONFIG_FILE.with_name(f"{CONFIG_FILE.name}.{os.getpid()}.tmp")
    try:
        # Write to a sibling temp file and atomically rename so a crash or
        # power loss mid-write can never leave a truncated config.json behind.
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(asdict(cfg), f, indent=2)
        tmp.replace(CONFIG_FILE)
    except Exception:
        try:
            tmp.unlink(missing_ok=True)
        except Exception:
            pass


def pid_is_dusky_audio(pid: int) -> bool:
    """True only if /proc/<pid>/cmdline belongs to this application.

    PID files can outlive their process; once the kernel recycles the PID it
    may belong to any unrelated program. Every consumer of PID_FILE /
    GUI_PID_FILE verifies ownership through here before signalling, so a
    stale file can never get an innocent process killed."""
    try:
        raw = Path(f"/proc/{pid}/cmdline").read_bytes()
    except OSError:
        return False
    return b"dusky_audio_studio" in raw


def get_daemon_pid() -> int | None:
    if PID_FILE.exists():
        try:
            with open(PID_FILE, "r", encoding="utf-8") as f:
                pid = int(f.read().strip())
            os.kill(pid, 0)
            if not pid_is_dusky_audio(pid):
                raise ValueError("pid recycled by another process")
            return pid
        except (OSError, ValueError):
            PID_FILE.unlink(missing_ok=True)
    return None


def enumerate_sources() -> list[tuple[str, str]]:
    """Enumerate physical audio input sources, filtering out all virtual/monitor nodes."""
    sources: list[tuple[str, str]] = [("default", "Default System Microphone (Auto-Detected)")]
    seen_names: set[str] = {"default"}
    try:
        out = subprocess.check_output(
            ["pw-cli", "ls", "Node"],
            text=True,
            stderr=subprocess.DEVNULL,
            env=COMMAND_ENV,
        )
        blocks = out.split("\tid ")
        for b in blocks:
            if 'media.class = "Audio/Source"' in b:
                name_m = re.search(r'node\.name = "([^"]+)"', b)
                desc_m = re.search(r'node\.description = "([^"]+)"', b)
                name = name_m.group(1) if name_m else None
                desc = desc_m.group(1) if desc_m else None

                if not name:
                    continue

                lower_name = name.lower()
                lower_desc = (desc or "").lower()
                # Strictly filter out self-nodes and loopback monitors
                if (
                    lower_name.startswith(("ghelper", "dusky", "rnnoise"))
                    or "noise suppressed" in lower_desc
                    or "audio monitor" in lower_desc
                    or "audio capture" in lower_desc
                    or lower_name.endswith(".monitor")
                    or "loopback" in lower_name
                ):
                    continue

                if name not in seen_names:
                    seen_names.add(name)
                    sources.append((name, desc or name))
    except Exception:
        pass
    return sources


def enumerate_sinks() -> list[tuple[str, str]]:
    """Enumerate physical audio output sinks, filtering out virtual/loopback nodes."""
    sinks: list[tuple[str, str]] = [("default", "Default System Output (Auto-Detected)")]
    seen_names: set[str] = {"default"}
    try:
        out = subprocess.check_output(
            ["pw-cli", "ls", "Node"],
            text=True,
            stderr=subprocess.DEVNULL,
            env=COMMAND_ENV,
        )
        blocks = out.split("\tid ")
        for b in blocks:
            if 'media.class = "Audio/Sink"' in b:
                name_m = re.search(r'node\.name = "([^"]+)"', b)
                desc_m = re.search(r'node\.description = "([^"]+)"', b)
                name = name_m.group(1) if name_m else None
                desc = desc_m.group(1) if desc_m else None

                if not name:
                    continue

                lower_name = name.lower()
                lower_desc = (desc or "").lower()
                # Filter out our own virtual sink and loopback nodes
                if (
                    lower_name.startswith(("ghelper", "dusky", "rnnoise"))
                    or "clean output" in lower_desc
                    or "loopback" in lower_name
                    or lower_name.endswith(".monitor")
                ):
                    continue

                if name not in seen_names:
                    seen_names.add(name)
                    sinks.append((name, desc or name))
    except Exception:
        pass
    return sinks


def is_node_alive(node_name: str, media_class: str) -> bool:
    """Checks if a given PipeWire node is actively connected and alive."""
    if not node_name or node_name == "default" or not shutil.which("pw-dump"):
        return False
    try:
        out = subprocess.check_output(["pw-dump", "Node"], text=True, stderr=subprocess.DEVNULL, env=COMMAND_ENV)
        for obj in json.loads(out):
            props = obj.get("info", {}).get("props", {})
            if props.get("media.class") == media_class:
                if props.get("node.name") == node_name or props.get("node.description") == node_name:
                    return True
    except Exception:
        pass
    return False


def resolve_hardware_source(requested: str = "default", fallback_node: str = "") -> str:
    """
    Resolves the physical microphone node name to prevent WirePlumber feedback loops.
    If 'default' is requested, dynamically queries the active physical microphone hardware node.
    """
    if requested != "default" and requested.strip():
        return requested.strip()

    # Priority 1: Check provided fallback_node (e.g. pre_source) if it is actively connected
    if fallback_node and fallback_node != "default" and is_node_alive(fallback_node, "Audio/Source"):
        return fallback_node

    # Priority 2: Try to query the active default source from native WirePlumber metadata
    if shutil.which("pw-dump"):
        try:
            out = subprocess.check_output(["pw-dump", "Metadata"], text=True, stderr=subprocess.DEVNULL, env=COMMAND_ENV)
            metas = json.loads(out)
            for m_obj in metas:
                if m_obj.get("props", {}).get("metadata.name") == "default":
                    for item in m_obj.get("metadata", []):
                        if item.get("key") in ("default.audio.source", "default.configured.audio.source"):
                            val = item.get("value")
                            v_str = val.get("name") if isinstance(val, dict) else (val if isinstance(val, str) else None)
                            if v_str and not any(v_str.lower().startswith(x) for x in ("ghelper", "dusky", "rnnoise")):
                                return v_str
        except Exception:
            pass

    # Priority 3: Fallback to querying active default source from wpctl status
    try:
        out = subprocess.check_output(["wpctl", "status"], text=True, stderr=subprocess.DEVNULL, env=COMMAND_ENV)
        in_sources = False
        default_id: str | None = None
        for line in out.splitlines():
            if "Sources:" in line:
                in_sources = True
                continue
            if in_sources:
                if line.strip().startswith(("├─", "└─", "Filters:", "Streams:")):
                    break
                m = re.search(r"\*\s+(\d+)\.", line)
                if m:
                    default_id = m.group(1)
                    break
        if default_id:
            info = subprocess.check_output(["pw-cli", "info", default_id], text=True, stderr=subprocess.DEVNULL, env=COMMAND_ENV)
            name_m = re.search(r'node\.name = "([^"]+)"', info)
            if name_m:
                node_name = name_m.group(1)
                lower = node_name.lower()
                if not lower.startswith(("ghelper", "dusky", "rnnoise")) and not lower.endswith(".monitor") and "loopback" not in lower:
                    return node_name
    except Exception:
        pass

    # Priority 4: Check persisted config pre_source
    try:
        persisted = load_config()
        if persisted.pre_source and persisted.pre_source != "default" and is_node_alive(persisted.pre_source, "Audio/Source"):
            return persisted.pre_source
    except Exception:
        pass

    # Priority 5: Fallback to first non-virtual source in enumerated sources
    sources = enumerate_sources()
    for node, _ in sources:
        if node != "default" and not node.startswith(("ghelper", "dusky")):
            return node
    return "default"


def resolve_hardware_sink(requested: str = "default", fallback_node: str = "") -> str:
    """
    Resolves the physical speaker/headphone node name to prevent WirePlumber feedback loops.
    If 'default' is requested, dynamically queries the active physical playback hardware node.
    """
    if requested != "default" and requested.strip():
        return requested.strip()

    # Priority 1: Check provided fallback_node (e.g. pre_sink) if it is actively connected
    if fallback_node and fallback_node != "default" and is_node_alive(fallback_node, "Audio/Sink"):
        return fallback_node

    # Priority 2: Try to query the active default sink from native WirePlumber metadata
    if shutil.which("pw-dump"):
        try:
            out = subprocess.check_output(["pw-dump", "Metadata"], text=True, stderr=subprocess.DEVNULL, env=COMMAND_ENV)
            metas = json.loads(out)
            for m_obj in metas:
                if m_obj.get("props", {}).get("metadata.name") == "default":
                    for item in m_obj.get("metadata", []):
                        if item.get("key") in ("default.audio.sink", "default.configured.audio.sink"):
                            val = item.get("value")
                            v_str = val.get("name") if isinstance(val, dict) else (val if isinstance(val, str) else None)
                            if v_str and not any(v_str.lower().startswith(x) for x in ("ghelper", "dusky", "rnnoise")):
                                return v_str
        except Exception:
            pass

    # Priority 3: Fallback to querying active default sink from wpctl status
    try:
        out = subprocess.check_output(["wpctl", "status"], text=True, stderr=subprocess.DEVNULL, env=COMMAND_ENV)
        in_sinks = False
        default_id: str | None = None
        for line in out.splitlines():
            if "Sinks:" in line:
                in_sinks = True
                continue
            if in_sinks:
                if line.strip().startswith(("├─", "└─", "Sources:", "Filters:", "Streams:")):
                    break
                m = re.search(r"\*\s+(\d+)\.", line)
                if m:
                    default_id = m.group(1)
                    break
        if default_id:
            info = subprocess.check_output(["pw-cli", "info", default_id], text=True, stderr=subprocess.DEVNULL, env=COMMAND_ENV)
            name_m = re.search(r'node\.name = "([^"]+)"', info)
            if name_m:
                node_name = name_m.group(1)
                lower = node_name.lower()
                if (
                    not lower.startswith(("ghelper", "dusky", "rnnoise"))
                    and not lower.endswith(".monitor")
                    and "loopback" not in lower
                    and "clean output" not in lower
                ):
                    return node_name
    except Exception:
        pass

    # Priority 4: Check persisted config pre_sink
    try:
        persisted = load_config()
        if persisted.pre_sink and persisted.pre_sink != "default" and is_node_alive(persisted.pre_sink, "Audio/Sink"):
            return persisted.pre_sink
    except Exception:
        pass

    # Priority 5: Fallback to first non-virtual sink in enumerated sinks
    sinks = enumerate_sinks()
    for node, _ in sinks:
        if node != "default" and not node.startswith(("ghelper", "dusky")):
            return node
    return "default"


def save_previous_default_devices(cfg: AudioConfig) -> None:
    """
    Captures the current active physical hardware default source and sink before
    enabling Dusky virtual nodes, so they can be seamlessly restored on disable or reboot.
    Utilizes multi-layer detection (PipeWire Metadata -> wpctl status -> hardware enumeration).
    """
    if not shutil.which("wpctl"):
        return

    src_name: str | None = None
    snk_name: str | None = None

    # Layer 1: Query native WirePlumber default metadata
    if shutil.which("pw-dump"):
        try:
            out = subprocess.check_output(["pw-dump", "Metadata"], text=True, stderr=subprocess.DEVNULL, env=COMMAND_ENV)
            metas = json.loads(out)
            for m_obj in metas:
                if m_obj.get("props", {}).get("metadata.name") == "default":
                    for item in m_obj.get("metadata", []):
                        k = item.get("key")
                        val = item.get("value")
                        val_str = val.get("name") if isinstance(val, dict) else (val if isinstance(val, str) else None)
                        if not val_str or any(val_str.lower().startswith(x) for x in ("ghelper", "dusky", "rnnoise")):
                            continue
                        if k in ("default.audio.sink", "default.configured.audio.sink") and not snk_name:
                            snk_name = val_str
                        elif k in ("default.audio.source", "default.configured.audio.source") and not src_name:
                            src_name = val_str
        except Exception:
            pass

    # Layer 2: Fallback to wpctl status parsing
    if not src_name or not snk_name:
        try:
            out = subprocess.check_output(["wpctl", "status"], text=True, stderr=subprocess.DEVNULL, env=COMMAND_ENV)
            in_audio = False
            in_sinks = False
            in_sources = False
            src_id: int | None = None
            snk_id: int | None = None

            for line in out.splitlines():
                if line.strip() == "Audio":
                    in_audio = True
                    continue
                if in_audio:
                    if line.strip().startswith(("Video", "Settings")):
                        break
                    if "Sinks:" in line:
                        in_sinks = True
                        in_sources = False
                        continue
                    elif "Sources:" in line:
                        in_sources = True
                        in_sinks = False
                        continue
                    elif line.strip().startswith(("Filters:", "Streams:", "Devices:")):
                        in_sinks = False
                        in_sources = False
                        continue

                    if in_sinks and snk_id is None:
                        m = re.search(r"\*\s+(\d+)\.", line)
                        if m:
                            snk_id = int(m.group(1))
                    elif in_sources and src_id is None:
                        m = re.search(r"\*\s+(\d+)\.", line)
                        if m:
                            src_id = int(m.group(1))

            if src_id is not None and not src_name:
                info = subprocess.check_output(["pw-cli", "info", str(src_id)], text=True, stderr=subprocess.DEVNULL, env=COMMAND_ENV)
                name_m = re.search(r'node\.name = "([^"]+)"', info)
                if name_m:
                    n_str = name_m.group(1)
                    if not any(n_str.lower().startswith(x) for x in ("ghelper", "dusky", "rnnoise")):
                        src_name = n_str

            if snk_id is not None and not snk_name:
                info = subprocess.check_output(["pw-cli", "info", str(snk_id)], text=True, stderr=subprocess.DEVNULL, env=COMMAND_ENV)
                name_m = re.search(r'node\.name = "([^"]+)"', info)
                if name_m:
                    n_str = name_m.group(1)
                    if not any(n_str.lower().startswith(x) for x in ("ghelper", "dusky", "rnnoise")):
                        snk_name = n_str
        except Exception:
            pass

    # Layer 3: Fallback to physical hardware enumeration
    if not src_name:
        src_name = resolve_hardware_source()
    if not snk_name:
        snk_name = resolve_hardware_sink()

    if src_name and not any(src_name.lower().startswith(x) for x in ("ghelper", "dusky", "rnnoise")):
        cfg.pre_source = src_name
    if snk_name and not any(snk_name.lower().startswith(x) for x in ("ghelper", "dusky", "rnnoise")):
        cfg.pre_sink = snk_name

    save_config(cfg)


def restore_previous_default_devices(cfg: AudioConfig | None = None) -> None:
    """
    Restores the previously active physical default source and sink when Dusky Audio is toggled off.
    Falls back to the first available non-virtual hardware device if previous device is disconnected.
    """
    if not shutil.which("wpctl"):
        return

    if cfg is None:
        cfg = load_config()

    target_source = cfg.pre_source if (cfg.pre_source and cfg.pre_source != "default") else resolve_hardware_source()
    target_sink = cfg.pre_sink if (cfg.pre_sink and cfg.pre_sink != "default") else resolve_hardware_sink()

    src_id: int | None = None
    snk_id: int | None = None

    if shutil.which("pw-dump"):
        try:
            out = subprocess.check_output(["pw-dump", "Node"], text=True, stderr=subprocess.DEVNULL, env=COMMAND_ENV)
            nodes = json.loads(out)
            for obj in nodes:
                props = obj.get("info", {}).get("props", {})
                media_class = props.get("media.class", "")
                name = props.get("node.name", "")
                desc = props.get("node.description", "")
                nick = props.get("node.nick", "")

                if media_class == "Audio/Source" and src_id is None:
                    if target_source in (name, desc, nick) or target_source.lower() in (name.lower(), desc.lower()):
                        src_id = obj.get("id")
                elif media_class == "Audio/Sink" and snk_id is None:
                    if target_sink in (name, desc, nick) or target_sink.lower() in (name.lower(), desc.lower()):
                        snk_id = obj.get("id")
        except Exception:
            pass

    # Dynamic fallback if targeted hardware device was disconnected/unplugged
    if src_id is None:
        fallback_src = resolve_hardware_source()
        if fallback_src != "default" and shutil.which("pw-dump"):
            try:
                out = subprocess.check_output(["pw-dump", "Node"], text=True, stderr=subprocess.DEVNULL, env=COMMAND_ENV)
                for obj in json.loads(out):
                    if obj.get("info", {}).get("props", {}).get("media.class") == "Audio/Source":
                        n = obj.get("info", {}).get("props", {}).get("node.name", "")
                        if fallback_src == n:
                            src_id = obj.get("id")
                            break
            except Exception:
                pass

    if snk_id is None:
        fallback_snk = resolve_hardware_sink()
        if fallback_snk != "default" and shutil.which("pw-dump"):
            try:
                out = subprocess.check_output(["pw-dump", "Node"], text=True, stderr=subprocess.DEVNULL, env=COMMAND_ENV)
                for obj in json.loads(out):
                    if obj.get("info", {}).get("props", {}).get("media.class") == "Audio/Sink":
                        n = obj.get("info", {}).get("props", {}).get("node.name", "")
                        if fallback_snk == n:
                            snk_id = obj.get("id")
                            break
            except Exception:
                pass

    if src_id is not None:
        subprocess.run(["wpctl", "set-default", str(src_id)], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=COMMAND_ENV)
    if snk_id is not None:
        subprocess.run(["wpctl", "set-default", str(snk_id)], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=COMMAND_ENV)


def set_dusky_devices_as_default() -> None:
    """
    Automatically sets Dusky Mic (Source) and Dusky Audio (Sink) as the system's
    active default audio devices in PipeWire / WirePlumber upon engine startup.
    Allows manual override at any time via pavucontrol, wpctl, or desktop applets.
    """
    if not shutil.which("wpctl") or not shutil.which("pw-dump"):
        return

    for _ in range(12):
        try:
            out = subprocess.check_output(["pw-dump", "Node"], text=True, stderr=subprocess.DEVNULL, env=COMMAND_ENV)
            nodes = json.loads(out)
            mic_id = None
            sink_id = None
            for obj in nodes:
                props = obj.get("info", {}).get("props", {})
                media_class = props.get("media.class", "")
                node_name = props.get("node.name", "").lower()
                node_desc = props.get("node.description", "").lower()

                if media_class == "Audio/Source" and ("ghelper-audio" in node_name or "dusky mic" in node_desc):
                    mic_id = obj.get("id")
                elif media_class == "Audio/Sink" and ("ghelper-audio-sink" in node_name or "dusky audio" in node_desc):
                    sink_id = obj.get("id")

            if mic_id is not None:
                subprocess.run(["wpctl", "set-default", str(mic_id)], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=COMMAND_ENV)
                break
        except Exception:
            pass
        time.sleep(0.04)


# -----------------------------------------------------------------------------
#   UNIX Domain Socket IPC & Direct Subprocess Daemon Server
# -----------------------------------------------------------------------------
class AudioDspServer:
    def __init__(self, bin_path: Path) -> None:
        self.bin_path = bin_path
        self.proc: subprocess.Popen[bytes] | None = None
        self.sock: socket.socket | None = None
        self.running = False
        self.telemetry = AudioTelemetry()
        self._lock = threading.Lock()
        # Last physical sink the engine was pointed at + last liveness check.
        # Used by the serve loop to re-target when a device disconnects.
        self.current_sink: str = ""
        self._last_sink_check: float = 0.0

    def start(self) -> bool:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        SOCK_PATH.unlink(missing_ok=True)

        try:
            self.proc = subprocess.Popen(
                [str(self.bin_path)],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                bufsize=0,
            )
        except Exception as e:
            print(f"[DuskyAudioServer] Failed to launch {self.bin_path}: {e}", file=sys.stderr)
            return False

        self.running = True
        threading.Thread(target=self._telemetry_reader, daemon=True).start()

        # Create UNIX domain socket
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.bind(str(SOCK_PATH))
        # Owner-only: the socket accepts arbitrary DSP commands and must not
        # be reachable by other local users regardless of umask.
        os.chmod(SOCK_PATH, 0o600)
        self.sock.listen(10)
        self.sock.settimeout(0.5)

        with open(PID_FILE, "w", encoding="utf-8") as f:
            f.write(str(os.getpid()))

        # Immediately restore all persisted audio settings (input/output EQ, vocoder, spatial DSP, denoise)
        try:
            init_cfg = load_config()
            self._apply_full_config(init_cfg)
        except Exception:
            pass

        return True

    def _telemetry_reader(self) -> None:
        if not self.proc or not self.proc.stdout:
            return

        stdout_fd = self.proc.stdout.fileno()
        buf = bytearray()
        magic_bytes: Final[bytes] = struct.pack("<I", MAGIC)

        while self.running and self.proc.poll() is None:
            try:
                chunk = os.read(stdout_fd, 4096)
                if not chunk:
                    break
                buf.extend(chunk)
                while len(buf) >= FRAME_SIZE:
                    (
                        magic,
                        ver,
                        seq,
                        flags,
                        vad_prob,
                        rms_in_db,
                        rms_out_db,
                        noise_red_db,
                        pitch_hz,
                    ) = HEADER_STRUCT.unpack_from(buf, 0)
                    if magic == MAGIC and ver == PROTOCOL_VERSION:
                        del buf[:FRAME_SIZE]
                        with self._lock:
                            self.telemetry = AudioTelemetry(
                                seq=seq,
                                flags=flags,
                                vad_prob=vad_prob,
                                rms_in_db=rms_in_db,
                                rms_out_db=rms_out_db,
                                noise_reduction_db=noise_red_db,
                                tracked_pitch_hz=pitch_hz,
                            )
                    else:
                        idx = buf.find(magic_bytes, 1)
                        if idx != -1:
                            del buf[:idx]
                        else:
                            del buf[:]
                            break
            except Exception:
                break

    def send_cmd(self, line: str) -> None:
        if not self.proc or not self.proc.stdin or self.proc.poll() is not None:
            return
        try:
            self.proc.stdin.write((line.strip() + "\n").encode("utf-8"))
            self.proc.stdin.flush()
        except Exception:
            pass

    def stop(self) -> None:
        self.running = False
        self.send_cmd("QUIT")
        time.sleep(0.05)
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=0.3)
            except Exception:
                self.proc.kill()

        if self.sock:
            try:
                self.sock.close()
            except Exception:
                pass

        SOCK_PATH.unlink(missing_ok=True)
        PID_FILE.unlink(missing_ok=True)

    def serve_forever(self) -> None:
        while self.running:
            try:
                conn, _ = self.sock.accept()  # type: ignore
            except (socket.timeout, OSError):
                if not self.running or (self.proc and self.proc.poll() is not None):
                    break
                self._heal_dead_sink()
                continue

            threading.Thread(target=self._handle_client, args=(conn,), daemon=True).start()

        self.stop()

    def _heal_dead_sink(self) -> None:
        """Re-target the DSP engine when its physical sink disconnects.

        The engine is pointed at one sink name (e.g. BT headphones). When that
        device vanishes, audio goes silent until something re-resolves. This
        runs on the accept-loop wakeup (throttled): if the current target is
        dead, resolve the live default and move the engine there. One-way
        only — never steals back when devices reappear, so manual wpctl
        choices are respected.
        """
        try:
            now = time.monotonic()
            if now - self._last_sink_check < 3.0:
                return
            self._last_sink_check = now
            if not self.current_sink:
                return
            if is_node_alive(self.current_sink, "Audio/Sink"):
                return
            new_target = resolve_hardware_sink("default")
            if not new_target or new_target == "default" or new_target == self.current_sink:
                return
            self.send_cmd(f"SINK_TGT {new_target}")
            self.current_sink = new_target
        except Exception:
            pass

    def _handle_client(self, conn: socket.socket) -> None:
        conn.settimeout(5.0)
        try:
            with conn:
                buf = ""
                while self.running:
                    try:
                        chunk = conn.recv(4096).decode("utf-8")
                    except socket.timeout:
                        continue
                    if not chunk:
                        break
                    buf += chunk
                    while "\n" in buf:
                        line, buf = buf.split("\n", 1)
                        cmd = line.strip()
                        if not cmd:
                            continue

                        if cmd == "GET_TELEMETRY":
                            with self._lock:
                                resp = json.dumps(asdict(self.telemetry)) + "\n"
                            conn.sendall(resp.encode("utf-8"))
                        elif cmd == "PING":
                            conn.sendall(b"PONG\n")
                        elif cmd == "QUIT":
                            self.running = False
                            conn.sendall(b"OK\n")
                            return
                        elif cmd.startswith("CMD "):
                            self.send_cmd(cmd[4:])
                            conn.sendall(b"OK\n")
                        elif cmd.startswith("CONFIG_SYNC "):
                            cfg_dict = json.loads(cmd[12:])
                            cfg = AudioConfig(**cfg_dict)
                            self._apply_full_config(cfg)
                            conn.sendall(b"OK\n")
        except Exception:
            pass

    def _apply_full_config(self, cfg: AudioConfig) -> None:
        # Hardware source & sink resolution (eliminates feedback loops)
        target_src = resolve_hardware_source(cfg.source, fallback_node=cfg.pre_source)
        self.send_cmd(f"SRC {target_src}")
        target_sink = resolve_hardware_sink(cfg.sink, fallback_node=cfg.pre_sink)
        self.send_cmd(f"SINK_TGT {target_sink}")
        self.current_sink = target_sink
        self.send_cmd(f"VOL {cfg.volume * 10}")
        self.send_cmd(f"MON {1 if cfg.monitor else 0}")

        # RNNoise Suppression - Input / Microphone
        self.send_cmd(f"RNN {1 if (cfg.enabled and cfg.rnnoise_on) else 0}")
        self.send_cmd(f"AGG {cfg.aggressiveness * 10}")

        # RNNoise Suppression - Output / Speaker & Headphone (Two-Way)
        self.send_cmd(f"OUT_NOISE {1 if (cfg.enabled and cfg.out_rnnoise_on) else 0}")
        self.send_cmd(f"OUT_AGG {cfg.out_aggressiveness * 10}")

        # Vocoder & Voice Transformers
        self.send_cmd(f"VOC {1 if (cfg.enabled and cfg.vocoder_on) else 0}")
        self.send_cmd(
            f"VOP {cfg.vocoder_mix * 10} {cfg.vocoder_carrier_hz} {cfg.vocoder_attack_ms} {cfg.vocoder_release_ms} {cfg.vocoder_detune} {1 if cfg.vocoder_follow else 0} {cfg.vocoder_pitch_shift}"
        )
        self.send_cmd(f"MTX {cfg.vocoder_matrix * 10}")
        self.send_cmd(f"PSH {cfg.pitch_shift if cfg.enabled else 0}")
        self.send_cmd(f"ATN {1 if (cfg.enabled and cfg.autotune_on) else 0}")
        self.send_cmd(f"ATT {cfg.autotune_target_hz if cfg.enabled else 0}")
        self.send_cmd(f"BCR {cfg.bitcrush_bits if cfg.enabled else 0} {cfg.bitcrush_downsample}")
        self.send_cmd(f"BPF {cfg.bandpass_hpf_hz if cfg.enabled else 0} {cfg.bandpass_lpf_hz if cfg.enabled else 0}")
        self.send_cmd(f"STT {cfg.stutter_hz if cfg.enabled else 0} 500")

        # Delay
        self.send_cmd(f"DLY {1 if (cfg.enabled and cfg.delay_on) else 0}")
        self.send_cmd(f"DLP {cfg.delay_ms} {cfg.delay_feedback * 10} {cfg.delay_mix * 10}")

        # Reverb
        self.send_cmd(f"RVB {1 if (cfg.enabled and cfg.reverb_on) else 0}")
        self.send_cmd(f"RVP {cfg.reverb_room * 10} {cfg.reverb_damp * 10} {cfg.reverb_width * 10} {cfg.reverb_mix * 10}")

        # 9-Band EQ & Uniform Post-Gain (Microphone Input)
        self.send_cmd(f"EQ {1 if (cfg.enabled and cfg.eq_on) else 0}")
        self.send_cmd(f"EGN {cfg.eq_post_gain}")
        eq_types = [3, 1, 0, 0, 0, 0, 0, 2, 0]
        eq_freqs = [80, 120, 250, 400, 1500, 3500, 6000, 9000, 12000]
        eq_q = [707, 707, 1000, 1000, 1000, 700, 1000, 700, 1000]
        for idx, gain in enumerate(cfg.eq_gains):
            self.send_cmd(f"EQB {idx} {eq_types[idx]} {eq_freqs[idx]} {eq_q[idx]} {gain}")

        # Stereo 9-Band EQ & Uniform Post-Gain (Playback Output)
        self.send_cmd(f"OUT_EQ {1 if (cfg.enabled and cfg.out_eq_on) else 0}")
        self.send_cmd(f"OUT_EGN {cfg.out_eq_post_gain}")
        for idx, gain in enumerate(cfg.out_eq_gains):
            self.send_cmd(f"OUT_EQB {idx} {eq_types[idx]} {eq_freqs[idx]} {eq_q[idx]} {gain}")

        # Output Playback Stereo Voice Transformers
        self.send_cmd(f"OUT_VOC {1 if (cfg.enabled and cfg.out_vocoder_on) else 0}")
        self.send_cmd(
            f"OUT_VOP {cfg.out_vocoder_mix * 10} {cfg.out_vocoder_carrier_hz} {cfg.out_vocoder_attack_ms} {cfg.out_vocoder_release_ms} {cfg.out_vocoder_detune} {1 if cfg.out_vocoder_follow else 0} {cfg.out_vocoder_pitch_shift}"
        )
        self.send_cmd(f"OUT_MTX {cfg.out_vocoder_matrix * 10}")
        self.send_cmd(f"OUT_PSH {cfg.out_pitch_shift if cfg.enabled else 0}")
        self.send_cmd(f"OUT_ATN {1 if (cfg.enabled and cfg.out_autotune_on) else 0}")
        self.send_cmd(f"OUT_ATT {cfg.out_autotune_target_hz if cfg.enabled else 0}")
        self.send_cmd(f"OUT_BCR {cfg.out_bitcrush_bits if cfg.enabled else 0} {cfg.out_bitcrush_downsample}")
        self.send_cmd(f"OUT_BPF {cfg.out_bandpass_hpf_hz if cfg.enabled else 0} {cfg.out_bandpass_lpf_hz if cfg.enabled else 0}")
        self.send_cmd(f"OUT_STT {cfg.out_stutter_hz if cfg.enabled else 0} 500")

        # Output Playback Stereo Delay
        self.send_cmd(f"OUT_DLY {1 if (cfg.enabled and cfg.out_delay_on) else 0}")
        self.send_cmd(f"OUT_DLP {cfg.out_delay_ms} {cfg.out_delay_feedback * 10} {cfg.out_delay_mix * 10}")

        # Output Playback Stereo Reverb
        self.send_cmd(f"OUT_RVB {1 if (cfg.enabled and cfg.out_reverb_on) else 0}")
        self.send_cmd(f"OUT_RVP {cfg.out_reverb_room * 10} {cfg.out_reverb_damp * 10} {cfg.out_reverb_width * 10} {cfg.out_reverb_mix * 10}")


# --- Client Communication Helpers ---
def send_daemon_cmd(cmd_str: str) -> bool:
    if not SOCK_PATH.exists():
        return False
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(0.5)
            client.connect(str(SOCK_PATH))
            client.sendall(f"CMD {cmd_str.strip()}\n".encode("utf-8"))
            resp = client.recv(128)
            return resp.startswith(b"OK")
    except Exception:
        return False


def sync_config_to_daemon(cfg: AudioConfig) -> bool:
    if not SOCK_PATH.exists():
        return False
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(1.0)
            client.connect(str(SOCK_PATH))
            payload = json.dumps(asdict(cfg))
            client.sendall(f"CONFIG_SYNC {payload}\n".encode("utf-8"))
            resp = client.recv(128)
            return resp.startswith(b"OK")
    except Exception:
        return False


def fetch_telemetry_from_daemon() -> AudioTelemetry | None:
    if not SOCK_PATH.exists():
        return None
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(0.1)
            client.connect(str(SOCK_PATH))
            client.sendall(b"GET_TELEMETRY\n")
            raw = client.recv(1024).decode("utf-8").strip()
            if raw:
                d = json.loads(raw)
                return AudioTelemetry(**d)
    except Exception:
        pass
    return None


def start_daemon(cfg: AudioConfig | None = None) -> bool:
    if cfg is None:
        cfg = load_config()

    save_previous_default_devices(cfg)
    cfg.enabled = True
    save_config(cfg)

    pid = get_daemon_pid()
    if pid and SOCK_PATH.exists():
        sync_config_to_daemon(cfg)
        set_dusky_devices_as_default()
        return True

    # Pre-clean stale state
    stop_daemon(restore_defaults=False)

    missing = check_system_dependencies()
    if missing:
        err_msg = "Dusky Audio Studio cannot start due to missing dependencies:\n\n" + "\n".join(f"• {m}" for m in missing)
        print(f"\n[Dusky Audio Error]\n{err_msg}\n", file=sys.stderr)
        send_desktop_notification("Dusky Audio Studio — Missing Dependency", "\n".join(f"• {m}" for m in missing), "critical")
        return False

    bin_path = find_helper_binary()
    if not bin_path:
        return False

    # Spawn daemon server in background subprocess
    script_dir = Path(__file__).resolve().parent
    server_code = f"""
import sys
sys.path.insert(0, {repr(str(script_dir))})
from dusky_audio_studio import AudioDspServer, Path
srv = AudioDspServer(Path({repr(str(bin_path))}))
if srv.start():
    srv.serve_forever()
"""
    subprocess.Popen(
        [sys.executable, "-c", server_code],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        stdin=subprocess.DEVNULL,
        cwd=str(STATE_DIR),
        start_new_session=True,
        env=COMMAND_ENV,
    )

    for _ in range(40):
        time.sleep(0.04)
        if SOCK_PATH.exists():
            try:
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                    s.settimeout(0.2)
                    s.connect(str(SOCK_PATH))
                    s.sendall(b"PING\n")
                    if s.recv(16).startswith(b"PONG"):
                        sync_config_to_daemon(cfg)
                        set_dusky_devices_as_default()
                        return True
            except Exception:
                pass

    return False


def stop_daemon(restore_defaults: bool = True, cfg: AudioConfig | None = None) -> bool:
    pid = get_daemon_pid()
    if SOCK_PATH.exists():
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.settimeout(0.3)
                s.connect(str(SOCK_PATH))
                s.sendall(b"QUIT\n")
        except Exception:
            pass

    if pid:
        for _ in range(15):
            time.sleep(0.01)
            try:
                os.kill(pid, 0)
            except OSError:
                break
        else:
            try:
                os.kill(pid, signal.SIGTERM)
            except OSError:
                pass

    try:
        subprocess.run(["pkill", "-x", "dusky_audio_dsp"], stderr=subprocess.DEVNULL)
        subprocess.run(["pkill", "-x", "ghelper-audio"], stderr=subprocess.DEVNULL)
    except Exception:
        pass

    PID_FILE.unlink(missing_ok=True)
    SOCK_PATH.unlink(missing_ok=True)

    if restore_defaults:
        restore_previous_default_devices(cfg)

    return True


# -----------------------------------------------------------------------------
#   GTK3 Interface & Reactive Studio Studio
# -----------------------------------------------------------------------------
def run_gtk_app() -> None:
    if GUI_PID_FILE.exists():
        try:
            with open(GUI_PID_FILE, "r", encoding="utf-8") as f:
                old_pid = int(f.read().strip())
            os.kill(old_pid, 0)
            if not pid_is_dusky_audio(old_pid):
                raise ValueError("pid recycled by another process")
            os.kill(old_pid, signal.SIGTERM)
            GUI_PID_FILE.unlink(missing_ok=True)
            return
        except (OSError, ValueError):
            GUI_PID_FILE.unlink(missing_ok=True)

    with open(GUI_PID_FILE, "w", encoding="utf-8") as f:
        f.write(str(os.getpid()))

    import gi
    gi.require_version("Gtk", "3.0")
    gi.require_version("Gdk", "3.0")
    from gi.repository import Gdk, GLib, Gtk

    try:
        GLib.set_prgname("dusky_audio_studio.py")
        GLib.set_application_name("Dusky Audio Studio")
    except Exception:
        pass

    cfg = load_config()

    provider = Gtk.CssProvider()
    provider.load_from_data(DUSKY_CSS.encode("utf-8"))
    screen = Gdk.Screen.get_default()
    if screen:
        Gtk.StyleContext.add_provider_for_screen(screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_USER)

    class AudioStudioWindow(Gtk.Window):
        def __init__(self) -> None:
            super().__init__(title="Dusky Audio Studio & Voice DSP")
            self.set_wmclass("dusky_audio_studio.py", "dusky_audio_studio.py")
            self.set_default_size(680, 760)
            self.set_border_width(16)
            self.set_position(Gtk.WindowPosition.CENTER)
            self.get_style_context().add_class("panel-window")

            self.cfg = cfg
            self.sources = enumerate_sources()
            self.sinks = enumerate_sinks()
            self._updating_ui = False
            self.preset_buttons: dict[str, Gtk.Button] = {}
            self.current_voice_target = "mic"
            self.current_spatial_target = "mic"
            self.current_eq_target = "mic"
            self.eq_preset_buttons: dict[str, Gtk.Button] = {}

            main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
            self.add(main_vbox)

            # --- Header: Title + Master Switch ---
            header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            left_spacer = Gtk.Box()
            left_spacer.set_size_request(44, -1)
            header_box.pack_start(left_spacer, False, False, 0)

            title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            title_box.set_halign(Gtk.Align.CENTER)
            title_box.set_hexpand(True)

            title_lbl = Gtk.Label(label="Dusky Audio Studio", xalign=0.5)
            title_lbl.get_style_context().add_class("header-title")

            self.status_lbl = Gtk.Label(xalign=0.5)
            self.update_status_label()

            title_box.pack_start(title_lbl, False, False, 0)
            title_box.pack_start(self.status_lbl, False, False, 0)
            header_box.pack_start(title_box, True, True, 0)

            self.master_switch = Gtk.Switch()
            self.master_switch.set_valign(Gtk.Align.CENTER)
            self.master_switch.set_halign(Gtk.Align.END)
            self.master_switch.get_style_context().add_class("compact-switch")
            self.master_switch.set_active(self.cfg.enabled)
            self.master_switch.connect("notify::active", self.on_master_toggled)
            header_box.pack_end(self.master_switch, False, False, 0)
            main_vbox.pack_start(header_box, False, False, 0)

            # --- Missing Dependencies Warning ---
            missing = check_system_dependencies()
            if missing:
                warn_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
                warn_box.get_style_context().add_class("warning-banner")
                warn_title_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
                warn_icon = Gtk.Image.new_from_icon_name("dialog-warning-symbolic", Gtk.IconSize.MENU)
                warn_title = Gtk.Label(label="Missing System Audio Dependencies:", xalign=0)
                warn_title.get_style_context().add_class("warning-text")
                warn_title_box.pack_start(warn_icon, False, False, 0)
                warn_title_box.pack_start(warn_title, False, False, 0)
                warn_box.pack_start(warn_title_box, False, False, 0)
                for m in missing:
                    item_lbl = Gtk.Label(label=f"  • {m}", xalign=0)
                    item_lbl.get_style_context().add_class("footer-info")
                    warn_box.pack_start(item_lbl, False, False, 0)
                main_vbox.pack_start(warn_box, False, False, 0)

            # --- Top Control Strip: Microphone Device, Monitor & Master Reset ---
            top_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            self.src_combo = Gtk.ComboBoxText()
            self.src_combo.get_style_context().add_class("device-combo")
            active_idx = 0
            for idx, (node, desc) in enumerate(self.sources):
                self.src_combo.append(node, desc)
                if node == self.cfg.source:
                    active_idx = idx
            self.src_combo.set_active(active_idx)
            self.src_combo.connect("changed", self.on_source_changed)
            top_bar.pack_start(self.src_combo, True, True, 0)

            self.mon_btn = Gtk.CheckButton(label="Hear Voice")
            self.mon_btn.set_active(self.cfg.monitor)
            self.mon_btn.connect("toggled", self.on_monitor_toggled)
            top_bar.pack_start(self.mon_btn, False, False, 0)

            btn_reset_all = self.create_icon_button(
                "view-refresh-symbolic",
                "Reset All Defaults",
                "Reset all noise suppression, voice transformations, spatial effects, and EQ to clean factory defaults",
                "reset-btn",
                self.reset_all_defaults,
            )
            top_bar.pack_end(btn_reset_all, False, False, 0)

            main_vbox.pack_start(top_bar, False, False, 0)

            main_vbox.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 0)

            # --- Notebook Tabs ---
            self.notebook = Gtk.Notebook()
            self.notebook.set_scrollable(True)
            main_vbox.pack_start(self.notebook, True, True, 0)

            self.build_tab_noise()
            self.build_tab_voice_fx()
            self.build_tab_spatial_dsp()
            self.build_tab_equalizer()

            # --- Footer ---
            footer_lbl = Gtk.Label(
                label="Virtual Audio Device: Dusky Mic & Dusky Audio (PipeWire RT Low-Latency DSP)",
                xalign=0.5,
            )
            footer_lbl.get_style_context().add_class("footer-info")
            main_vbox.pack_end(footer_lbl, False, False, 0)

            if self.cfg.enabled:
                start_daemon(self.cfg)

            # Start 30 Hz Telemetry Polling Timer
            GLib.timeout_add(33, self.poll_telemetry)

        def create_tab_label(self, icon_name: str, label_text: str) -> Gtk.Box:
            box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
            box.set_halign(Gtk.Align.CENTER)
            box.set_valign(Gtk.Align.CENTER)
            box.set_hexpand(True)
            icon = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.MENU)
            lbl = Gtk.Label(label=label_text)
            box.pack_start(icon, False, False, 0)
            box.pack_start(lbl, False, False, 0)
            box.show_all()
            return box

        def add_notebook_tab(self, page: Gtk.Widget, icon_name: str, label_text: str) -> None:
            tab_box = self.create_tab_label(icon_name, label_text)
            self.notebook.append_page(page, tab_box)
            self.notebook.child_set_property(page, "tab-expand", True)
            self.notebook.child_set_property(page, "tab-fill", True)

        def create_icon_button(
            self,
            icon_name: str,
            label_text: str,
            tooltip: str = "",
            css_class: str = "",
            callback: Any = None,
        ) -> Gtk.Button:
            btn = Gtk.Button()
            box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
            icon = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.MENU)
            lbl = Gtk.Label(label=label_text)
            box.pack_start(icon, False, False, 0)
            box.pack_start(lbl, False, False, 0)
            btn.add(box)
            if css_class:
                btn.get_style_context().add_class(css_class)
            if tooltip:
                btn.set_tooltip_text(tooltip)
            if callback:
                btn.connect("clicked", callback)
            return btn

        # ---------------------------------------------------------------------
        # Tab 1: Noise & Telemetry
        # ---------------------------------------------------------------------
        def build_tab_noise(self) -> None:
            vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
            vbox.set_border_width(12)

            # Master Output Volume
            self.vol_row = self.create_slider_row("Microphone Output Gain", self.cfg.volume, 0, 200, "%", self.on_volume_changed)
            vbox.pack_start(self.vol_row, False, False, 0)

            # RNNoise Neural Toggle
            rnn_hdr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            rnn_lbl = Gtk.Label(label="RNNoise Neural Suppression", xalign=0)
            rnn_lbl.get_style_context().add_class("section-label")
            self.rnn_switch = Gtk.Switch()
            self.rnn_switch.get_style_context().add_class("compact-switch")
            self.rnn_switch.set_active(self.cfg.rnnoise_on)
            self.rnn_switch.connect("notify::active", self.on_rnnoise_toggled)
            rnn_hdr.pack_start(rnn_lbl, True, True, 0)
            rnn_hdr.pack_end(self.rnn_switch, False, False, 0)
            vbox.pack_start(rnn_hdr, False, False, 0)

            # Aggressiveness
            self.agg_row = self.create_slider_row(
                "Noise Gate Aggressiveness (Silence Attenuation)",
                self.cfg.aggressiveness,
                0,
                100,
                "%",
                self.on_agg_changed,
            )
            vbox.pack_start(self.agg_row, False, False, 0)

            vbox.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 4)

            # Output (Two-Way) Noise Cancellation - Speakers / Headphones
            out_section_lbl = Gtk.Label(
                label="Output Noise Cancellation (Incoming Audio)",
                xalign=0,
            )
            out_section_lbl.get_style_context().add_class("section-label")
            vbox.pack_start(out_section_lbl, False, False, 0)

            out_desc = Gtk.Label(
                label=(
                    "Filters background noise from other people's microphones "
                    "in Discord, Zoom, and browser calls before it reaches "
                    "your speakers or headphones."
                ),
                xalign=0,
                wrap=True,
            )
            out_desc.get_style_context().add_class("dim-label")
            vbox.pack_start(out_desc, False, False, 0)

            # Output Device Combo
            sink_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            sink_lbl = Gtk.Label(label="Physical Playback Device:", xalign=0)
            sink_lbl.get_style_context().add_class("section-label")
            self.sink_combo = Gtk.ComboBoxText()
            self.sink_combo.get_style_context().add_class("device-combo")
            sink_active_idx = 0
            for idx, (node, desc) in enumerate(self.sinks):
                self.sink_combo.append(node, desc)
                if node == self.cfg.sink:
                    sink_active_idx = idx
            self.sink_combo.set_active(sink_active_idx)
            self.sink_combo.connect("changed", self.on_sink_changed)
            sink_box.pack_start(sink_lbl, False, False, 0)
            sink_box.pack_start(self.sink_combo, True, True, 0)
            vbox.pack_start(sink_box, False, False, 0)

            out_rnn_hdr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            out_rnn_lbl = Gtk.Label(label="Output RNNoise Suppression", xalign=0)
            out_rnn_lbl.get_style_context().add_class("section-label")
            self.out_rnn_switch = Gtk.Switch()
            self.out_rnn_switch.get_style_context().add_class("compact-switch")
            self.out_rnn_switch.set_active(self.cfg.out_rnnoise_on)
            self.out_rnn_switch.connect("notify::active", self.on_out_rnnoise_toggled)
            out_rnn_hdr.pack_start(out_rnn_lbl, True, True, 0)
            out_rnn_hdr.pack_end(self.out_rnn_switch, False, False, 0)
            vbox.pack_start(out_rnn_hdr, False, False, 0)

            self.out_agg_row = self.create_slider_row(
                "Output Noise Gate Aggressiveness",
                self.cfg.out_aggressiveness,
                0,
                100,
                "%",
                self.on_out_agg_changed,
            )
            vbox.pack_start(self.out_agg_row, False, False, 0)

            vbox.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 4)

            # Live Telemetry Visualizer Card
            tele_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
            tele_box.get_style_context().add_class("telemetry-card")

            tele_title = Gtk.Label(label="Live Signal Telemetry", xalign=0)
            tele_title.get_style_context().add_class("section-label")
            tele_box.pack_start(tele_title, False, False, 0)

            grid = Gtk.Grid()
            grid.set_column_spacing(12)
            grid.set_row_spacing(6)
            grid.set_hexpand(True)

            # Voice Activity Probability
            vad_lbl = Gtk.Label(label="Voice Activity", xalign=0)
            vad_lbl.get_style_context().add_class("meter-label")
            self.vad_val_lbl = Gtk.Label(label="0%", xalign=1)
            self.vad_val_lbl.get_style_context().add_class("meter-val")
            self.vad_bar = Gtk.ProgressBar()
            grid.attach(vad_lbl, 0, 0, 1, 1)
            grid.attach(self.vad_bar, 1, 0, 1, 1)
            grid.attach(self.vad_val_lbl, 2, 0, 1, 1)

            # Noise Reduction dB
            red_lbl = Gtk.Label(label="Active Reduction", xalign=0)
            red_lbl.get_style_context().add_class("meter-label")
            self.red_val_lbl = Gtk.Label(label="0.0 dB", xalign=1)
            self.red_val_lbl.get_style_context().add_class("meter-val")
            self.red_bar = Gtk.ProgressBar()
            grid.attach(red_lbl, 0, 1, 1, 1)
            grid.attach(self.red_bar, 1, 1, 1, 1)
            grid.attach(self.red_val_lbl, 2, 1, 1, 1)

            # Input RMS Level
            in_lbl = Gtk.Label(label="Input Level", xalign=0)
            in_lbl.get_style_context().add_class("meter-label")
            self.in_val_lbl = Gtk.Label(label="-inf dB", xalign=1)
            self.in_val_lbl.get_style_context().add_class("meter-val")
            self.in_bar = Gtk.ProgressBar()
            grid.attach(in_lbl, 0, 2, 1, 1)
            grid.attach(self.in_bar, 1, 2, 1, 1)
            grid.attach(self.in_val_lbl, 2, 2, 1, 1)

            # Output RMS Level
            out_lbl = Gtk.Label(label="Output Level", xalign=0)
            out_lbl.get_style_context().add_class("meter-label")
            self.out_val_lbl = Gtk.Label(label="-inf dB", xalign=1)
            self.out_val_lbl.get_style_context().add_class("meter-val")
            self.out_bar = Gtk.ProgressBar()
            grid.attach(out_lbl, 0, 3, 1, 1)
            grid.attach(self.out_bar, 1, 3, 1, 1)
            grid.attach(self.out_val_lbl, 2, 3, 1, 1)

            self.vad_bar.set_hexpand(True)
            self.red_bar.set_hexpand(True)
            self.in_bar.set_hexpand(True)
            self.out_bar.set_hexpand(True)

            tele_box.pack_start(grid, True, True, 0)
            vbox.pack_start(tele_box, False, False, 0)

            scrolled = Gtk.ScrolledWindow()
            scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            scrolled.add(vbox)
            self.add_notebook_tab(scrolled, "audio-input-microphone-symbolic", "Noise & Level")

        # ---------------------------------------------------------------------
        # ---------------------------------------------------------------------
        # Tab 2: Voice FX & Transformers (Microphone & Playback)
        # ---------------------------------------------------------------------
        def build_tab_voice_fx(self) -> None:
            vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
            vbox.set_border_width(12)

            # Target Mode Switcher: Input (Mic) vs Output (Playback)
            target_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
            target_box.set_halign(Gtk.Align.CENTER)
            target_box.get_style_context().add_class("segmented-group")

            self.btn_voice_target_mic = Gtk.Button(label="🎙 Microphone Voice FX (Input)")
            self.btn_voice_target_mic.get_style_context().add_class("segmented-btn")
            self.btn_voice_target_mic.get_style_context().add_class("active-preset")
            self.btn_voice_target_mic.connect("clicked", lambda _: self.set_voice_target("mic"))

            self.btn_voice_target_out = Gtk.Button(label="󰓃 Playback Voice FX (Output)")
            self.btn_voice_target_out.get_style_context().add_class("segmented-btn")
            self.btn_voice_target_out.connect("clicked", lambda _: self.set_voice_target("out"))

            target_box.pack_start(self.btn_voice_target_mic, True, True, 0)
            target_box.pack_start(self.btn_voice_target_out, True, True, 0)
            vbox.pack_start(target_box, False, False, 2)

            preset_hdr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            self.voice_hdr_lbl = Gtk.Label(label="Voice FX Character Presets (Microphone Input)", xalign=0)
            self.voice_hdr_lbl.get_style_context().add_class("section-label")
            btn_reset_voice = self.create_icon_button(
                "edit-undo-symbolic",
                "Reset Voice (Clean)",
                "Reset all voice modulation, pitch shift, autotune, and vocoder effects to Natural Clean",
                "reset-btn",
                self.reset_voice_fx,
            )
            preset_hdr.pack_start(self.voice_hdr_lbl, True, True, 0)
            preset_hdr.pack_end(btn_reset_voice, False, False, 0)
            vbox.pack_start(preset_hdr, False, False, 0)

            flowbox = Gtk.FlowBox()
            flowbox.set_valign(Gtk.Align.START)
            flowbox.set_max_children_per_line(4)
            flowbox.set_selection_mode(Gtk.SelectionMode.NONE)
            flowbox.set_row_spacing(6)
            flowbox.set_column_spacing(6)

            for name in PRESETS:
                btn = Gtk.Button(label=name)
                btn.get_style_context().add_class("preset-btn")
                btn.connect("clicked", lambda _, n=name: self.apply_preset_by_name(n))
                self.preset_buttons[name] = btn
                flowbox.add(btn)
            vbox.pack_start(flowbox, False, False, 0)

            vbox.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 4)

            # Granular Pitch Shifter
            self.pitch_row = self.create_slider_row(
                "Granular Pitch Shifter",
                int(self.cfg.pitch_shift / 100),
                -24,
                24,
                " st",
                self.on_pitch_changed,
            )
            vbox.pack_start(self.pitch_row, False, False, 0)

            # 16-Band Vocoder Header + Switch
            voc_hdr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            voc_lbl = Gtk.Label(label="16-Band Robot Vocoder & Carrier Stack", xalign=0)
            voc_lbl.get_style_context().add_class("section-label")
            self.voc_switch = Gtk.Switch()
            self.voc_switch.get_style_context().add_class("compact-switch")
            self.voc_switch.set_active(self.cfg.vocoder_on)
            self.voc_switch.connect("notify::active", self.on_vocoder_toggled)
            voc_hdr.pack_start(voc_lbl, True, True, 0)
            voc_hdr.pack_end(self.voc_switch, False, False, 0)
            vbox.pack_start(voc_hdr, False, False, 0)

            # Vocoder Follow Voice Pitch + Tracked Pitch Indicator
            follow_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            self.check_follow = Gtk.CheckButton(label="Follow Voice Pitch (Adaptive Formant Tracking)")
            self.check_follow.set_active(self.cfg.vocoder_follow)
            self.check_follow.connect("toggled", self.on_follow_toggled)
            self.lbl_pitch_track = Gtk.Label(label="Tracked Pitch: —", xalign=1)
            self.lbl_pitch_track.get_style_context().add_class("value-label")
            follow_box.pack_start(self.check_follow, True, True, 0)
            follow_box.pack_end(self.lbl_pitch_track, False, False, 0)
            vbox.pack_start(follow_box, False, False, 0)

            # Carrier Pitch Slider (Adaptive Transpose or Hz)
            carrier_title = "Carrier Pitch Transposition" if self.cfg.vocoder_follow else "Carrier Frequency"
            carrier_val = self.cfg.vocoder_pitch_shift if self.cfg.vocoder_follow else self.cfg.vocoder_carrier_hz
            carrier_min = -24 if self.cfg.vocoder_follow else 50
            carrier_max = 24 if self.cfg.vocoder_follow else 440
            carrier_unit = " st" if self.cfg.vocoder_follow else " Hz"
            self.carrier_row = self.create_slider_row(
                carrier_title,
                carrier_val,
                carrier_min,
                carrier_max,
                carrier_unit,
                self.on_carrier_changed,
            )
            vbox.pack_start(self.carrier_row, False, False, 0)

            # Vocoder Mix & Matrix Timbre
            self.voc_mix_row = self.create_slider_row(
                "Vocoder Dry/Wet Mix", self.cfg.vocoder_mix, 0, 100, "%", self.on_voc_mix_changed
            )
            vbox.pack_start(self.voc_mix_row, False, False, 0)

            self.matrix_row = self.create_slider_row(
                "Matrix / Sentinel Timbre (Ring Mod + Saturation)",
                self.cfg.vocoder_matrix,
                0,
                100,
                "%",
                self.on_matrix_changed,
            )
            vbox.pack_start(self.matrix_row, False, False, 0)

            # Autotune Switch
            atn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            atn_lbl = Gtk.Label(label="Autotune (Pitch Snap / Chromatic)", xalign=0)
            atn_lbl.get_style_context().add_class("section-label")
            self.atn_switch = Gtk.Switch()
            self.atn_switch.get_style_context().add_class("compact-switch")
            self.atn_switch.set_active(self.cfg.autotune_on)
            self.atn_switch.connect("notify::active", self.on_autotune_toggled)
            atn_box.pack_start(atn_lbl, True, True, 0)
            atn_box.pack_end(self.atn_switch, False, False, 0)
            vbox.pack_start(atn_box, False, False, 0)

            # Bitcrusher (0..15 bits)
            self.bitcrush_row = self.create_slider_row(
                "Lo-Fi Bitcrusher (Quantisation Depth)",
                self.cfg.bitcrush_bits,
                0,
                15,
                " bits",
                self.on_bitcrush_changed,
            )
            vbox.pack_start(self.bitcrush_row, False, False, 0)

            # Stutter Chopper Gate
            self.stutter_row = self.create_slider_row(
                "Stutter Chopper Gate (Rhythmic Machine Voice)",
                self.cfg.stutter_hz,
                0,
                20,
                " Hz",
                self.on_stutter_changed,
            )
            vbox.pack_start(self.stutter_row, False, False, 0)

            scrolled = Gtk.ScrolledWindow()
            scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            scrolled.add(vbox)
            self.add_notebook_tab(scrolled, "applications-multimedia-symbolic", "Voice FX")

        # ---------------------------------------------------------------------
        # Tab 3: Spatial DSP (Microphone & Playback)
        # ---------------------------------------------------------------------
        def build_tab_spatial_dsp(self) -> None:
            vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
            vbox.set_border_width(12)

            # Target Mode Switcher: Input (Mic) vs Output (Playback)
            target_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
            target_box.set_halign(Gtk.Align.CENTER)
            target_box.get_style_context().add_class("segmented-group")

            self.btn_spatial_target_mic = Gtk.Button(label="🎙 Microphone Spatial FX (Input)")
            self.btn_spatial_target_mic.get_style_context().add_class("segmented-btn")
            self.btn_spatial_target_mic.get_style_context().add_class("active-preset")
            self.btn_spatial_target_mic.connect("clicked", lambda _: self.set_spatial_target("mic"))

            self.btn_spatial_target_out = Gtk.Button(label="󰓃 Playback Spatial FX (Output)")
            self.btn_spatial_target_out.get_style_context().add_class("segmented-btn")
            self.btn_spatial_target_out.connect("clicked", lambda _: self.set_spatial_target("out"))

            target_box.pack_start(self.btn_spatial_target_mic, True, True, 0)
            target_box.pack_start(self.btn_spatial_target_out, True, True, 0)
            vbox.pack_start(target_box, False, False, 2)

            # Header + Reset Spatial FX Button
            spat_top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            self.spatial_hdr_lbl = Gtk.Label(label="Spatial FX (Tape Delay & Algorithmic Reverb)", xalign=0)
            self.spatial_hdr_lbl.get_style_context().add_class("section-label")
            btn_reset_spatial = self.create_icon_button(
                "edit-undo-symbolic",
                "Reset Delay & Reverb",
                "Disable and reset delay and reverb to clean bypass defaults",
                "reset-btn",
                self.reset_spatial_dsp,
            )
            spat_top.pack_start(self.spatial_hdr_lbl, True, True, 0)
            spat_top.pack_end(btn_reset_spatial, False, False, 0)
            vbox.pack_start(spat_top, False, False, 0)

            # Delay Header
            dly_hdr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            self.spatial_dly_lbl = Gtk.Label(label="Stereo Tape Echo / Delay (Microphone Input)", xalign=0)
            self.spatial_dly_lbl.get_style_context().add_class("section-label")
            self.dly_switch = Gtk.Switch()
            self.dly_switch.get_style_context().add_class("compact-switch")
            self.dly_switch.set_active(self.cfg.delay_on)
            self.dly_switch.connect("notify::active", self.on_delay_toggled)
            dly_hdr.pack_start(self.spatial_dly_lbl, True, True, 0)
            dly_hdr.pack_end(self.dly_switch, False, False, 0)
            vbox.pack_start(dly_hdr, False, False, 0)

            self.dly_time_row = self.create_slider_row("Delay Time", self.cfg.delay_ms, 10, 1000, " ms", self.on_delay_time_changed)
            self.dly_fb_row = self.create_slider_row("Delay Feedback", self.cfg.delay_feedback, 0, 95, "%", self.on_delay_fb_changed)
            self.dly_mix_row = self.create_slider_row("Delay Wet/Dry Mix", self.cfg.delay_mix, 0, 100, "%", self.on_delay_mix_changed)

            vbox.pack_start(self.dly_time_row, False, False, 0)
            vbox.pack_start(self.dly_fb_row, False, False, 0)
            vbox.pack_start(self.dly_mix_row, False, False, 0)

            vbox.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 4)

            # Reverb Header
            rvb_hdr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            self.spatial_rvb_lbl = Gtk.Label(label="Schroeder Algorithmic Reverb Tank (Microphone Input)", xalign=0)
            self.spatial_rvb_lbl.get_style_context().add_class("section-label")
            self.rvb_switch = Gtk.Switch()
            self.rvb_switch.get_style_context().add_class("compact-switch")
            self.rvb_switch.set_active(self.cfg.reverb_on)
            self.rvb_switch.connect("notify::active", self.on_reverb_toggled)
            rvb_hdr.pack_start(self.spatial_rvb_lbl, True, True, 0)
            rvb_hdr.pack_end(self.rvb_switch, False, False, 0)
            vbox.pack_start(rvb_hdr, False, False, 0)

            self.rvb_room_row = self.create_slider_row("Reverb Room Size", self.cfg.reverb_room, 0, 100, "%", self.on_reverb_room_changed)
            self.rvb_damp_row = self.create_slider_row("Reverb Dampening", self.cfg.reverb_damp, 0, 100, "%", self.on_reverb_damp_changed)
            self.rvb_width_row = self.create_slider_row("Reverb Stereo Width", self.cfg.reverb_width, 0, 100, "%", self.on_reverb_width_changed)
            self.rvb_mix_row = self.create_slider_row("Reverb Wet/Dry Mix", self.cfg.reverb_mix, 0, 100, "%", self.on_reverb_mix_changed)

            vbox.pack_start(self.rvb_room_row, False, False, 0)
            vbox.pack_start(self.rvb_damp_row, False, False, 0)
            vbox.pack_start(self.rvb_width_row, False, False, 0)
            vbox.pack_start(self.rvb_mix_row, False, False, 0)

            scrolled = Gtk.ScrolledWindow()
            scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            scrolled.add(vbox)
            self.add_notebook_tab(scrolled, "audio-speakers-symbolic", "Delay & Reverb")

        # ---------------------------------------------------------------------
        # Tab 4: 9-Band Studio EQ (Microphone & Playback)
        # ---------------------------------------------------------------------
        def build_tab_equalizer(self) -> None:
            vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
            vbox.set_border_width(12)

            # Target Mode Switcher: Input (Mic) vs Output (Playback)
            target_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
            target_box.set_halign(Gtk.Align.CENTER)
            target_box.get_style_context().add_class("segmented-group")

            self.btn_eq_target_mic = Gtk.Button(label="🎙 Microphone EQ (Input)")
            self.btn_eq_target_mic.get_style_context().add_class("segmented-btn")
            self.btn_eq_target_mic.get_style_context().add_class("active-preset")
            self.btn_eq_target_mic.connect("clicked", lambda _: self.set_eq_target("mic"))

            self.btn_eq_target_out = Gtk.Button(label="󰓃 Playback EQ (Output)")
            self.btn_eq_target_out.get_style_context().add_class("segmented-btn")
            self.btn_eq_target_out.connect("clicked", lambda _: self.set_eq_target("out"))

            target_box.pack_start(self.btn_eq_target_mic, True, True, 0)
            target_box.pack_start(self.btn_eq_target_out, True, True, 0)
            vbox.pack_start(target_box, False, False, 2)

            # EQ Header (Label, Reset Button, Master Toggle)
            eq_hdr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            self.eq_lbl = Gtk.Label(label="9-Band Studio Parametric EQ (Microphone Input)", xalign=0)
            self.eq_lbl.get_style_context().add_class("section-label")
            self.eq_switch = Gtk.Switch()
            self.eq_switch.get_style_context().add_class("compact-switch")
            self.eq_switch.set_active(self.cfg.eq_on)
            self.eq_switch.connect("notify::active", self.on_eq_toggled)

            btn_reset_eq = self.create_icon_button(
                "edit-undo-symbolic",
                "Reset EQ (Flat 0 dB)",
                "Zero out active EQ bands (0.0 dB) and reset post gain offset",
                "reset-btn",
                self.reset_eq_flat,
            )

            eq_hdr.pack_start(self.eq_lbl, True, True, 0)
            eq_hdr.pack_end(btn_reset_eq, False, False, 0)
            eq_hdr.pack_end(self.eq_switch, False, False, 0)
            vbox.pack_start(eq_hdr, False, False, 0)

            # Presets Chips Row
            self.eq_presets_box = Gtk.FlowBox()
            self.eq_presets_box.set_selection_mode(Gtk.SelectionMode.NONE)
            self.eq_presets_box.set_max_children_per_line(6)
            self.eq_presets_box.set_row_spacing(4)
            self.eq_presets_box.set_column_spacing(6)
            self._populate_eq_presets_chips()
            vbox.pack_start(self.eq_presets_box, False, False, 2)

            # Uniform Post-EQ Line Translation Gain
            self.eq_post_row = self.create_slider_row(
                "Uniform Post-EQ Gain Offset",
                int(self.cfg.eq_post_gain / 100),
                -36,
                36,
                " dB",
                self.on_eq_post_gain_changed,
            )
            vbox.pack_start(self.eq_post_row, False, False, 0)

            vbox.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 2)

            bands = [
                ("80 Hz (Sub Bass Highpass)", 0),
                ("120 Hz (Warmth Lowshelf)", 1),
                ("250 Hz (Low Mid Clean)", 2),
                ("400 Hz (Boxiness Mud Cut)", 3),
                ("1.5 kHz (Vocal Body)", 4),
                ("3.5 kHz (Presence & Clarity)", 5),
                ("6.0 kHz (Vocal Detail)", 6),
                ("9.0 kHz (Air & Sheen Highshelf)", 7),
                ("12.0 kHz (Brilliance)", 8),
            ]

            self.eq_band_rows = []
            for name, idx in bands:
                val = self.cfg.eq_gains[idx] / 100 if idx < len(self.cfg.eq_gains) else 0
                row = self.create_slider_row(name, int(val), -12, 12, " dB", lambda s, i=idx: self.on_eq_band_changed(i, s))
                self.eq_band_rows.append(row)
                vbox.pack_start(row, False, False, 0)

            scrolled = Gtk.ScrolledWindow()
            scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            scrolled.add(vbox)
            self.add_notebook_tab(scrolled, "multimedia-volume-control-symbolic", "9-Band EQ")

        # ---------------------------------------------------------------------
        # Helper: Create Slider Row
        # ---------------------------------------------------------------------
        def create_slider_row(
            self,
            title: str,
            val: int,
            min_v: int,
            max_v: int,
            unit: str,
            callback: Any,
        ) -> Gtk.Box:
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            hdr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            lbl = Gtk.Label(label=title, xalign=0)
            lbl.get_style_context().add_class("section-label")
            val_lbl = Gtk.Label(label=f"{val:+d}{unit}" if min_v < 0 else f"{val}{unit}", xalign=1)
            val_lbl.get_style_context().add_class("value-label")
            hdr.pack_start(lbl, True, True, 0)
            hdr.pack_end(val_lbl, False, False, 0)
            box.pack_start(hdr, False, False, 0)

            scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, min_v, max_v, 1)
            scale.set_value(val)

            def on_val(s: Gtk.Scale) -> None:
                v = int(s.get_value())
                val_lbl.set_text(f"{v:+d}{unit}" if min_v < 0 else f"{v}{unit}")
                if not self._updating_ui:
                    callback(s)

            def on_scroll(w: Gtk.Widget, event: Gdk.EventScroll) -> bool:
                # Forward mouse wheel scroll event to parent ScrolledWindow so it scrolls the page
                # rather than accidentally adjusting the slider.
                parent = w.get_parent()
                while parent:
                    if isinstance(parent, Gtk.ScrolledWindow):
                        adj = parent.get_vadjustment()
                        if adj:
                            step = adj.get_step_increment() or 20.0
                            if event.direction == Gdk.ScrollDirection.UP:
                                adj.set_value(max(adj.get_lower(), adj.get_value() - step * 2))
                            elif event.direction == Gdk.ScrollDirection.DOWN:
                                adj.set_value(min(adj.get_upper() - adj.get_page_size(), adj.get_value() + step * 2))
                            elif event.direction == Gdk.ScrollDirection.SMOOTH:
                                _, _, dy = event.get_scroll_deltas()
                                adj.set_value(max(adj.get_lower(), min(adj.get_upper() - adj.get_page_size(), adj.get_value() + dy * step * 2)))
                        return True
                    parent = parent.get_parent()
                return True

            scale.connect("scroll-event", on_scroll)
            scale.connect("value-changed", on_val)
            box.pack_start(scale, False, False, 0)
            box._scale = scale  # type: ignore
            box._val_lbl = val_lbl  # type: ignore
            box._title_lbl = lbl  # type: ignore
            return box

        # ---------------------------------------------------------------------
        # Real-Time Telemetry Polling
        # ---------------------------------------------------------------------
        def poll_telemetry(self) -> bool:
            tele = fetch_telemetry_from_daemon()
            if tele:
                # VAD %
                vad_pct = int(tele.vad_prob * 100)
                self.vad_bar.set_fraction(max(0.0, min(1.0, tele.vad_prob)))
                self.vad_val_lbl.set_text(f"{vad_pct}%")

                # Reduction dB (0..40 dB scale)
                red_frac = max(0.0, min(1.0, tele.noise_reduction_db / 40.0))
                self.red_bar.set_fraction(red_frac)
                self.red_val_lbl.set_text(f"{tele.noise_reduction_db:.1f} dB")

                # Input RMS (-80..0 dBFS)
                in_frac = max(0.0, min(1.0, (tele.rms_in_db + 80.0) / 80.0))
                self.in_bar.set_fraction(in_frac)
                self.in_val_lbl.set_text(f"{tele.rms_in_db:.1f} dB" if tele.rms_in_db > -79.0 else "-inf dB")

                # Output RMS (-80..0 dBFS)
                out_frac = max(0.0, min(1.0, (tele.rms_out_db + 80.0) / 80.0))
                self.out_bar.set_fraction(out_frac)
                self.out_val_lbl.set_text(f"{tele.rms_out_db:.1f} dB" if tele.rms_out_db > -79.0 else "-inf dB")

                # Tracked Pitch Hz
                if tele.tracked_pitch_hz > 1.0:
                    self.lbl_pitch_track.set_text(f"Tracked: ~{tele.tracked_pitch_hz:.0f} Hz")
                else:
                    self.lbl_pitch_track.set_text("Tracked: —")
            else:
                self.vad_bar.set_fraction(0.0)
                self.red_bar.set_fraction(0.0)
                self.in_bar.set_fraction(0.0)
                self.out_bar.set_fraction(0.0)
                self.lbl_pitch_track.set_text("Tracked: —")

            return True

        # ---------------------------------------------------------------------
        # Event Handlers & State Synchronization
        # ---------------------------------------------------------------------
        def update_status_label(self) -> None:
            if self.cfg.enabled:
                self.status_lbl.set_text("Active (PipeWire RT Low-Latency DSP ON)")
                self.status_lbl.get_style_context().remove_class("header-subtitle-inactive")
                self.status_lbl.get_style_context().add_class("header-subtitle-active")
            else:
                self.status_lbl.set_text("Disabled (Direct Hardware Bypass)")
                self.status_lbl.get_style_context().remove_class("header-subtitle-active")
                self.status_lbl.get_style_context().add_class("header-subtitle-inactive")

        def on_master_toggled(self, switch: Gtk.Switch, _gparam: Any) -> None:
            if self._updating_ui:
                return
            active = switch.get_active()
            self.cfg.enabled = active
            save_config(self.cfg)
            self.update_status_label()

            if active:
                ok = start_daemon(self.cfg)
                if not ok:
                    self._updating_ui = True
                    switch.set_active(False)
                    self._updating_ui = False
                    self.cfg.enabled = False
                    save_config(self.cfg)
                    self.update_status_label()
            else:
                stop_daemon(restore_defaults=True, cfg=self.cfg)

        def on_source_changed(self, combo: Gtk.ComboBoxText) -> None:
            if self._updating_ui:
                return
            node = combo.get_active_id()
            if node:
                self.cfg.source = node
                save_config(self.cfg)
                target = resolve_hardware_source(node)
                send_daemon_cmd(f"SRC {target}")

        def on_sink_changed(self, combo: Gtk.ComboBoxText) -> None:
            if self._updating_ui:
                return
            node = combo.get_active_id()
            if node:
                self.cfg.sink = node
                save_config(self.cfg)
                target = resolve_hardware_sink(node)
                send_daemon_cmd(f"SINK_TGT {target}")

        def on_volume_changed(self, scale: Gtk.Scale) -> None:
            val = int(scale.get_value())
            self.cfg.volume = val
            save_config(self.cfg)
            send_daemon_cmd(f"VOL {val * 10}")

        def on_rnnoise_toggled(self, switch: Gtk.Switch, _g: Any) -> None:
            active = switch.get_active()
            self.cfg.rnnoise_on = active
            save_config(self.cfg)
            send_daemon_cmd(f"RNN {1 if (self.cfg.enabled and active) else 0}")

        def on_agg_changed(self, scale: Gtk.Scale) -> None:
            val = int(scale.get_value())
            self.cfg.aggressiveness = val
            save_config(self.cfg)
            send_daemon_cmd(f"AGG {val * 10}")

        def on_out_rnnoise_toggled(self, switch: Gtk.Switch, _g: Any) -> None:
            active = switch.get_active()
            self.cfg.out_rnnoise_on = active
            save_config(self.cfg)
            send_daemon_cmd(f"OUT_NOISE {1 if active else 0}")

        def on_out_agg_changed(self, scale: Gtk.Scale) -> None:
            val = int(scale.get_value())
            self.cfg.out_aggressiveness = val
            save_config(self.cfg)
            send_daemon_cmd(f"OUT_AGG {val * 10}")

        def set_voice_target(self, target: str) -> None:
            if self.current_voice_target == target:
                return
            self.current_voice_target = target
            if target == "mic":
                self.btn_voice_target_mic.get_style_context().add_class("active-preset")
                self.btn_voice_target_out.get_style_context().remove_class("active-preset")
                self.voice_hdr_lbl.set_text("Voice FX Character Presets (Microphone Input)")
            else:
                self.btn_voice_target_out.get_style_context().add_class("active-preset")
                self.btn_voice_target_mic.get_style_context().remove_class("active-preset")
                self.voice_hdr_lbl.set_text("Voice FX Character Presets (Playback Output)")
            self._refresh_voice_ui()

        def set_spatial_target(self, target: str) -> None:
            if self.current_spatial_target == target:
                return
            self.current_spatial_target = target
            if target == "mic":
                self.btn_spatial_target_mic.get_style_context().add_class("active-preset")
                self.btn_spatial_target_out.get_style_context().remove_class("active-preset")
                self.spatial_dly_lbl.set_text("Stereo Tape Echo / Delay (Microphone Input)")
                self.spatial_rvb_lbl.set_text("Stereo Schroeder Reverb (Microphone Input)")
            else:
                self.btn_spatial_target_out.get_style_context().add_class("active-preset")
                self.btn_spatial_target_mic.get_style_context().remove_class("active-preset")
                self.spatial_dly_lbl.set_text("Stereo Tape Echo / Delay (Playback Output)")
                self.spatial_rvb_lbl.set_text("Stereo Schroeder Reverb (Playback Output)")
            self._refresh_spatial_ui()

        def on_pitch_changed(self, scale: Gtk.Scale) -> None:
            val = int(scale.get_value())
            if self.current_voice_target == "mic":
                self.cfg.pitch_shift = val * 100
                send_daemon_cmd(f"PSH {self.cfg.pitch_shift if self.cfg.enabled else 0}")
            else:
                self.cfg.out_pitch_shift = val * 100
                send_daemon_cmd(f"OUT_PSH {self.cfg.out_pitch_shift if self.cfg.enabled else 0}")
            save_config(self.cfg)
            self._clear_active_preset_highlight()

        def on_vocoder_toggled(self, switch: Gtk.Switch, _g: Any) -> None:
            active = switch.get_active()
            if self.current_voice_target == "mic":
                self.cfg.vocoder_on = active
                send_daemon_cmd(f"VOC {1 if (self.cfg.enabled and active) else 0}")
            else:
                self.cfg.out_vocoder_on = active
                send_daemon_cmd(f"OUT_VOC {1 if (self.cfg.enabled and active) else 0}")
            save_config(self.cfg)
            self._clear_active_preset_highlight()

        def on_follow_toggled(self, check: Gtk.CheckButton) -> None:
            active = check.get_active()
            is_mic = (self.current_voice_target == "mic")
            if is_mic:
                self.cfg.vocoder_follow = active
                c_shift = self.cfg.vocoder_pitch_shift
                c_hz = self.cfg.vocoder_carrier_hz
                mix = self.cfg.vocoder_mix
                atk = self.cfg.vocoder_attack_ms
                rel = self.cfg.vocoder_release_ms
                det = self.cfg.vocoder_detune
            else:
                self.cfg.out_vocoder_follow = active
                c_shift = self.cfg.out_vocoder_pitch_shift
                c_hz = self.cfg.out_vocoder_carrier_hz
                mix = self.cfg.out_vocoder_mix
                atk = self.cfg.out_vocoder_attack_ms
                rel = self.cfg.out_vocoder_release_ms
                det = self.cfg.out_vocoder_detune

            save_config(self.cfg)
            self._clear_active_preset_highlight()

            self._updating_ui = True
            if active:
                self.carrier_row._scale.set_range(-24, 24)  # type: ignore
                self.carrier_row._scale.set_value(c_shift)  # type: ignore
                self.carrier_row._title_lbl.set_text("Carrier Pitch Transposition")  # type: ignore
                self.carrier_row._val_lbl.set_text(f"{c_shift:+d} st")  # type: ignore
            else:
                self.carrier_row._scale.set_range(50, 440)  # type: ignore
                self.carrier_row._scale.set_value(c_hz)  # type: ignore
                self.carrier_row._title_lbl.set_text("Carrier Frequency")  # type: ignore
                self.carrier_row._val_lbl.set_text(f"{c_hz} Hz")  # type: ignore
            self._updating_ui = False

            prefix = "VOP" if is_mic else "OUT_VOP"
            send_daemon_cmd(f"{prefix} {mix * 10} {c_hz} {atk} {rel} {det} {1 if active else 0} {c_shift}")

        def on_carrier_changed(self, scale: Gtk.Scale) -> None:
            val = int(scale.get_value())
            is_mic = (self.current_voice_target == "mic")
            if is_mic:
                if self.cfg.vocoder_follow:
                    self.cfg.vocoder_pitch_shift = val
                else:
                    self.cfg.vocoder_carrier_hz = val
                c_shift = self.cfg.vocoder_pitch_shift
                c_hz = self.cfg.vocoder_carrier_hz
                follow = self.cfg.vocoder_follow
                mix = self.cfg.vocoder_mix
                atk = self.cfg.vocoder_attack_ms
                rel = self.cfg.vocoder_release_ms
                det = self.cfg.vocoder_detune
            else:
                if self.cfg.out_vocoder_follow:
                    self.cfg.out_vocoder_pitch_shift = val
                else:
                    self.cfg.out_vocoder_carrier_hz = val
                c_shift = self.cfg.out_vocoder_pitch_shift
                c_hz = self.cfg.out_vocoder_carrier_hz
                follow = self.cfg.out_vocoder_follow
                mix = self.cfg.out_vocoder_mix
                atk = self.cfg.out_vocoder_attack_ms
                rel = self.cfg.out_vocoder_release_ms
                det = self.cfg.out_vocoder_detune

            save_config(self.cfg)
            self._clear_active_preset_highlight()
            prefix = "VOP" if is_mic else "OUT_VOP"
            send_daemon_cmd(f"{prefix} {mix * 10} {c_hz} {atk} {rel} {det} {1 if follow else 0} {c_shift}")

        def on_voc_mix_changed(self, scale: Gtk.Scale) -> None:
            val = int(scale.get_value())
            is_mic = (self.current_voice_target == "mic")
            if is_mic:
                self.cfg.vocoder_mix = val
                c_shift = self.cfg.vocoder_pitch_shift
                c_hz = self.cfg.vocoder_carrier_hz
                follow = self.cfg.vocoder_follow
                atk = self.cfg.vocoder_attack_ms
                rel = self.cfg.vocoder_release_ms
                det = self.cfg.vocoder_detune
            else:
                self.cfg.out_vocoder_mix = val
                c_shift = self.cfg.out_vocoder_pitch_shift
                c_hz = self.cfg.out_vocoder_carrier_hz
                follow = self.cfg.out_vocoder_follow
                atk = self.cfg.out_vocoder_attack_ms
                rel = self.cfg.out_vocoder_release_ms
                det = self.cfg.out_vocoder_detune

            save_config(self.cfg)
            self._clear_active_preset_highlight()
            prefix = "VOP" if is_mic else "OUT_VOP"
            send_daemon_cmd(f"{prefix} {val * 10} {c_hz} {atk} {rel} {det} {1 if follow else 0} {c_shift}")

        def on_matrix_changed(self, scale: Gtk.Scale) -> None:
            val = int(scale.get_value())
            if self.current_voice_target == "mic":
                self.cfg.vocoder_matrix = val
                send_daemon_cmd(f"MTX {val * 10}")
            else:
                self.cfg.out_vocoder_matrix = val
                send_daemon_cmd(f"OUT_MTX {val * 10}")
            save_config(self.cfg)
            self._clear_active_preset_highlight()

        def on_autotune_toggled(self, switch: Gtk.Switch, _g: Any) -> None:
            active = switch.get_active()
            if self.current_voice_target == "mic":
                self.cfg.autotune_on = active
                send_daemon_cmd(f"ATN {1 if (self.cfg.enabled and active) else 0}")
                send_daemon_cmd(f"ATT {self.cfg.autotune_target_hz if self.cfg.enabled else 0}")
            else:
                self.cfg.out_autotune_on = active
                send_daemon_cmd(f"OUT_ATN {1 if (self.cfg.enabled and active) else 0}")
                send_daemon_cmd(f"OUT_ATT {self.cfg.out_autotune_target_hz if self.cfg.enabled else 0}")
            save_config(self.cfg)
            self._clear_active_preset_highlight()

        def on_bitcrush_changed(self, scale: Gtk.Scale) -> None:
            val = int(scale.get_value())
            if self.current_voice_target == "mic":
                self.cfg.bitcrush_bits = val
                send_daemon_cmd(f"BCR {val if self.cfg.enabled else 0} {self.cfg.bitcrush_downsample}")
            else:
                self.cfg.out_bitcrush_bits = val
                send_daemon_cmd(f"OUT_BCR {val if self.cfg.enabled else 0} {self.cfg.out_bitcrush_downsample}")
            save_config(self.cfg)
            self._clear_active_preset_highlight()

        def on_stutter_changed(self, scale: Gtk.Scale) -> None:
            val = int(scale.get_value())
            if self.current_voice_target == "mic":
                self.cfg.stutter_hz = val
                send_daemon_cmd(f"STT {val if self.cfg.enabled else 0} 500")
            else:
                self.cfg.out_stutter_hz = val
                send_daemon_cmd(f"OUT_STT {val if self.cfg.enabled else 0} 500")
            save_config(self.cfg)
            self._clear_active_preset_highlight()

        def on_delay_toggled(self, switch: Gtk.Switch, _g: Any) -> None:
            active = switch.get_active()
            if self.current_spatial_target == "mic":
                self.cfg.delay_on = active
                send_daemon_cmd(f"DLY {1 if (self.cfg.enabled and active) else 0}")
            else:
                self.cfg.out_delay_on = active
                send_daemon_cmd(f"OUT_DLY {1 if (self.cfg.enabled and active) else 0}")
            save_config(self.cfg)

        def on_delay_time_changed(self, scale: Gtk.Scale) -> None:
            val = int(scale.get_value())
            if self.current_spatial_target == "mic":
                self.cfg.delay_ms = val
                send_daemon_cmd(f"DLP {self.cfg.delay_ms} {self.cfg.delay_feedback * 10} {self.cfg.delay_mix * 10}")
            else:
                self.cfg.out_delay_ms = val
                send_daemon_cmd(f"OUT_DLP {self.cfg.out_delay_ms} {self.cfg.out_delay_feedback * 10} {self.cfg.out_delay_mix * 10}")
            save_config(self.cfg)

        def on_delay_fb_changed(self, scale: Gtk.Scale) -> None:
            val = int(scale.get_value())
            if self.current_spatial_target == "mic":
                self.cfg.delay_feedback = val
                send_daemon_cmd(f"DLP {self.cfg.delay_ms} {self.cfg.delay_feedback * 10} {self.cfg.delay_mix * 10}")
            else:
                self.cfg.out_delay_feedback = val
                send_daemon_cmd(f"OUT_DLP {self.cfg.out_delay_ms} {self.cfg.out_delay_feedback * 10} {self.cfg.out_delay_mix * 10}")
            save_config(self.cfg)

        def on_delay_mix_changed(self, scale: Gtk.Scale) -> None:
            val = int(scale.get_value())
            if self.current_spatial_target == "mic":
                self.cfg.delay_mix = val
                send_daemon_cmd(f"DLP {self.cfg.delay_ms} {self.cfg.delay_feedback * 10} {self.cfg.delay_mix * 10}")
            else:
                self.cfg.out_delay_mix = val
                send_daemon_cmd(f"OUT_DLP {self.cfg.out_delay_ms} {self.cfg.out_delay_feedback * 10} {self.cfg.out_delay_mix * 10}")
            save_config(self.cfg)

        def on_reverb_toggled(self, switch: Gtk.Switch, _g: Any) -> None:
            active = switch.get_active()
            if self.current_spatial_target == "mic":
                self.cfg.reverb_on = active
                send_daemon_cmd(f"RVB {1 if (self.cfg.enabled and active) else 0}")
            else:
                self.cfg.out_reverb_on = active
                send_daemon_cmd(f"OUT_RVB {1 if (self.cfg.enabled and active) else 0}")
            save_config(self.cfg)

        def on_reverb_room_changed(self, scale: Gtk.Scale) -> None:
            val = int(scale.get_value())
            if self.current_spatial_target == "mic":
                self.cfg.reverb_room = val
                send_daemon_cmd(f"RVP {self.cfg.reverb_room * 10} {self.cfg.reverb_damp * 10} {self.cfg.reverb_width * 10} {self.cfg.reverb_mix * 10}")
            else:
                self.cfg.out_reverb_room = val
                send_daemon_cmd(f"OUT_RVP {self.cfg.out_reverb_room * 10} {self.cfg.out_reverb_damp * 10} {self.cfg.out_reverb_width * 10} {self.cfg.out_reverb_mix * 10}")
            save_config(self.cfg)

        def on_reverb_damp_changed(self, scale: Gtk.Scale) -> None:
            val = int(scale.get_value())
            if self.current_spatial_target == "mic":
                self.cfg.reverb_damp = val
                send_daemon_cmd(f"RVP {self.cfg.reverb_room * 10} {self.cfg.reverb_damp * 10} {self.cfg.reverb_width * 10} {self.cfg.reverb_mix * 10}")
            else:
                self.cfg.out_reverb_damp = val
                send_daemon_cmd(f"OUT_RVP {self.cfg.out_reverb_room * 10} {self.cfg.out_reverb_damp * 10} {self.cfg.out_reverb_width * 10} {self.cfg.out_reverb_mix * 10}")
            save_config(self.cfg)

        def on_reverb_width_changed(self, scale: Gtk.Scale) -> None:
            val = int(scale.get_value())
            if self.current_spatial_target == "mic":
                self.cfg.reverb_width = val
                send_daemon_cmd(f"RVP {self.cfg.reverb_room * 10} {self.cfg.reverb_damp * 10} {self.cfg.reverb_width * 10} {self.cfg.reverb_mix * 10}")
            else:
                self.cfg.out_reverb_width = val
                send_daemon_cmd(f"OUT_RVP {self.cfg.out_reverb_room * 10} {self.cfg.out_reverb_damp * 10} {self.cfg.out_reverb_width * 10} {self.cfg.out_reverb_mix * 10}")
            save_config(self.cfg)

        def on_reverb_mix_changed(self, scale: Gtk.Scale) -> None:
            val = int(scale.get_value())
            if self.current_spatial_target == "mic":
                self.cfg.reverb_mix = val
                send_daemon_cmd(f"RVP {self.cfg.reverb_room * 10} {self.cfg.reverb_damp * 10} {self.cfg.reverb_width * 10} {self.cfg.reverb_mix * 10}")
            else:
                self.cfg.out_reverb_mix = val
                send_daemon_cmd(f"OUT_RVP {self.cfg.out_reverb_room * 10} {self.cfg.out_reverb_damp * 10} {self.cfg.out_reverb_width * 10} {self.cfg.out_reverb_mix * 10}")
            save_config(self.cfg)

        def set_eq_target(self, target: str) -> None:
            if self.current_eq_target == target:
                return
            self.current_eq_target = target
            if target == "mic":
                self.btn_eq_target_mic.get_style_context().add_class("active-preset")
                self.btn_eq_target_out.get_style_context().remove_class("active-preset")
                self.eq_lbl.set_text("9-Band Studio Parametric EQ (Microphone Input)")
            else:
                self.btn_eq_target_out.get_style_context().add_class("active-preset")
                self.btn_eq_target_mic.get_style_context().remove_class("active-preset")
                self.eq_lbl.set_text("9-Band Stereo Parametric EQ (Playback & Speakers)")
            self._populate_eq_presets_chips()
            self._refresh_eq_ui()

        def _populate_eq_presets_chips(self) -> None:
            for child in self.eq_presets_box.get_children():
                self.eq_presets_box.remove(child)
            self.eq_preset_buttons.clear()

            presets_dict = INPUT_EQ_PRESETS if self.current_eq_target == "mic" else OUTPUT_EQ_PRESETS
            for name, data in presets_dict.items():
                btn = Gtk.Button(label=name)
                btn.get_style_context().add_class("preset-chip")
                btn.connect("clicked", lambda _, n=name, d=data: self.apply_eq_preset(n, d))
                self.eq_presets_box.add(btn)
                self.eq_preset_buttons[name] = btn
            self.eq_presets_box.show_all()

        def apply_eq_preset(self, name: str, data: dict[str, Any]) -> None:
            self._updating_ui = True
            post_gain = data.get("post_gain", 0)
            gains = list(data.get("gains", [0] * 9))
            eq_types = [3, 1, 0, 0, 0, 0, 0, 2, 0]
            eq_freqs = [80, 120, 250, 400, 1500, 3500, 6000, 9000, 12000]
            eq_q = [707, 707, 1000, 1000, 1000, 700, 1000, 700, 1000]

            if self.current_eq_target == "mic":
                self.cfg.eq_post_gain = post_gain
                self.cfg.eq_gains = gains
                send_daemon_cmd(f"EGN {post_gain}")
                for idx, g in enumerate(gains):
                    send_daemon_cmd(f"EQB {idx} {eq_types[idx]} {eq_freqs[idx]} {eq_q[idx]} {g}")
            else:
                self.cfg.out_eq_post_gain = post_gain
                self.cfg.out_eq_gains = gains
                send_daemon_cmd(f"OUT_EGN {post_gain}")
                for idx, g in enumerate(gains):
                    send_daemon_cmd(f"OUT_EQB {idx} {eq_types[idx]} {eq_freqs[idx]} {eq_q[idx]} {g}")
            save_config(self.cfg)
            self._refresh_eq_ui()
            self._updating_ui = False
            for btn_name, btn in self.eq_preset_buttons.items():
                if btn_name == name:
                    btn.get_style_context().add_class("active-preset")
                else:
                    btn.get_style_context().remove_class("active-preset")

        def _clear_active_eq_preset_highlight(self) -> None:
            for btn in self.eq_preset_buttons.values():
                btn.get_style_context().remove_class("active-preset")

        def on_eq_toggled(self, switch: Gtk.Switch, _g: Any) -> None:
            active = switch.get_active()
            if self.current_eq_target == "mic":
                self.cfg.eq_on = active
                send_daemon_cmd(f"EQ {1 if (self.cfg.enabled and active) else 0}")
            else:
                self.cfg.out_eq_on = active
                send_daemon_cmd(f"OUT_EQ {1 if (self.cfg.enabled and active) else 0}")
            save_config(self.cfg)

        def on_eq_post_gain_changed(self, scale: Gtk.Scale) -> None:
            val = int(scale.get_value()) * 100
            if self.current_eq_target == "mic":
                self.cfg.eq_post_gain = val
                send_daemon_cmd(f"EGN {val}")
            else:
                self.cfg.out_eq_post_gain = val
                send_daemon_cmd(f"OUT_EGN {val}")
            save_config(self.cfg)
            self._clear_active_eq_preset_highlight()

        def on_eq_band_changed(self, idx: int, scale: Gtk.Scale) -> None:
            val = int(scale.get_value()) * 100
            eq_types = [3, 1, 0, 0, 0, 0, 0, 2, 0]
            eq_freqs = [80, 120, 250, 400, 1500, 3500, 6000, 9000, 12000]
            eq_q = [707, 707, 1000, 1000, 1000, 700, 1000, 700, 1000]

            if self.current_eq_target == "mic":
                if idx < len(self.cfg.eq_gains):
                    self.cfg.eq_gains[idx] = val
                    save_config(self.cfg)
                    send_daemon_cmd(f"EQB {idx} {eq_types[idx]} {eq_freqs[idx]} {eq_q[idx]} {val}")
            else:
                if idx < len(self.cfg.out_eq_gains):
                    self.cfg.out_eq_gains[idx] = val
                    save_config(self.cfg)
                    send_daemon_cmd(f"OUT_EQB {idx} {eq_types[idx]} {eq_freqs[idx]} {eq_q[idx]} {val}")
            self._clear_active_eq_preset_highlight()

        def on_monitor_toggled(self, check: Gtk.CheckButton) -> None:
            active = check.get_active()
            self.cfg.monitor = active
            save_config(self.cfg)
            send_daemon_cmd(f"MON {1 if active else 0}")

        # ---------------------------------------------------------------------
        # Reset Routines
        # ---------------------------------------------------------------------
        def reset_all_defaults(self, *_: Any) -> None:
            self._updating_ui = True
            saved_pre_src = self.cfg.pre_source
            saved_pre_snk = self.cfg.pre_sink
            saved_enabled = self.cfg.enabled

            self.cfg.volume = 100
            self.cfg.rnnoise_on = True
            self.cfg.aggressiveness = 100
            self.cfg.out_rnnoise_on = False
            self.cfg.out_aggressiveness = 70
            self.cfg.source = "default"
            self.cfg.sink = "default"
            self.cfg.monitor = False
            self.cfg.pre_source = saved_pre_src
            self.cfg.pre_sink = saved_pre_snk
            self.cfg.enabled = saved_enabled

            self._reset_voice_state()
            self._reset_spatial_state()
            self._reset_eq_state()
            save_config(self.cfg)
            sync_config_to_daemon(self.cfg)
            self._refresh_all_ui()
            self._updating_ui = False
            send_desktop_notification("Dusky Audio Studio", "All audio processing reset to clean factory defaults.")

        def reset_voice_fx(self, *_: Any) -> None:
            self.apply_preset_by_name("Natural Clean")

        def reset_spatial_dsp(self, *_: Any) -> None:
            self._updating_ui = True
            if self.current_spatial_target == "mic":
                self.cfg.delay_on = False
                self.cfg.delay_ms = 250
                self.cfg.delay_feedback = 35
                self.cfg.delay_mix = 30
                self.cfg.reverb_on = False
                self.cfg.reverb_room = 70
                self.cfg.reverb_damp = 50
                self.cfg.reverb_width = 80
                self.cfg.reverb_mix = 35
            else:
                self.cfg.out_delay_on = False
                self.cfg.out_delay_ms = 250
                self.cfg.out_delay_feedback = 35
                self.cfg.out_delay_mix = 30
                self.cfg.out_reverb_on = False
                self.cfg.out_reverb_room = 70
                self.cfg.out_reverb_damp = 50
                self.cfg.out_reverb_width = 80
                self.cfg.out_reverb_mix = 35
            save_config(self.cfg)
            sync_config_to_daemon(self.cfg)
            self._refresh_spatial_ui()
            self._updating_ui = False

        def reset_eq_flat(self, *_: Any) -> None:
            self._updating_ui = True
            if self.current_eq_target == "mic":
                self.cfg.eq_on = False
                self.cfg.eq_post_gain = 0
                self.cfg.eq_gains = [0, 0, 0, 0, 0, 0, 0, 0, 0]
            else:
                self.cfg.out_eq_on = False
                self.cfg.out_eq_post_gain = 0
                self.cfg.out_eq_gains = [0, 0, 0, 0, 0, 0, 0, 0, 0]
            save_config(self.cfg)
            sync_config_to_daemon(self.cfg)
            self._refresh_eq_ui()
            self._clear_active_eq_preset_highlight()
            self._updating_ui = False

        def _reset_voice_state(self) -> None:
            clean = PRESETS["Natural Clean"]
            for k, v in clean.items():
                if hasattr(self.cfg, k):
                    setattr(self.cfg, k, v)
                out_k = f"out_{k}"
                if hasattr(self.cfg, out_k):
                    setattr(self.cfg, out_k, v)
            self.cfg.vocoder_carrier_hz = 110
            self.cfg.vocoder_detune = 20
            self.cfg.vocoder_attack_ms = 5
            self.cfg.vocoder_release_ms = 30
            self.cfg.vocoder_follow = True
            self.cfg.vocoder_pitch_shift = 0
            self.cfg.vocoder_matrix = 0
            self.cfg.vocoder_mix = 0
            self.cfg.out_vocoder_carrier_hz = 110
            self.cfg.out_vocoder_detune = 20
            self.cfg.out_vocoder_attack_ms = 5
            self.cfg.out_vocoder_release_ms = 30
            self.cfg.out_vocoder_follow = True
            self.cfg.out_vocoder_pitch_shift = 0
            self.cfg.out_vocoder_matrix = 0
            self.cfg.out_vocoder_mix = 0

        def _reset_spatial_state(self) -> None:
            self.cfg.delay_on = False
            self.cfg.delay_ms = 250
            self.cfg.delay_feedback = 35
            self.cfg.delay_mix = 30
            self.cfg.reverb_on = False
            self.cfg.reverb_room = 70
            self.cfg.reverb_damp = 50
            self.cfg.reverb_width = 80
            self.cfg.reverb_mix = 35
            self.cfg.out_delay_on = False
            self.cfg.out_delay_ms = 250
            self.cfg.out_delay_feedback = 35
            self.cfg.out_delay_mix = 30
            self.cfg.out_reverb_on = False
            self.cfg.out_reverb_room = 70
            self.cfg.out_reverb_damp = 50
            self.cfg.out_reverb_width = 80
            self.cfg.out_reverb_mix = 35

        def _reset_eq_state(self) -> None:
            self.cfg.eq_on = False
            self.cfg.eq_post_gain = 0
            self.cfg.eq_gains = [0, 0, 0, 0, 0, 0, 0, 0, 0]
            self.cfg.out_eq_on = False
            self.cfg.out_eq_post_gain = 0
            self.cfg.out_eq_gains = [0, 0, 0, 0, 0, 0, 0, 0, 0]

        def _refresh_all_ui(self) -> None:
            self.vol_row._scale.set_value(self.cfg.volume)  # type: ignore
            self.rnn_switch.set_active(self.cfg.rnnoise_on)
            self.agg_row._scale.set_value(self.cfg.aggressiveness)  # type: ignore
            self.out_rnn_switch.set_active(self.cfg.out_rnnoise_on)
            self.out_agg_row._scale.set_value(self.cfg.out_aggressiveness)  # type: ignore
            sink_idx = 0
            for idx, (node, _) in enumerate(self.sinks):
                if node == self.cfg.sink:
                    sink_idx = idx
                    break
            self.sink_combo.set_active(sink_idx)
            self.mon_btn.set_active(self.cfg.monitor)
            self._refresh_voice_ui()
            self._refresh_spatial_ui()
            self._refresh_eq_ui()

        def _refresh_voice_ui(self) -> None:
            is_mic = (self.current_voice_target == "mic")
            voc_on = self.cfg.vocoder_on if is_mic else self.cfg.out_vocoder_on
            atn_on = self.cfg.autotune_on if is_mic else self.cfg.out_autotune_on
            follow = self.cfg.vocoder_follow if is_mic else self.cfg.out_vocoder_follow
            pshift = self.cfg.pitch_shift if is_mic else self.cfg.out_pitch_shift
            c_shift = self.cfg.vocoder_pitch_shift if is_mic else self.cfg.out_vocoder_pitch_shift
            c_hz = self.cfg.vocoder_carrier_hz if is_mic else self.cfg.out_vocoder_carrier_hz
            matrix = self.cfg.vocoder_matrix if is_mic else self.cfg.out_vocoder_matrix
            mix = self.cfg.vocoder_mix if is_mic else self.cfg.out_vocoder_mix
            bc_bits = self.cfg.bitcrush_bits if is_mic else self.cfg.out_bitcrush_bits
            st_hz = self.cfg.stutter_hz if is_mic else self.cfg.out_stutter_hz

            self.voc_switch.set_active(voc_on)
            self.atn_switch.set_active(atn_on)
            self.check_follow.set_active(follow)
            if follow:
                self.carrier_row._scale.set_range(-24, 24)  # type: ignore
                self.carrier_row._scale.set_value(c_shift)  # type: ignore
                self.carrier_row._title_lbl.set_text("Carrier Pitch Transposition")  # type: ignore
                self.carrier_row._val_lbl.set_text(f"{c_shift:+d} st")  # type: ignore
            else:
                self.carrier_row._scale.set_range(50, 440)  # type: ignore
                self.carrier_row._scale.set_value(c_hz)  # type: ignore
                self.carrier_row._title_lbl.set_text("Carrier Frequency")  # type: ignore
                self.carrier_row._val_lbl.set_text(f"{c_hz} Hz")  # type: ignore
            self.pitch_row._scale.set_value(int(pshift / 100))  # type: ignore
            self.matrix_row._scale.set_value(matrix)  # type: ignore
            self.voc_mix_row._scale.set_value(mix)  # type: ignore
            self.bitcrush_row._scale.set_value(bc_bits)  # type: ignore
            self.stutter_row._scale.set_value(st_hz)  # type: ignore
            self._clear_active_preset_highlight()

            for p_name, p_data in PRESETS.items():
                match = True
                for k, v in p_data.items():
                    val = getattr(self.cfg, k if is_mic else f"out_{k}", None)
                    if val != v:
                        match = False
                        break
                if match:
                    if p_name in self.preset_buttons:
                        self.preset_buttons[p_name].get_style_context().add_class("active-preset")
                    break

        def _refresh_spatial_ui(self) -> None:
            is_mic = (self.current_spatial_target == "mic")
            d_on = self.cfg.delay_on if is_mic else self.cfg.out_delay_on
            d_ms = self.cfg.delay_ms if is_mic else self.cfg.out_delay_ms
            d_fb = self.cfg.delay_feedback if is_mic else self.cfg.out_delay_feedback
            d_mix = self.cfg.delay_mix if is_mic else self.cfg.out_delay_mix

            r_on = self.cfg.reverb_on if is_mic else self.cfg.out_reverb_on
            r_room = self.cfg.reverb_room if is_mic else self.cfg.out_reverb_room
            r_damp = self.cfg.reverb_damp if is_mic else self.cfg.out_reverb_damp
            r_width = self.cfg.reverb_width if is_mic else self.cfg.out_reverb_width
            r_mix = self.cfg.reverb_mix if is_mic else self.cfg.out_reverb_mix

            self.dly_switch.set_active(d_on)
            self.dly_time_row._scale.set_value(d_ms)  # type: ignore
            self.dly_fb_row._scale.set_value(d_fb)  # type: ignore
            self.dly_mix_row._scale.set_value(d_mix)  # type: ignore

            self.rvb_switch.set_active(r_on)
            self.rvb_room_row._scale.set_value(r_room)  # type: ignore
            self.rvb_damp_row._scale.set_value(r_damp)  # type: ignore
            self.rvb_width_row._scale.set_value(r_width)  # type: ignore
            self.rvb_mix_row._scale.set_value(r_mix)  # type: ignore

        def _refresh_eq_ui(self) -> None:
            if self.current_eq_target == "mic":
                self.eq_lbl.set_text("9-Band Studio Parametric EQ (Microphone Input)")
                self.eq_switch.set_active(self.cfg.eq_on)
                self.eq_post_row._scale.set_value(int(self.cfg.eq_post_gain / 100))  # type: ignore
                for idx, row in enumerate(self.eq_band_rows):
                    val = int(self.cfg.eq_gains[idx] / 100) if idx < len(self.cfg.eq_gains) else 0
                    row._scale.set_value(val)  # type: ignore
            else:
                self.eq_lbl.set_text("9-Band Stereo Parametric EQ (Playback & Speakers)")
                self.eq_switch.set_active(self.cfg.out_eq_on)
                self.eq_post_row._scale.set_value(int(self.cfg.out_eq_post_gain / 100))  # type: ignore
                for idx, row in enumerate(self.eq_band_rows):
                    val = int(self.cfg.out_eq_gains[idx] / 100) if idx < len(self.cfg.out_eq_gains) else 0
                    row._scale.set_value(val)  # type: ignore

        def _clear_active_preset_highlight(self) -> None:
            for btn in self.preset_buttons.values():
                btn.get_style_context().remove_class("active-preset")

        def apply_preset_by_name(self, name: str) -> None:
            p = PRESETS.get(name)
            if not p:
                return

            self._updating_ui = True
            is_mic = (self.current_voice_target == "mic")
            if is_mic:
                for k, v in p.items():
                    if hasattr(self.cfg, k):
                        setattr(self.cfg, k, v)
                self.cfg.vocoder_carrier_hz = p.get("vocoder_carrier_hz", 110)
                self.cfg.vocoder_detune = p.get("vocoder_detune", 20)
                self.cfg.vocoder_attack_ms = p.get("vocoder_attack_ms", 5)
                self.cfg.vocoder_release_ms = p.get("vocoder_release_ms", 30)
                self.cfg.vocoder_follow = p.get("vocoder_follow", True)
                self.cfg.vocoder_pitch_shift = p.get("vocoder_pitch_shift", 0)
                self.cfg.vocoder_matrix = p.get("vocoder_matrix", 0)
                self.cfg.bitcrush_downsample = p.get("bitcrush_downsample", 1)
                self.cfg.bandpass_hpf_hz = p.get("bandpass_hpf_hz", 0)
                self.cfg.bandpass_lpf_hz = p.get("bandpass_lpf_hz", 0)
            else:
                for k, v in p.items():
                    out_k = f"out_{k}"
                    if hasattr(self.cfg, out_k):
                        setattr(self.cfg, out_k, v)
                self.cfg.out_vocoder_carrier_hz = p.get("vocoder_carrier_hz", 110)
                self.cfg.out_vocoder_detune = p.get("vocoder_detune", 20)
                self.cfg.out_vocoder_attack_ms = p.get("vocoder_attack_ms", 5)
                self.cfg.out_vocoder_release_ms = p.get("vocoder_release_ms", 30)
                self.cfg.out_vocoder_follow = p.get("vocoder_follow", True)
                self.cfg.out_vocoder_pitch_shift = p.get("vocoder_pitch_shift", 0)
                self.cfg.out_vocoder_matrix = p.get("vocoder_matrix", 0)
                self.cfg.out_bitcrush_downsample = p.get("bitcrush_downsample", 1)
                self.cfg.out_bandpass_hpf_hz = p.get("bandpass_hpf_hz", 0)
                self.cfg.out_bandpass_lpf_hz = p.get("bandpass_lpf_hz", 0)

            save_config(self.cfg)
            sync_config_to_daemon(self.cfg)
            self._refresh_voice_ui()
            self._clear_active_preset_highlight()
            if name in self.preset_buttons:
                self.preset_buttons[name].get_style_context().add_class("active-preset")
            self._updating_ui = False

    win = AudioStudioWindow()

    def on_destroy(*_: Any) -> None:
        GUI_PID_FILE.unlink(missing_ok=True)
        Gtk.main_quit()

    win.connect("destroy", on_destroy)
    win.show_all()
    Gtk.main()
    GUI_PID_FILE.unlink(missing_ok=True)


# -----------------------------------------------------------------------------
#   CLI Parser
# -----------------------------------------------------------------------------
def main() -> None:
    args = sys.argv[1:]
    cfg = load_config()

    if not args or args[0] in ("--gui", "-g"):
        run_gtk_app()
        return

    match args[0].lower():
        case "--autostart":
            if cfg.enabled:
                start_daemon(cfg)
                print("Dusky Audio DSP autostarted from persisted state (ON).")
            else:
                print("Dusky Audio DSP persisted state is OFF (skipping autostart).")
        case "--on" | "-1" | "on":
            cfg.enabled = True
            save_config(cfg)
            start_daemon(cfg)
            send_desktop_notification("Dusky Audio Studio", "Voice DSP & Noise Cancellation turned ON.")
            print("Dusky Audio DSP turned ON (PipeWire RT Low-Latency).")
        case "--off" | "-0" | "off":
            cfg.enabled = False
            save_config(cfg)
            stop_daemon(restore_defaults=True, cfg=cfg)
            send_desktop_notification("Dusky Audio Studio", "Voice DSP turned OFF (Direct Hardware Bypass).")
            print("Dusky Audio DSP turned OFF (Direct Hardware Bypass).")
        case "--toggle" | "-t" | "toggle":
            is_on = bool(get_daemon_pid())
            if is_on:
                cfg.enabled = False
                save_config(cfg)
                stop_daemon(restore_defaults=True, cfg=cfg)
                send_desktop_notification("Dusky Audio Studio", "Voice DSP turned OFF (Direct Hardware Bypass).")
                print("Dusky Audio DSP turned OFF.")
            else:
                cfg.enabled = True
                save_config(cfg)
                start_daemon(cfg)
                send_desktop_notification("Dusky Audio Studio", "Voice DSP & Noise Cancellation turned ON.")
                print("Dusky Audio DSP turned ON.")
        case "--reset" | "--reset-all" | "-r":
            cfg = AudioConfig(enabled=cfg.enabled, source=cfg.source, sink=cfg.sink)
            save_config(cfg)
            sync_config_to_daemon(cfg)
            print("All audio DSP settings reset to factory defaults.")
        case "--reset-voice":
            clean = PRESETS["Natural Clean"]
            for k, v in clean.items():
                if hasattr(cfg, k):
                    setattr(cfg, k, v)
            cfg.vocoder_carrier_hz = 110
            cfg.vocoder_detune = 20
            cfg.vocoder_attack_ms = 5
            cfg.vocoder_release_ms = 30
            cfg.vocoder_follow = True
            cfg.vocoder_pitch_shift = 0
            cfg.vocoder_matrix = 0
            cfg.vocoder_mix = 0
            save_config(cfg)
            sync_config_to_daemon(cfg)
            print("Voice FX reset to Natural Clean.")
        case "--reset-eq":
            cfg.eq_on = False
            cfg.eq_post_gain = 0
            cfg.eq_gains = [0, 0, 0, 0, 0, 0, 0, 0, 0]
            cfg.out_eq_on = False
            cfg.out_eq_post_gain = 0
            cfg.out_eq_gains = [0, 0, 0, 0, 0, 0, 0, 0, 0]
            save_config(cfg)
            sync_config_to_daemon(cfg)
            print("Microphone & Playback Parametric EQ reset to Flat 0 dB.")
        case "--out-eq" if len(args) > 1:
            action = args[1].lower()
            if action == "on":
                cfg.out_eq_on = True
                save_config(cfg)
                send_daemon_cmd("OUT_EQ 1")
                print("Playback Parametric EQ: ON")
            elif action == "off":
                cfg.out_eq_on = False
                save_config(cfg)
                send_daemon_cmd("OUT_EQ 0")
                print("Playback Parametric EQ: OFF")
            elif action == "toggle":
                cfg.out_eq_on = not cfg.out_eq_on
                save_config(cfg)
                send_daemon_cmd(f"OUT_EQ {1 if cfg.out_eq_on else 0}")
                print(f"Playback Parametric EQ: {'ON' if cfg.out_eq_on else 'OFF'}")
            else:
                print("Usage: --out-eq <on|off|toggle>", file=sys.stderr)
        case "--reset-spatial":
            cfg.delay_on = False
            cfg.delay_ms = 250
            cfg.delay_feedback = 35
            cfg.delay_mix = 30
            cfg.reverb_on = False
            cfg.reverb_room = 70
            cfg.reverb_damp = 50
            cfg.reverb_width = 80
            cfg.reverb_mix = 35
            save_config(cfg)
            sync_config_to_daemon(cfg)
            print("Delay and Reverb reset to default bypass.")
        case "--status" | "-s" | "status":
            pid = get_daemon_pid()
            tele = fetch_telemetry_from_daemon()
            if pid:
                tele_str = f", VAD: {int(tele.vad_prob * 100)}%, Noise Reduction: {tele.noise_reduction_db:.1f} dB" if tele else ""
                print(f"ON (PID {pid}, Suppression: {cfg.aggressiveness}%, Volume: {cfg.volume}%, Vocoder: {'ON' if cfg.vocoder_on else 'OFF'}{tele_str})")
            else:
                print("OFF")
        case ("--preset" | "-p") if len(args) > 1:
            p_name = " ".join(args[1:])
            match_key = None
            for k in PRESETS:
                if k.lower() == p_name.lower():
                    match_key = k
                    break
            if match_key:
                for k, v in PRESETS[match_key].items():
                    if hasattr(cfg, k):
                        setattr(cfg, k, v)
                save_config(cfg)
                sync_config_to_daemon(cfg)
                print(f"Applied Character Preset: {match_key}")
            else:
                print(f"Preset '{p_name}' not found. Available: {', '.join(PRESETS.keys())}")
        case ("--set-source" | "--source" | "--src") if len(args) > 1:
            val = " ".join(args[1:])
            cfg.source = val
            save_config(cfg)
            target = resolve_hardware_source(val)
            send_daemon_cmd(f"SRC {target}")
            print(f"Set Input Microphone Source to '{val}' (target: {target})")
        case ("--set-sink" | "--sink") if len(args) > 1:
            val = " ".join(args[1:])
            cfg.sink = val
            save_config(cfg)
            target = resolve_hardware_sink(val)
            send_daemon_cmd(f"SINK_TGT {target}")
            print(f"Set Output Playback Device to '{val}' (target: {target})")
        case ("--set-agg" | "--agg") if len(args) > 1:
            try:
                val = max(0, min(100, int(args[1])))
                cfg.aggressiveness = val
                save_config(cfg)
                send_daemon_cmd(f"AGG {val * 10}")
                print(f"Set Input Noise Reduction Aggressiveness to {val}%")
            except ValueError:
                print("Invalid value for aggressiveness (0-100).", file=sys.stderr)
        case ("--set-vol" | "--vol") if len(args) > 1:
            try:
                val = max(0, min(200, int(args[1])))
                cfg.volume = val
                save_config(cfg)
                send_daemon_cmd(f"VOL {val * 10}")
                print(f"Set Output Gain to {val}%")
            except ValueError:
                print("Invalid value for volume (0-200).", file=sys.stderr)
        case "--noise" if len(args) > 1:
            action = args[1].lower()
            if action == "on":
                cfg.rnnoise_on = True
                save_config(cfg)
                send_daemon_cmd("RNN 1")
                print("Input Noise Cancellation: ON")
            elif action == "off":
                cfg.rnnoise_on = False
                save_config(cfg)
                send_daemon_cmd("RNN 0")
                print("Input Noise Cancellation: OFF")
            elif action == "toggle":
                cfg.rnnoise_on = not cfg.rnnoise_on
                save_config(cfg)
                send_daemon_cmd(f"RNN {1 if cfg.rnnoise_on else 0}")
                print(f"Input Noise Cancellation: {'ON' if cfg.rnnoise_on else 'OFF'}")
            else:
                print("Usage: --noise <on|off|toggle>", file=sys.stderr)
        case "--noise-state" | "--noise-status":
            print("yes" if cfg.rnnoise_on else "no")
        case "--out-noise-state" | "--out-noise-status":
            print("yes" if cfg.out_rnnoise_on else "no")
        case "--get-agg":
            print(cfg.aggressiveness)
        case "--get-out-agg":
            print(cfg.out_aggressiveness)
        case "--out-noise" if len(args) > 1:
            action = args[1].lower()
            if action == "on":
                cfg.out_rnnoise_on = True
                save_config(cfg)
                send_daemon_cmd("OUT_NOISE 1")
                print("Output Noise Cancellation: ON")
            elif action == "off":
                cfg.out_rnnoise_on = False
                save_config(cfg)
                send_daemon_cmd("OUT_NOISE 0")
                print("Output Noise Cancellation: OFF")
            elif action == "toggle":
                cfg.out_rnnoise_on = not cfg.out_rnnoise_on
                save_config(cfg)
                send_daemon_cmd(f"OUT_NOISE {1 if cfg.out_rnnoise_on else 0}")
                print(f"Output Noise Cancellation: {'ON' if cfg.out_rnnoise_on else 'OFF'}")
            else:
                print("Usage: --out-noise <on|off|toggle>", file=sys.stderr)
        case ("--set-out-agg" | "--out-agg") if len(args) > 1:
            try:
                val = max(0, min(100, int(args[1])))
                cfg.out_aggressiveness = val
                save_config(cfg)
                send_daemon_cmd(f"OUT_AGG {val * 10}")
                print(f"Set Output Noise Reduction Aggressiveness to {val}%")
            except ValueError:
                print("Invalid value for output aggressiveness (0-100).", file=sys.stderr)
        case "--help" | "-h":
            print(
                """Usage: dusky_audio_studio.py [COMMAND]

Commands:
  --gui, -g                 Launch complete GTK3 Audio Studio window (default)
  --toggle, -t              Toggle Audio DSP / Noise Cancellation ON / OFF
  --on                      Turn Audio DSP ON
  --off                     Turn Audio DSP OFF
  --reset, -r               Reset all audio settings to clean factory defaults
  --reset-voice             Reset voice character effects to Natural Clean
  --reset-eq                Reset 9-Band EQ to Flat 0 dB
  --reset-spatial           Reset Delay & Reverb to clean bypass
  --status, -s              Print current status and live telemetry
  --preset, -p <name>       Apply voice preset (e.g. "Daft Punk", "Darth Vader", "Sci-Fi Alien")
  --set-source <node>       Set hardware capture microphone source
  --set-sink <node>         Set physical playback output device (speakers/headphones)
  --set-agg <0-100>         Set input RNNoise suppression aggressiveness (0 to 100%)
  --set-vol <0-200>         Set microphone volume/gain (0 to 200%)
  --out-noise <on|off|toggle>  Toggle output noise cancellation (Two-Way)
  --set-out-agg <0-100>     Set output RNNoise suppression aggressiveness (0 to 100%)
  --help, -h                Show this help message

Available Voice Character Presets:
  """
                + ", ".join(f'"{k}"' for k in PRESETS.keys())
            )
        case _:
            print(f"Unknown command: {args[0]}. Run with --help for usage.")


if __name__ == "__main__":
    main()
