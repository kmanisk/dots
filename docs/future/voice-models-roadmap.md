# Future Roadmap: Real-Time AI / Neural Voice Models & Voice Conversion

**Target Architecture:** CachyOS rolling · Intel i5-13450HX + RTX 5050 Mobile (Blackwell `sm_120`) · PipeWire 1.6+  
**Current Production Baseline:** 27 in-chain PipeWire LADSPA voice models running directly inside `40-mic.conf` (`ghelper-audio`) with DPDFNet neural denoising (45 dB floor), 80 Hz HPF, broadcast EQ, and anti-shout limiting.

---

## 1. Production Context & Roadmap Scope

MicStudio v1.0.0 successfully provides 27 in-chain voice models using native LADSPA plugins (RubberBand formant-preserving pitch transposition, SWH RingMod, Decimator, Flanger, Delayorama, and Biquad filters). These execute with sub-millisecond switching latency and zero CPU/RAM daemon overhead.

This roadmap documents exploratory research for **Phase 2: Real-Time Neural Voice Cloning / RVC Conversion** leveraging the RTX 5050 Mobile Tensor Cores for hyper-realistic voice conversion without robotic timbre artifacts.

---

## 2. Voice Model Timbres & Archetypes

The target character profiles and sonic archetypes:

| Preset / Model | Target Sonic Characteristics | Processing Archetype | Current Production Status |
| :--- | :--- | :--- | :--- |
| **Natural Clean** | Transparent broadcast clarity, zero background fan noise (45 dB suppression), leveled speech dynamics. | DPDFNet + 7-Stage EQ & Limiter | **Active Production Default** |
| **Deep Voice** | Warm, authoritative broadcast radio announcer; deep fundamental resonance without phase artifacts. | Formant-preserving pitch drop (-4 st) | **Active in MicStudio v1.0.0** |
| **Darth Vader** | Heavy mechanical breathing resonance, dark resonant timbre, subtle sub-harmonic synthesis. | Pitch drop (-6 st) + ring modulation | **Active in MicStudio v1.0.0** |
| **Robot** | Fast ring modulation delivering a synthetic metallic cadence. | SWH RingMod carrier modulation | **Active in MicStudio v1.0.0** |
| **Helldiver Radio** | Bandpass military comms with aggressive limiter punch and simulated RF choke. | Sharp 400 Hz–3.5 kHz bandpass + Limiter | **Active in MicStudio v1.0.0** |
| **Walkie Talkie** | Tactical VHF/UHF military radio comms with squelch distortion and static. | Bandpass + 12-bit lo-fi quantizer | **Active in MicStudio v1.0.0** |
| **Alien Choir** | Extraterrestrial multi-tonal frequency modulation with ambient shimmer. | Harmonic shimmer + detuned chorus | **Active in MicStudio v1.0.0** |
| **Stutter Glitch** | Rhythmic DSP gate chop effect creating synthetic stuttered vocals. | Sliced square-wave gating (8 Hz) | **Active in MicStudio v1.0.0** |

---

## 3. Next-Gen Technical Pathways for Neural Conversion

To achieve natural, artifact-free voice conversion in real time without interfering with competitive gaming framerates:

### Option A: Real-Time RVC on RTX 5050 Tensor Cores (ONNX Runtime / TensorRT)
- **Engine:** Real-time ONNX Runtime running on CUDA / TensorRT offload (`nvidia` runtime).
- **Latency Target:** < 20 ms buffer latency.
- **Hardware Profile:** Leverage RTX 5050 Mobile Tensor Cores via dynamic GPU offloading (`prime-run` or direct CUDA stream) without disturbing desktop power state when idle.
- **Capability:** True voice cloning and timbre replacement (preserving user pitch inflection while adopting target vocal tract harmonics).

### Option B: Formant-Preserving Phase Vocoder (RubberBand v3 / Custom Rust STFT)
- **Engine:** Modern WSOLA or Phase Vocoder with independent pitch and formant scaling.
- **Advantage:** Low CPU footprint (< 1% on Intel i5-13450HX), zero GPU dependency, < 10 ms latency.
- **Capability:** Refines pitch shifts to completely eliminate the "chipmunk" or "slurred mud" artifacts.

### Option C: DDSP (Differentiable Digital Signal Processing)
- **Engine:** Lightweight neural pitch/timbre synthesis trained specifically on target vocal models.
- **Advantage:** Extremely compact ONNX models (~5 MB) that execute in real time on CPU or GPU.
