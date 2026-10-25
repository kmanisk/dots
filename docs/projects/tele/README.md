# Tele: Terminal Telegram Client (Upstream Contributions)

**High-performance, terminal user interface for Telegram written in Go using Bubble Tea, replacing the legacy `tgt` client.**

- **Upstream Repository:** [sorokin-vladimir/tele](https://github.com/sorokin-vladimir/tele)
- **Local Worktrees:**
  - Active Sixel Feature: `/home/onyx/Projects/tele-sixel` (branch `feat/sixel-images`)
  - Stable Sixel Deployment: `/home/onyx/Projects/tele-sixel-stable` (branch `local/sixel-polish-v1`)
  - Video Streaming Feature: `/home/onyx/Projects/tele-video-streaming` (branch `feat/video-streaming`)
- **Installed Binary:** `~/.local/bin/tele` (version `1.11.13+sixel.369c21e`)
- **Desktop Integration:** Footclient-optimized launch with VictorMono Nerd Font, Sway floating window rules.

---

## 1. Overview & Architecture

Tele is a lightweight, keyboard-driven terminal Telegram client built on the Elm Architecture (Bubble Tea) and `gotd` (pure Go MTProto implementation). It operates without bulky background daemons, running with bounded memory footprints (~30-50 MB PSS under Foot).

Tele fully supersedes `tgt` on this system, offering improved session reliability, native Wayland rendering, and direct integration with terminal graphics protocols.

---

## 2. Upstream Contributions by @kmanisk

Two major feature implementations and architectural pull requests have been contributed to upstream Tele:

### PR #318: Bounded Sixel Previews and Album Rendering
- **Upstream PR:** [#318: feat: add Sixel previews with bounded terminal rendering](https://github.com/sorokin-vladimir/tele/pull/318)
- **Status:** Open (5 tasks completed, mergeable)
- **Architecture Document:** [`pr-318-sixel.md`](./pr-318-sixel.md) (or [`docs/system/tele-sixel.md`](file:///home/onyx/docs/system/tele-sixel.md))
- **Key Capabilities:**
  - High-performance inline Sixel image decoding and rendering.
  - 2-column album grid layout with dynamic badge cropping and cell-boundary clipping.
  - Geometry synchronization with Foot/Sway cell dimensions (10x23 to 14x34 px).
  - Serialized asynchronous raster encoding preventing repaint loops and frame tearing.

### PR #321: Progressive Range-Based Video Streaming
- **Upstream PR:** [#321: feat: play videos without waiting for the full download](https://github.com/sorokin-vladimir/tele/pull/321)
- **Status:** Open (8 tasks completed, mergeable)
- **Architecture Document:** [`pr-321-video-streaming.md`](./pr-321-video-streaming.md)
- **Key Capabilities:**
  - Instant progressive playback without waiting for complete document downloads.
  - Private loopback HTTP range streaming gateway (`127.0.0.1:0`) with 256-bit token entropy.
  - Aligned 128 KiB chunk fetching dividing Telegram 1 MiB windows with an 8-part LRU cache (1 MiB memory cap).
  - Direct integration with mpv and ffmpeg via HTTP 206 Partial Content range requests.
  - Monotonic session sequencing and automatic cleanup on modal dismiss or account disconnect.

---

## 3. Local Repository & Documentation Links

- [PR #318 Sixel Implementation Reference](./pr-318-sixel.md)
- [PR #321 Progressive Video Transport Specification](./pr-321-video-streaming.md)
- [Upstream Candidate Sixel Source README](./source-sixel-README.md)
- [Upstream Video Streaming Source README](./source-streaming-README.md)
