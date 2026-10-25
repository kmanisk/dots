# FetchIt: TUI Download Manager & Content Resolver

**High-performance terminal user interface (TUI) download manager and content browser built with Go and Bubble Tea.**

- **Project Path:** [`/home/onyx/fetchit`](file:///home/onyx/fetchit) (symlinked at [`/home/onyx/Projects/fetchit`](file:///home/onyx/Projects/fetchit))
- **Architecture:** Go (zero CGO) + Bubble Tea Elm Architecture + `aria2c` engine via WebSocket JSON-RPC.
- **Key Dependencies:** `chromedp` (headless browser automation), `xtractr` (archive decompression), `siku2/arigo` (aria2c RPC).

---

## 1. Overview & Capabilities

FetchIt automates link extraction, multi-threaded downloading, decompression, and disk cleanup in a single fluid 60 FPS terminal interface:

- **Plugin-Based Resolvers:**
  - *Pattern A (HTMX Redirect):* Captures direct CDN redirects via HTTP headers.
  - *Pattern B (REST API):* Interacts with hoster JSON APIs with guest tokens.
  - *Pattern C (Headless Multi-Step):* Automates JavaScript and Cloudflare challenges using `chromedp`.
  - *Pattern D (TLS Fingerprint):* Mimics standard browser TLS handshakes.
  - *Pattern E (Deterministic):* Instant URL pattern interpolation.
  - *Pattern F (DOM Scraper):* Scrapes DOM trees for fallback extraction.
- **Accelerated Downloads:** Communicates with local `aria2c` daemons using 16-connection splitting per file.
- **Automatic Decompression:** Native extraction of ZIP, RAR, 7Z, TAR, GZ, and ISO archives followed by automatic temporary archive deletion.
- **Pre-Flight Disk Safety:** Audits filesystem capacity prior to starting downloads to eliminate Btrfs disk saturation risks.

---

## 2. Usage & Execution

```bash
cd /home/onyx/fetchit

# Run interactive TUI
./fetchit
```

---

## 3. Architecture & Repository Documentation

- [Upstream Repository README](./source-README.md)
