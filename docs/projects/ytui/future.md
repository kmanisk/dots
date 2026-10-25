# ytui & ytui-gui: Future Roadmap & SmartTube Architecture

## 1. Executive Summary

This document specifies the technical roadmap and streaming architecture for `ytui` and `ytui-gui`, bridging terminal workflows and modern desktop GUI capabilities while maintaining a zero-bloat, shared native Rust core (`ytui-core`).

The design draws architectural inspiration from SmartTube (Android TV), adapting its chunked media streaming, aggressive rate-limit mitigation, and video metadata pipelines for Linux workstations.

---

## 2. SmartTube Architectural Audit & Parity Matrix

SmartTube achieves playback stability on Android TV by bypassing standard web client limitations through ExoPlayer custom data sources and direct InnerTube endpoints. Below is the parity audit for `ytui-core`, `ytui` (TUI), and `ytui-gui` (GTK4 + libmpv):

| Capability | SmartTube Mechanism | ytui Implementation | Current Status | Target Milestone |
| :--- | :--- | :--- | :--- | :--- |
| **Stream Extraction** | Custom InnerTube client rotation (`ANDROID`, `TV_EMBEDDED`, `IOS`) | `InnerTubeBackend` + `YtDlpBackend` fallback | **Production** | Milestone 1 (Complete) |
| **Bandwidth Throttle Bypass** | InnerTube Android stream parsing (`ratebypass=yes`) | `ytdl-raw-options: extractor-args=youtube:player_client=android,web` | **Production** | Milestone 1 (Complete) |
| **Stream Auto-Reconnect** | OkHttp / Cronet connection pooling with auto-retry | `demuxer-lavf-o: reconnect=1,reconnect_streamed=1,reconnect_delay_max=5` | **Production** | Milestone 1 (Complete) |
| **SponsorBlock Integration** | Native REST API parser with segment skip actions | `SponsorBlockClient` + `SponsorBlockTracker` with cooldown | **Production** | Milestone 1 (Complete) |
| **Return YouTube Dislike** | RYD API lookup on video load | `InnerTubeBackend::watch()` integrates RYD REST endpoint | **Production** | Milestone 1 (Complete) |
| **Watch History Sync** | Periodic watchtime pings to `/api/stats/watchtime` | `mark_watched()` sends `ping_playback` and `ping_watchtime` | **Production** | Milestone 1 (Complete) |
| **Resume Playback** | `thumbnailOverlayResumePlaybackRenderer` parsing | `VideoCard::resolved_resume_sec()` passes `start={sec}` to mpv | **Production** | Milestone 1 (Complete) |
| **Hardware Video Decode** | Android MediaCodec NDK | `hwdec=auto-safe` (NVDEC / Vulkan / VA-API) | **Production** | Milestone 1 (Complete) |
| **Vim Keyboard Workflow** | D-pad remote mapping | Full Vim chords (`j`, `k`, `h`, `l`, `gg`, `G`, `/`, `r`, `1`-`5`) | **Production** | Milestone 1 (Complete) |
| **SABR / PoToken Bypass** | JavaScript challenge solver for SABR streams | Extractor-args visitor data + yt-dlp node execution | **Partial** | Milestone 2 |
| **Native Rust Streaming Engine** | OkHttp custom chunk pre-fetching DataSource | Embedded libmpv demuxer (512 MiB cache, 60s readahead) | **Partial** | Milestone 3 |
| **Miniplayer / Floating Mode** | Android PiP (Picture-in-Picture) | Wayland/X11 floating window rule via Sway/i3 | **Planned** | Milestone 2 |
| **Multi-Account Switching** | Account profile list with OAuth refresh tokens | AES-256-GCM token storage; currently single active account | **Planned** | Milestone 3 |

---

## 3. Playback Engine: Future Evolution

### 3.1 Near-Term: Embedded libmpv Optimizations (Milestone 2)
1. **Dynamic Aspect Ratio Resizing:**
   - Detect video aspect ratio dynamically (e.g. 21:9 ultrawide, 4:3 legacy, 9:16 Shorts) from mpv's `video-params/aspect` property and update the GTK4 `AspectFrame` ratio dynamically.
2. **Miniplayer Floating Dock:**
   - In `ytui-gui`, allow docking the active video into the bottom-right corner when navigating away from the Watch page back to Home, Subscriptions, or Search feeds.
3. **Hardware DRM Zero-Copy Presentation:**
   - Investigate direct EGL stream / dmabuf sharing between libmpv and GTK4 GSK Vulkan renderer, reducing frame memory copies on Optimus hybrid setups.

### 3.2 Long-Term: Native Rust Chunk Streaming Pipeline (Milestone 3)
To replicate SmartTube's resilience against YouTube throttling and Sabr format experiments:
1. **Direct HTTP/2 Segment Prefetcher:**
   - Implement an in-process Tokio-based HTTP/2 streaming pipeline that downloads video and audio fragments ahead of playback using parallel connections.
   - Serve fragments to mpv via a local Unix domain socket or HTTP loopback server (`http://127.0.0.1:port/stream`), mimicking SmartTube's internal caching proxy.
2. **Automated PoToken (Proof-of-Origin) Daemon:**
   - Embed a lightweight JavaScript engine (`quickjs-rs` or `deno_core`) in `ytui-core` to resolve botguard and player tokens locally without launching external node processes.

---

## 4. UI / UX Roadmap

### 4.1 GUI Enhancements (`ytui-gui`)
- **Channel Header & Tab Navigation:** Clicking a channel name opens a dedicated Channel View with tabs for *Videos*, *Playlists*, *Community*, and *About*.
- **Comments Tree & Replies:** Expandable nested replies for YouTube comment threads.
- **Playlist Management:** Inline creation and deletion of local playlists and cloud sync.
- **Volume OSD Overlay:** On-screen display bar directly over the video surface during volume adjustments.

### 4.2 TUI Enhancements (`ytui`)
- **Split-Screen Watch Mode:** Embedded Sixel/Kitty terminal preview alongside live chat stream and description pane.
- **Queue Reordering:** Interactive modal to drag or reorder queued videos using `J` and `K`.
