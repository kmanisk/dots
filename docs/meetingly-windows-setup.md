# Meetingly AI and Local Ollama Setup Guide for Windows

This document details the configuration of **Meetingly AI** paired with local **Ollama** LLM inference on Windows for an **ASUS TUF Gaming F16 (Intel Core i5-13450HX, NVIDIA GeForce RTX 5050 Mobile 8 GB VRAM, 16 GB DDR5 RAM)**.

---

## Architecture Overview

```
                      +------------------------------------+
                      |         Video Call / Meeting       |
                      |  (Zoom, Teams, Google Meet, Slack) |
                      +-----------------+------------------+
                                        |
                 WASAPI Loopback Capture| Mic Input Capture
                                        v
                      +------------------------------------+
                      |            Meetingly AI            |
                      |     (Windows WASAPI Audio Engine)  |
                      |     - On-device speech recognition |
                      |     - Dual-stream (You vs Them)    |
                      |     - Window cloaking (WDA)        |
                      +-----------------+------------------+
                                        |
                          HTTP POST /v1 | Local Inference
                                        v
                      +------------------------------------+
                      |            Ollama Core             |
                      |        http://localhost:11434      |
                      |     - GPU: RTX 5050 (8 GB VRAM)    |
                      |     - Context: Q4 quantized models |
                      +------------------------------------+
```

---

## Hardware Budget and VRAM Constraints

In real-time interview scenarios, inference latency must remain sub-second. When a model exceeds physical VRAM (8 GB on the RTX 5050), CUDA offloads remaining layers or KV-cache pages into system memory (DDR5) via PCIe. This causes token generation throughput to plummet from 40+ tokens/second down to 4-6 tokens/second, rendering live suggestions useless.

### VRAM Allocation Rule

```
Total VRAM: 8,192 MB
- Windows DWM and Display overhead: ~800 MB
- Meetingly on-device STT (Nemotron / Whisper): ~1,000 MB
- Available budget for Ollama: ~6,200 MB to 6,400 MB
```

### Quantized Model Suitability Table (Q4_K_M)

| Model Identifier | Architecture | VRAM Footprint | Avg Throughput | Recommendation |
| :--- | :--- | :--- | :--- | :--- |
| `qwen2.5:7b` / `qwen3:8b` | Dense 7B-8B | ~5.8 GB - 6.5 GB | ~38 - 45 tok/s | Recommended: Primary all-rounder for technical, coding, and behavioral interviews |
| `qwen2.5:3b` / `qwen3.5:4b` | Dense 3B-4B | ~3.2 GB - 3.8 GB | ~70 - 80 tok/s | Recommended: Ultra-low latency for instant short responses |
| `lfm2.5:8b` | MoE 8B (1.5B active) | ~5.2 GB - 5.6 GB | ~100+ tok/s | Recommended: High token throughput via sparse mixture-of-experts |
| `llama3.1:8b` | Dense 8B | ~5.9 GB - 6.4 GB | ~40 - 44 tok/s | Supported: Reliable baseline fallback |
| `gemma2:2b` / `gemma4:e4b` | Dense 2.6B-4.5B | ~2.8 GB - 4.2 GB | ~55 - 65 tok/s | Supported: Lightweight reasoning with low memory footprint |
| `mistral-nemo:12b` | Dense 12B | ~9.2 GB | ~5 - 8 tok/s | Prohibited: Exceeds 8 GB VRAM limit; triggers system RAM paging |
| `phi4:14b` | Dense 14B | ~10.5 GB | ~3 - 5 tok/s | Prohibited: Severe memory bottleneck |

---

## Step 1: Install and Configure Ollama on Windows

### 1. Installation
1. Download the official Windows installer from [ollama.com/download/windows](https://ollama.com/download/windows).
2. Execute `OllamaSetup.exe` and complete the installation.
3. Verify that the Ollama service starts automatically in the system tray.

### 2. Configure Windows Environment Variables
To ensure Ollama binds correctly and leverages NVIDIA Tensor cores and Flash Attention, configure system environment variables:

1. Open PowerShell as Administrator.
2. Run the following commands to configure persistent system-wide variables:

```powershell
[System.Environment]::SetEnvironmentVariable('OLLAMA_HOST', '127.0.0.1:11434', 'Machine')
[System.Environment]::SetEnvironmentVariable('OLLAMA_ORIGINS', '*', 'Machine')
[System.Environment]::SetEnvironmentVariable('OLLAMA_FLASH_ATTENTION', '1', 'Machine')
[System.Environment]::SetEnvironmentVariable('OLLAMA_NUM_PARALLEL', '1', 'Machine')
```

3. Restart the Ollama application from the Windows system tray to apply the variables.

### 3. Pull Selected Models
In PowerShell or Windows Terminal, execute:

```powershell
# Primary technical and behavioral model
ollama pull qwen2.5:7b

# Fast response fallback model
ollama pull qwen2.5:3b
```

Verify GPU acceleration and layer offloading:

```powershell
ollama run qwen2.5:7b "Confirm you are loaded onto NVIDIA RTX 5050"
```

In a second PowerShell window, check VRAM consumption:

```powershell
nvidia-smi
```

Ensure `ollama_llama_server.exe` appears under Processes and utilizes the dedicated NVIDIA GPU rather than Intel UHD Graphics.

---

## Step 2: Install Meetingly AI on Windows

1. Download the Windows installer executable from the official site:
   [https://meetinglyai.com/download/Meetingly-Setup.exe](https://meetinglyai.com/download/Meetingly-Setup.exe)
2. Run `Meetingly-Setup.exe`.
3. The application will launch and minimize to the Windows notification tray area.

---

## Step 3: Configure Windows Audio Routing

Unlike Linux which requires manual PipeWire monitor selection, Windows uses WASAPI (Windows Audio Session API) loopback capture.

1. Right-click the Windows Volume icon in the taskbar and select **Sound settings**.
2. Confirm your **Output** device (e.g., Speakers Realtek Audio or Headphone Realtek Audio).
3. Confirm your **Input** device (e.g., Microphone Array Realtek Audio).
4. Launch Meetingly AI settings:
   - **Microphone**: Select your active laptop microphone array or external headset mic.
   - **Speaker / System Audio**: Select **Default System Audio (WASAPI Loopback)**.
5. Test by playing any YouTube video or audio file. Confirm that the audio is actively transcribed in the "Them" stream within Meetingly.

---

## Step 4: Connect Meetingly AI to Local Ollama

1. Open Meetingly AI.
2. Click the Meetingly tray icon or open the sidebar settings panel.
3. Select **Use your own API key...** or **AI Provider**.
4. Configure the connection parameters:
   - **Provider**: Select `Ollama` (or `OpenAI-Compatible Custom Endpoint`).
   - **API Base URL**: `http://127.0.0.1:11434/v1`
   - **API Key**: Enter `ollama` (placeholder string required by client headers).
   - **Model Name**: Enter `qwen2.5:7b` (or `qwen2.5:3b`).
5. Save settings.
6. Trigger a test prompt to verify instant local responses.

---

## Step 5: Screen-Share Cloaking on Windows

On Windows 10/11, Meetingly utilizes the native Win32 API:
```c
SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE);
```

### Operational Behavior
- The Meetingly overlay window is rendered on top of your desktop and applications.
- Screen capture software (Zoom, Microsoft Teams, Google Meet, Discord, OBS Studio) automatically bypasses the window.
- Even if you share your **entire monitor / screen** on Windows, remote viewers will see the background application without the overlay.

>[!NOTE]
> Hardware-accelerated capture hooks in specific proprietary proctoring software (e.g., Respondus LockDown Browser, Proctorio) use kernel drivers or low-level hooks. Meetingly is designed for ordinary workplace and technical interviews (Zoom/Teams/Meet), not proctored testing environments.

---

## Step 6: Handling Knowledge Cutoff and Live Web Search

A local Ollama instance runs offline and cannot search the live internet. Its responses are limited to its training data cutoff.

### Hybrid Strategy
- **Coding, DSA, and Standard Technical Questions**: Keep Ollama active (`qwen2.5:7b`). Response latency is optimal (~400 ms time-to-first-token), completely free, and private.
- **Company-Specific, Current-Year, or Live Documentation Lookups**: If questions require live web information:
  1. Open Meetingly AI Provider settings.
  2. Switch to **OpenRouter** or **OpenAI**.
  3. Use an OpenRouter endpoint with an online-enabled model (e.g., `perplexity/sonar`, `openai/gpt-4o-mini`).
  4. Paste an OpenRouter API key.
