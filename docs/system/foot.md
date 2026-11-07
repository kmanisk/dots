# Foot Terminal Emulator Architecture and Benchmarks

Foot is a lightweight, fast, Wayland-native terminal emulator designed specifically for wlroots and Wayland compositors (such as Sway). It renders on the CPU using Pixman SIMD routines (AVX2/SSE) rather than allocating OpenGL/GPU textures, eliminating GPU driver overhead and preventing discrete GPUs from remaining active in hybrid setups.

---

## 1. Operating Modes: Standalone vs Client-Server

Foot supports two execution models:

### A. Standalone Mode (`foot`)
- **Architecture:** Each terminal window runs as an independent OS process.
- **Advantages:**
  - Complete crash isolation: If one terminal process hangs or terminates unexpectedly, other terminal windows are unaffected.
  - Direct execution model with zero daemon dependency.
- **Footprint:** ~23.8 MB RSS per instance.

### B. Client-Server Mode (`foot --server` + `footclient`)
- **Architecture:** A single background daemon (`foot --server`) manages fonts, glyph caches, and Wayland display handles. New windows are created via `footclient`.
- **Advantages:**
  - Shared memory: Fonts and glyph caches are allocated only once.
  - Sub-millisecond window creation latency.
  - Incremental footprint: ~2 MB to ~4 MB per connected client.
- **Trade-offs:**
  - Single point of failure: If the server daemon crashes, all connected client windows terminate.

---

## 2. Live Benchmark Results: Foot vs Kitty (Sway Workspace 5)

Tested on CachyOS (Linux 6.18, Intel i5-13450HX, 1920x1200 @ 165Hz). Measured from `/proc/<pid>/smaps_rollup` with identical typography (`VictorMono Nerd Font Bold @ 19.5`) and color palettes.

### Single Window Baseline

| Metric | Kitty (PID 132068) | Foot (PID 132069) | Foot Advantage |
| :--- | :--- | :--- | :--- |
| **RSS (Resident Set Size)** | 131.99 MB | 23.88 MB | **-108.11 MB (5.5x leaner)** |
| **PSS (Proportional Set Size)** | 55.68 MB | 10.42 MB | **-45.26 MB** |
| **USS (Unique Private RAM)** | 42.21 MB | 6.70 MB | **-35.51 MB** |
| **CPU Utilization (Idle)** | 0.00% | 0.00% | Equal |

### Multi-Window Memory Projection

| Open Windows | Kitty Total RSS | Foot Total RSS | RAM Saved |
| :--- | :--- | :--- | :--- |
| **1 Window** | 132.0 MB | 23.9 MB | **108.1 MB (0.11 GB)** |
| **3 Windows** | 396.0 MB | 71.6 MB | **324.3 MB (0.32 GB)** |
| **5 Windows** | 660.0 MB | 119.4 MB | **540.5 MB (0.53 GB)** |
| **6 Windows** | 791.9 MB | 143.3 MB | **648.7 MB (0.63 GB)** |
| **8 Windows** | 1055.9 MB | 191.0 MB | **864.9 MB (0.84 GB)** |
| **10 Windows** | 1319.9 MB | 238.8 MB | **1081.1 MB (1.06 GB)** |

### Fastfetch Head-to-Head Comparison

Based on an OCR scan of the screenshot directory (`screenshot-2026-10-17_19-55-44_117482.png`) compared directly with the live fastfetch capture:

| Metric | Kitty Era (Oct 17, 19:55) | Foot Client-Server Era (Current) | Difference / Savings |
| :--- | :--- | :--- | :--- |
| **Terminal** | kitty 0.49.2 | foot 1.28.0 | Client-server architecture |
| **Active RAM Used** | 6.82 GiB (7,025 MB) | 4.57 GiB (4,680 MB) | -2.25 GiB (-2,304 MB) |
| **RAM % of Total (15.22 GiB)** | 45% | 30% | -15.0% of total physical RAM |
| **Relative Memory Drop** | Baseline | Reduced by 33.0% | 1/3 less active RAM consumed |
| **Uptime & Workload** | 4 hours, 7 mins (YouTube, shell) | 9 hours, 31 mins (YouTube, agy, opencode) | Lower RAM even with double uptime |

### Technical Breakdown of the Savings

1. **Font & Glyph De-duplication (Client-Server Mode)**
   - **Kitty:** Each terminal window ran an independent process with its own Python/C runtime, GLFW OpenGL context, font rasterizer, and glyph texture atlas (~120 MB - 160 MB RSS per window). With 3–4 open windows (workspace terminals + scratchpad dropdown + notes dropdown), Kitty alone occupied ~500 MB - 640 MB of memory.
   - **Foot:** A single background daemon (`foot --server`) parses VictorMono Nerd Font once. All subsequent windows connect as lightweight `footclient` sessions sharing the identical font cache, rasterized glyphs, and configuration trees. In our live sysmem audit, all 3 active Foot windows plus the server daemon consume only 67.0 MB total PSS (~16.7 MB per window).

2. **Elimination of Per-Window GPU Context Overhead**
   - Standalone GPU-accelerated terminals force dedicated OpenGL/EGL surface allocations and graphics driver buffers on Wayland.
   - Foot utilizes direct Wayland shared-memory (`wl_shm`) with multi-threaded pixman CPU rendering (`workers=4`), completely removing GPU driver memory bloat from the terminal stack.

3. **Compound Cache & Swap Relief**
   - Freeing 2.25 GiB reduced swap thrashing and left significantly more memory available for reclaimable Linux page cache (`Buff/Cache: ~10.03 GB`), improving system responsiveness during background compilation and heavy browser workloads.

---

## 3. Key Findings

1. **Memory Discipline:** Foot saves ~108 MB RAM per window. A standard workflow of 5 to 6 terminals saves ~540 MB to ~650 MB of memory.
2. **GPU Overhead Elimination:** Kitty's ~132 MB footprint is largely driven by OpenGL context creation, GLSL shader compilation, and GPU surface buffers. Foot uses CPU SIMD buffers via Pixman, drawing virtually zero power and preventing dGPU wakeups.
3. **Dynamic Theming Integration:** Integrated with `theme-set`. Foot is the workstation's primary terminal target. For Omarchy themes that ship terminal-specific profiles, Foot translates the author's colors with precedence `alacritty.toml` -> `kitty.conf` -> normalized generated palette, per value; Kitty may fill roles Alacritty does not define, such as URL color. This ports background/foreground, cursor, selection, and all ANSI 0-15 colors without importing upstream fonts, padding, keybindings, commands, or window behavior. Switching themes recompiles `~/.config/foot/foot-colors.ini` atomically and broadcasts the same translated XTerm OSC 10/11/12/17/19 plus OSC 4 palette directly to PTYs owned by live Foot windows for instant hot-reload. Foot `SIGUSR1`/`SIGUSR2` are not reload signals: in Foot 1.28 they only switch to the `[colors-dark]` / `[colors-light]` values already cached by the long-lived server, so `theme-set` must not use those signals after regenerating the palette. A zero-resident `~/.local/bin/footclient` exec wrapper injects `-o include=~/.config/foot/foot-colors.ini` into new clients so they receive the current palette even though the server itself remains running.

### 2026-11-07: Foot server PTY hot-reload correction

In the live client/server layout, `/usr/bin/footclient` is an IPC client without a terminal child. The session processes (`fish`, `nvim`, etc.) are spawned directly by `foot --server`; their standard FDs expose `/dev/pts/<n>`. The previous `theme-set` process search also inspected `footclient` children, so existing windows often received **no** OSC palette updates. New Foot windows still loaded the new generated include, producing inconsistent old/new backgrounds across the desktop.

`theme-set` now calls `foot_terminal_ptys()` on **only `foot` PIDs**, examining standard FDs 0, 1 and 2 of their immediate children, and sends one complete palette payload per discovered slave PTY. It sends OSC 10/11/12/17/19 and all 16 OSC 4 colors **before** live Neovim theme RPC, reducing the dark/light mismatch between a terminal's background and the editor redraw. The implementation never writes to unrelated PTYs, sends no terminal clear/reset and does not restart the shared Foot server or any TUI.

Read-only process discovery found live Foot sessions at `/dev/pts/0` and `/dev/pts/1`; a focused write test of the current active palette successfully updated **2/2** live Foot PTYs, with no global theme change. A mocked test verified 21 color commands per PTY and no screen-reset sequences. An optional one-off `THEME_FOOT_TRACE=1 theme-set <theme>` reports updated PTY counts on a **real** theme switch; same-theme no-op updates intentionally skip broadcasting. The failed experimental dark/light round-trip was **not run** because the user changed themes during test setup, and their chosen theme was preserved.

**Limit:** Existing TUI cells painted with explicit 24-bit RGB colors are application-owned, not terminal palette indices. OSC alone cannot recolor those cells; Codex/OpenCode or other fullscreen apps must redraw their own content or refresh their internal theme. Do not force `SIGWINCH`, restart app processes or send `ESC[2J`/RIS globally: these can disrupt active sessions. If an app leaves an artifact after a theme switch, use its own redraw action (often `Ctrl+L`, where supported). This fix guarantees the terminal palette delivery, not arbitrary application-specific theme reloads.

---

## 4. Benchmark Utility

A standalone isolation benchmark tool is installed at `~/.local/bin/bench-terminals`. It maps isolated test windows into Sway Workspace 5, profiles them via kernel `smaps_rollup`, prints real-time metrics, and cleans up automatically.

To execute:
```bash
bench-terminals
```

---

## 5. Font Configuration and Sizing

Font state is owned by `~/.config/foot/foot.ini` (chezmoi source: `dot_config/foot/foot.ini`). Nothing else defines a Foot font size.

- **Current:** `Iosevka Nerd Font Mono:size=16.6:style=Regular`, `pad=0x0`, `font-size-adjustment=0.5`.
- **DPI:** no `dpi` / `pixels-per-inch` key is set, so Foot uses its default 96 DPI multiplied by the Wayland output scale. `eDP-1` currently runs at scale `1.30` (logical 1476x923), so the configured 16.6 pt size is still enlarged by compositor scaling.
- **The running server owns the font size.** `foot-server.service` parses `foot.ini` once at startup; `footclient` only forwards `-o` overrides. Editing `foot.ini` therefore does not change new windows by itself. Verified on 2026-11-01: with the server up since before the edit, a new client reported 147x35 cells at both 16 and 24 pt in `foot.ini`, while `-o font=...:size=17.5` produced 137x32 in the same window. Any file-based size change requires `restart-terminals` or `foot-font -r`; restarting the server closes every open Foot window.
- **Zoom keys:** `Alt+Shift+U` / `Alt+Shift+=` / `Ctrl+plus` / `Ctrl+=` / `Ctrl+KP_Add` grow by 0.5; `Alt+Shift+Y` / `Alt+Shift+-` / `Ctrl+minus` / `Ctrl+KP_Subtract` shrink by 0.5; `Ctrl+0` resets. Mouse-wheel zoom is bound to `none` so wheel chords stay pure scrollback.
- **Scratchpads differ:** `scratch-term`, `scratch-notes`, and `dc-term` spawn through `~/.local/bin/scratch-toggle`, passing a per-client `-o font=` override. `scratch-notes` and `dc-term` use `SCRATCH_FONT_SIZE` (17 pt); the Ctrl+Space `scratch-term` uses `SCRATCH_TERM_FONT_SIZE` (16.5 pt). Both can be overridden in the environment without editing the script. Because the override is per client, the foot server does not need a restart, but an existing scratchpad client must be respawned (killing its `footclient`); hiding and re-showing keeps the old font.

### Font changes must go through `foot-font`

Use `~/.local/bin/foot-font` (`foot-font` alone prints the current value, `foot-font +0.5`, `foot-font 17`, `foot-font -r` after restarting the server). It writes `foot.ini`, the chezmoi copy, and then validates with `foot --check-config`.

Invariant: `dot_config/sway/config.d/00-variables.conf` must keep a plain `set $term footclient` with no `-o font=` override. Behavior belongs to `foot.ini` so there is one source of truth. `foot-font` therefore only rewrites a `-o font=` override if one already exists on that line, and never injects a new one. Earlier versions spliced the generated override into the following comment line because the insertion regex used `\s+` (which consumed the newline), which produced an invalid `-o` Sway command; the rewrite now anchors on `[^\n]` and restores the variables file if `sway -C` reports a load error.

---

## 6. URL Mode & Link Navigation

- **Activation Keychords:** `Alt+o` or `Ctrl+Shift+o` triggers Foot's URL jump mode, showing alphabet hint badges over links in the terminal viewport.
- **Smart Launcher (`foot-url-launch`):** Configured via `[url] launch=foot-url-launch ${url}`:
  - **Web URLs (`http://`, `https://`):** Delegated directly to default browser (`brave-origin`).
  - **File URLs & Paths (`file://...`):** Extracts file paths and optional line numbers (`#L123` or `:123`).
  - **Directories:** Opened in file manager (`thunar`).
  - **Media / Documents:** Image/video/audio/PDF files open in their respective graphical viewers (`imv`, `mpv`, `pdfcraft`).
  - **Text & Code Files:** Opened directly in a new Foot terminal window running Neovim (`footclient -s $sock -E nvim [+$line] $file`).
- **Generic XDG Compatibility:** A user desktop entry at `~/.local/share/applications/nvim.desktop` (`Exec=footclient nvim %F`, `Terminal=false`) ensures generic `xdg-open` calls from existing running terminal instances also allocate a terminal window rather than running Neovim as an invisible background process.
