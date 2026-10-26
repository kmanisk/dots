# Real-Time AI Interview Assistant & Screen Cloaking Architecture

**Target Platforms:** Windows 11 & CachyOS (Sway Wayland)  
**Target Hardware:** ASUS TUF Gaming F16 (Intel Core i5-13450HX, NVIDIA GeForce RTX 5050 Mobile 8 GB GDDR7, 16 GB DDR5)  
**Primary Application:** Meetingly AI Desktop Copilot  
**Local Inference Engine:** Ollama / `llama.cpp` (Detailed benchmarks in [Local LLM Roadmap](localllm.md))

---

## 1. System Overview & Architecture

Meetingly AI operates as an undetectable real-time assistant during job interviews and technical evaluations. The architecture captures both sides of a call (candidate microphone + interviewer system audio), generates instant responses via local or cloud AI models, and uses OS-level display isolation to keep the assistant invisible during live screen sharing.

```
+-------------------------------------------------------------------------------+
|                             Meeting / Call Audio                              |
|                       (Zoom, Google Meet, Teams, Slack)                       |
+---------------------------------------+---------------------------------------+
                                        |
                 WASAPI / PipeWire Loopback + Mic Input
                                        v
+-------------------------------------------------------------------------------+
|                                Meetingly AI                                   |
|   - Real-time on-device speech recognition (NVIDIA Nemotron / Whisper local)  |
|   - Candidate ("You") vs Interviewer ("Them") dual-stream transcript          |
|   - Screen cloaking layer (Win32 WDA on Windows / Virtual Headless on Sway)   |
+---------------------------------------+---------------------------------------+
                                        |
                         HTTP POST /v1 (Local or Remote)
                                        v
+-------------------------------------------------------------------------------+
|                             Inference Engine                                  |
|   [Local Primary]: Ollama on RTX 5050 (Qwen3.5-9B / Qwen3-8B in GDDR7 VRAM)   |
|   [Cloud Fallback]: OpenRouter API (Live web search for up-to-date lookups)   |
+-------------------------------------------------------------------------------+
```

---

## 2. Windows Interview Setup Module

### 2.1 Installation
1. Download the Windows installer executable from the official site:
   [https://meetinglyai.com/download/Meetingly-Setup.exe](https://meetinglyai.com/download/Meetingly-Setup.exe)
2. Run `Meetingly-Setup.exe`.
3. The application will launch and minimize to the Windows notification tray area.

### 2.2 WASAPI Dual-Stream Audio Pipeline
Meetingly interfaces natively with the Windows Audio Session API (WASAPI):
- **Candidate Microphone Stream**: Captures input directly from the internal laptop microphone array or external headset.
- **Interviewer Call Audio Stream**: Uses WASAPI Loopback Capture to record audio from the default playback device directly from the digital mix buffer before DAC conversion. This guarantees full clarity without picking up ambient room acoustics.

### 2.3 Win32 Screen Cloaking (`WDA_EXCLUDEFROMCAPTURE`)
On Windows 10/11, Meetingly utilizes the Desktop Window Manager (DWM) API:

```c
SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE);
```

- **Mechanism**: The OS composites the window normally for the physical display panel, but skips the window surface during any DirectX Desktop Duplication, Windows.Graphics.Capture, or BitBlt capture request.
- **Operational Advantage**: The candidate can share their **Entire Desktop / Screen** in Zoom, Google Meet, Microsoft Teams, or Discord. Remote participants receive a completely clean screen feed without the overlay.

### 2.4 Connecting Meetingly to Local Ollama on Windows
1. Open Meetingly settings from the system tray icon.
2. Select **Use your own API key...** or **AI Provider**.
3. Configure the connection parameters:
   - **Provider**: Select `Ollama` (or `OpenAI-Compatible Custom Endpoint`).
   - **API Base URL**: `http://127.0.0.1:11434/v1`
   - **API Key**: Enter `ollama` (placeholder string required by client headers).
   - **Model Name**: Enter `qwen3.5:9b` or `qwen2.5:7b`.
4. Save settings and test prompt generation.

---

## 3. Linux / Sway Wayland Setup Module

### 3.1 Local Application Deployment
- **Binary Directory**: Extracted into [`~/.local/opt/meetingly/app/`](file:///home/onyx/.local/opt/meetingly/app/).
- **Executable Launcher**: Available at [`~/.local/bin/meetingly`](file:///home/onyx/.local/bin/meetingly) with automatic Ozone Wayland negotiation (`--ozone-platform-hint=auto`).
- **Desktop Entry**: Configured at [`~/.local/share/applications/meetingly.desktop`](file:///home/onyx/.local/share/applications/meetingly.desktop).

### 3.2 PipeWire Dual-Stream Audio Configuration
- **Microphone**: Select `ghelper-audio` (internal laptop microphone array with neural denoising).
- **Interviewer / Call Audio**: Select the PipeWire monitor source of your active output (e.g. `alsa_output.pci-0000_00_1f.3.analog-stereo.monitor` or Dolby Speaker monitor).

### 3.3 Sway Window Management Rules
Managed via chezmoi in [`~/.config/sway/config.d/30-window-rules.conf`](file:///home/onyx/.config/sway/config.d/30-window-rules.conf):

```ini
for_window [app_id="(?i)^meetingly.*"] floating enable, sticky enable, border pixel 1
for_window [class="(?i)^meetingly.*"] floating enable, sticky enable, border pixel 1
# Tile wl-mirror without borders on eDP-1 so floating Meetingly floats strictly on top
for_window [app_id="^wl-mirror$"] border none, move to output eDP-1
```

### 3.4 Sway Screen Cloaking via Virtual Headless Display
Because Wayland intentionally lacks an arbitrary per-surface window-hiding API (`WDA_EXCLUDEFROMCAPTURE`) due to security boundaries (KeePassXC Issue #10476), use the virtual headless display architecture for unleakable screen sharing:

```
[ Physical Display: eDP-1 ]                    [ Virtual Display: HEADLESS-1 ]
+---------------------------------------+      +-------------------------------+
| - Displays tiled wl-mirror (no border)|      | - Assigned to Workspaces 1-9  |
| - Meetingly overlay floats ON TOP     |      | - Houses IDE, Browser, Term   |
|   (Rendered only to physical monitor) |      |                               |
+---------------------------------------+      +---------------+---------------+
                                                               |
                                                  PipeWire Captures ONLY This
                                                               |
                                                               v
                                                    [ Screen Share Stream ]
```

1. **Create Virtual Output & Match Physical Panel Resolution Dynamically**:
   ```bash
   read -r W H < <(swaymsg -t get_outputs | jq -r '.[] | select(.name=="eDP-1") | "\(.current_mode.width) \(.current_mode.height)"')
   HEADLESS_OUT=$(swaymsg -t get_outputs | jq -r '.[].name | select(startswith("HEADLESS-"))' | head -n1)
   [[ -z "$HEADLESS_OUT" ]] && { swaymsg create_output; HEADLESS_OUT=$(swaymsg -t get_outputs | jq -r '.[].name | select(startswith("HEADLESS-"))' | head -n1); }
   swaymsg output "$HEADLESS_OUT" resolution "${W}x${H}" position "$W" 0
   ```
2. **Assign Workspaces**: Direct working workspaces (browser, VS Code, terminal) to `$HEADLESS_OUT`.
3. **Return Focus to eDP-1**:
   ```bash
   swaymsg focus output eDP-1 2>/dev/null || swaymsg workspace 2
   ```
4. **Mirror Virtual Display to Physical Panel (Tiled, Not Fullscreen)**:
   ```bash
   wl-mirror "$HEADLESS_OUT" > /dev/null 2>&1 &
   ```
   *Note: `wl-mirror` is tiled borderless rather than fullscreened so that Sway's floating layer (Meetingly) renders strictly on top.*
5. **Overlay Pinning**: Meetingly is pinned to physical display `eDP-1` floating over the tiled mirror.
6. **Screen Share Selection**: When Zoom/Google Meet prompts for screen share, select `$HEADLESS_OUT`. Meetingly does not exist in `$HEADLESS_OUT`'s memory buffer, keeping the feed completely clean.
7. **Teardown**:
   ```bash
   pkill -x wl-mirror || true
   swaymsg workspace 1 output eDP-1
   for out in $(swaymsg -t get_outputs | jq -r '.[].name | select(startswith("HEADLESS-"))'); do
       swaymsg output "$out" unplug || true
   done
   ```

---

## 4. Local Model Integration Summary

For complete benchmarks, quantization sizing, and MoE offload details, see [`localllm.md`](localllm.md).

### Recommended Interview Models for RTX 5050 (8 GB GDDR7)

| Purpose | Model | Location | Expected Speed | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| **Instant Responses** | `qwen3.5:4b` | 100% VRAM (~4 GB) | **70–90 tok/s** | Sub-second latency; ideal for quick Q&A |
| **Primary Daily Driver** | `qwen3.5:9b` | 100% VRAM (~7 GB) | **40–50 tok/s** | **Current sweet spot**; high coding & reasoning depth |
| **Heavy MoE Reasoning** | `qwen3.6:35b-a3b` | Hybrid Offload | **20–30+ tok/s** | **Requires 32 GB RAM upgrade** (Q4 quant with CPU-processed experts) |

---

## 5. Hybrid Knowledge Retrieval Strategy

Local models operate strictly offline based on training weights. When interviews require current-year libraries, live documentation, or specific company research:

- **Local Mode (Default)**: Technical questions, DSA coding, and behavioral STAR stories are handled locally by Ollama. Latency is ~400 ms with complete privacy.
- **Cloud Fallback (On Demand)**: Configure OpenRouter in Meetingly settings pointing to a web-search model (e.g. `perplexity/sonar` or `openai/gpt-4o-mini`). Switching requires a single toggle in Meetingly's provider tray.
