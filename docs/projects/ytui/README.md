# ytui Workspace: TUI and GUI YouTube Client for Linux

**Fast, keyboard-driven YouTube client for Linux, combining a terminal user interface (Ratatui) and native desktop GUI (GTK4 + libmpv) on a shared Rust backend (`ytui-core`).**

---

## 1. Overview & Architecture

The `ytui` workspace is partitioned into three decoupled crates:

```
ytui/
├── crates/
│   ├── ytui-core/     # Headless engine: InnerTube requests, auth, SponsorBlock, RYD, cache
│   ├── ytui/          # Ratatui TUI client with MPV IPC control and Kitty/Sixel graphics
│   └── ytui-gui/      # GTK4 native GUI client with embedded libmpv hardware video surface
```

### Shared Engine (`ytui-core`)
- **InnerTube Client:** Communicates with YouTube's TVHTML5 and Web endpoints without requiring API keys or quota consumption. Supports search, home feed, subscriptions, channel feeds, playlists, comments, and related videos.
- **SponsorBlock Engine:** Asynchronously queries the SponsorBlock REST API and tracks playback position to skip sponsors, intros, outros, and self-promotions.
- **Return YouTube Dislike (RYD):** Real-time integration fetching like and dislike statistics.
- **Watch History & Resume:** Parses `thumbnailOverlayResumePlaybackRenderer` for exact playback continuation and emits `ping_playback` and `ping_watchtime` pings to sync with official YouTube accounts.
- **Fallback Chain:** Transparent fallback from InnerTube to `yt-dlp` for protected or rate-limited streams.

---

## 2. Clients

### 2.1 Terminal Client (`ytui`)
- **Engine:** `ratatui` + `crossterm`.
- **Graphics:** High-resolution terminal thumbnails via DEC Sixel (Foot) and Kitty Graphics Protocol (Kitty, Ghostty), with Unicode half-block fallback.
- **Playback:** Out-of-process `mpv` instance controlled via Unix domain socket JSON IPC.
- **Binary:** `~/.local/bin/ytui`

### 2.2 Desktop GUI Client (`ytui-gui`)
- **Engine:** `gtk4` (`gtk4-rs`) + embedded `libmpv` rendered to `GtkGLArea` with OpenGL context sharing.
- **Performance:** Sub-10ms UI reaction time, under 285 MB RSS memory usage, 0% idle CPU.
- **Design:** Modern YouTube desktop layout with 16:9 responsive thumbnail grid, channel avatar badges, video description box with clickable timestamps and chapters, comments list, and horizontal related video cards.
- **Binary:** `~/.local/bin/ytui-gui`

### 2.3 Client Selection & Workflow Rationale (TUI vs. GUI)
- **Active Daily Driver (`ytui`):** Preferred client for keyboard-driven terminal workflows. Consumes only ~25-45 MB RSS, renders high-resolution thumbnails via DEC Sixel directly on `foot` under Sway, and controls an out-of-process `mpv` player via Unix domain sockets without spawning heavyweight GUI window hierarchies.
- **Desktop GUI Status (`ytui-gui`):** Fully implemented, compilable, and operational, but reserved as an opt-in standalone client. It is not used as the primary daily driver due to the higher memory footprint (~285 MB RSS from GTK4/OpenGL/libadwaita runtime) and workflow friction compared to keeping playback inside the terminal workspace.

### 2.4 Pixel / terminal-browser Hardware Benchmark Audit (Why It Is Rejected)

Live empirical benchmarks conducted on this workstation (Intel Core i5-13450HX + RTX 5050 Mobile) evaluating `@zenbu-labs/pixel` / `terminal-browser` during 1280x720 YouTube playback in a terminal pane:

#### Process-Level Resource Allocation & Telemetry

| Component / Subprocess | Measured PSS (Real RAM) | CPU Load (Active Playback) | Architecture Role |
| :--- | :--- | :--- | :--- |
| **Kitty + 2 kittens + fish** | 343 MiB | ~7% of 1 core | Terminal emulator host container |
| **YouTube tab renderer** (pid 301042) | 387 MiB | 54% of 1 core | Chromium Blink DOM / JS execution |
| **Browser daemon** (pid 300505) | 199 MiB | 18% of 1 core | Node/Electron main lifecycle process |
| **GPU process** (pid 300543) | 241 MiB | 15% of 1 core | Offscreen rendering (OSR) surface |
| **Other helper processes** | ~175 MiB | ~1% of 1 core | IPC bridges and audio decoders |
| **Combined Workload Total** | **~1.35 GiB PSS** | **~95% of 1 core (5.9% total CPU)** | Full Electron/Chromium pipeline |

*Note on memory metrics:* Proportional Set Size (PSS) represents the exact unshared memory footprint. Summing naive per-process RSS shows ~2.3 GiB due to double-counting shared Chromium shared memory pages.

#### GPU & Power Metrics
- **Intel iGPU (GPU0):** Draws 9–11 W with 12–27% load when the pane is visible on screen. During background/hidden workspace playback, the GPU video engine drops to 0% (rc6 100%, 0 W), causing the video stream to fall back to unaccelerated software CPU decoding, which drives CPU consumption to ~0.95 cores.
- **GeForce RTX 5050 (GPU1):** Stays suspended in D3cold (0%, 0.00 W) because the Electron process targets the Intel render node.
- **Video Engine Usage:** 0% hardware decode engagement in the test profile.

#### Architectural Verdict
1. **Toolkit vs. Application:** Pixel is a UI wrapper, but running web content requires the full `terminal-browser` stack (Chromium + Electron + React + Node), introducing massive memory and thread overhead.
2. **Resource Inefficiency:** Consuming ~1.35 GiB of RAM and an entire CPU core just to display a YouTube video inside a terminal defeats the entire purpose of a lean, minimalist Linux setup.
3. **Adopted Architecture:** Retain pure native Rust **Ratatui + `ytui-core`** for catalog browsing and metadata, combined with decoupled **MPV + IPC** for hardware-accelerated (`hwdec=auto-safe`) video decode. This achieves the complete keyboard-first experience with a fraction of the system footprint (~30 MB TUI + lean MPV instance).

---

## 3. Keyboard Workflows (Vim-Driven)

### 3.1 GUI Navigation (`ytui-gui`)

| Mode | Keybinding | Action |
| :--- | :--- | :--- |
| **Global** | `/` or `Ctrl + L` | Focus search entry |
| **Global** | `Esc` | Unfocus / Return to feed / Exit Fullscreen |
| **Global** | `1` to `5` | Switch view: Home, Subscriptions, History, Playlists, Settings |
| **Browse Grid** | `j` or `Down` | Move selection down (next row) |
| **Browse Grid** | `k` or `Up` | Move selection up (previous row) |
| **Browse Grid** | `h` or `Left` | Move selection left (previous item) |
| **Browse Grid** | `l` or `Right` | Move selection right (next item) |
| **Browse Grid** | `Return` / `Enter` | Play video or open playlist |
| **Browse Grid** | `gg` / `G` | Jump to top / Jump to bottom |
| **Browse Grid** | `r` | Reload current feed |
| **Watch View** | `k` or `Space` | Play / Pause toggle |
| **Watch View** | `j` or `Left` | Seek -5s (Shift: -30s) |
| **Watch View** | `l` or `Right` | Seek +5s (Shift: +30s) |
| **Watch View** | `Up` / `Down` | Volume +5% / Volume -5% |
| **Watch View** | `m` | Mute toggle |
| **Watch View** | `[` / `]` | Playback speed -0.25x / +0.25x |
| **Watch View** | `f` | Fullscreen toggle |
| **Watch View** | `t` | Theater mode toggle |
| **Watch View** | `c` | Subtitles toggle |
| **Watch View** | `Tab` | Switch focus between video player and Related Videos sidebar |
| **Related Sidebar** | `j` / `k` + `Enter` | Navigate and play related video |

### 3.2 TUI Navigation (`ytui`)

| Keybinding | Action |
| :--- | :--- |
| `j` / `k` / `h` / `l` | Navigate video grid or queue |
| `Enter` | Play video in MPV |
| `Shift + Enter` | Start inline terminal playback |
| `/` | Focus search bar |
| `1` - `4` | Switch tabs: Home, Subscriptions, History, Playlists |
| `q` | Quit application |
| `Space` | Play / Pause (via IPC) |
| `[` / `]` | Volume down / Volume up |

---

## 4. Hardware Acceleration and MPV Tuning

Hardware decoding is governed by the system's dynamic GPU mode:
- **Direct dGPU MUX Mode (`AsusMuxDgpu`):** `hwdec = "auto-safe"` uses NVDEC / Vulkan acceleration on the RTX 5050 Mobile, delivering 4K60 AV1 playback with zero CPU overhead.
- **Optimus Hybrid Mode (`Hybrid`):** `hwdec = "vaapi"` offloads to Intel UHD Graphics iGPU, keeping the dedicated GPU suspended in runtime D3cold.

Buffer configuration:
```ini
demuxer-max-bytes=512MiB
demuxer-max-back-bytes=256MiB
demuxer-readahead-secs=60
demuxer-lavf-buffersize=2097152
demuxer-lavf-o=reconnect=1,reconnect_streamed=1,reconnect_delay_max=5
ytdl-raw-options=no-playlist=,extractor-args=youtube:player_client=android,web
```

---

## 5. Further Documentation

- [Upstream Repository README](./source-README.md)
- [Future Roadmap & SmartTube Architecture](future.md)
- [Crate Source: ytui-core](file:///home/onyx/Projects/ytui/crates/ytui-core)
- [Crate Source: ytui-gui](file:///home/onyx/Projects/ytui/crates/ytui-gui)
- [Crate Source: ytui](file:///home/onyx/Projects/ytui/crates/ytui)
