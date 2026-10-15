# Jio 5G Tethering & YouTube Video Streaming Resolution

## 1. Problem Description
When browsing or watching YouTube on Chromium/Brave over **Jio 5G USB tethering**, video playback repeatedly freezes/buffers (e.g. stalled buffer bar at 1080p/4K), even though generic network speed tests show high speeds (100–300+ Mbps).

---

## 2. Root Cause Analysis
1. **QUIC / HTTP/3 over UDP Port 443:**
   - By default, Chromium-based browsers (Brave, Chrome) attempt to stream YouTube from Google Global Cache (GGC) nodes via **QUIC (HTTP/3 over UDP port 443)**.
   - Jio 5G cellular uplink uses GTP-U encapsulation with a path MTU ceiling of **1372 bytes**.
   - Intermediate cellular middleboxes and CGNAT on Jio routinely drop, rate-limit, or fragment high-throughput UDP traffic.
   - Because QUIC operates over UDP without standard kernel TCP PMTU recovery, dropped UDP video fragments cause the YouTube HTML5 player to stall in an infinite buffer cycle.

2. **TCP vs UDP on Jio 5G:**
   - Over standard **TCP (HTTP/2)**, the Linux kernel's Path MTU Probing (`net.ipv4.tcp_mtu_probing = 1`), UFW TCP MSS clamping (`-j TCPMSS --clamp-mss-to-pmtu`), and BBR congestion control dynamically negotiate and pace packet sizes to fit within the 1372-byte bearer.
   - Over **UDP (QUIC)**, no kernel MSS clamping exists, making video streams fragile to carrier-side UDP packet drops.

---

## 3. Verified Resolution
Disable QUIC in browser flags to force Chromium/Brave to stream video exclusively over **HTTP/2 (TCP)**.

### Implementation:
Added `--disable-quic` to both browser flag files:
- `~/.config/brave-flags.conf`
- `~/.config/brave-origin-flags.conf`

```text
--ignore-gpu-blocklist
--enable-gpu-rasterization
--enable-zero-copy
--use-gl=angle
--use-angle=gl
--enable-features=VaapiVideoDecodeLinuxGL,VaapiVideoDecoder,CanvasOopRasterization,SmoothScrolling
--disable-features=VulkanVideoDecoder,Vulkan
--password-store=basic
--enable-blink-features=MiddleClickAutoscroll
--disable-quic
--test-type
```

### Verification & Outcome:
- Brave automatically switches to HTTP/2 over TCP for `*.googlevideo.com` and Jio GGC edge nodes.
- YouTube video chunks stream at full line speed (100–300+ Mbps) without buffer freezes.
- Managed and version-controlled via chezmoi.
