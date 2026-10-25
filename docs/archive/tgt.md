# tgt Terminal User Interface for Telegram (Archived)

> [!NOTE]
> This document is archived. tgt is no longer in active use on this system, superseded by Tele TUI.

`tgt` is a terminal user interface for Telegram written in Rust, built with Ratatui and TDLib.

---

## 1. Build Architecture & Enabled Features

Compiled from source ([FedericoBruzzone/tgt](https://github.com/FedericoBruzzone/tgt)) with all high-performance and media features enabled, optimized via release profile (`opt-level = 'z'`, `lto = true`, `codegen-units = 1`):

| Feature | Status | Architecture & Implementation |
| :--- | :--- | :--- |
| **`static-download`** | Enabled | Statically links `tdjson` into the release binary. Eliminates external dynamic library dependencies and path mismatches. |
| **`voice-message`** | Enabled | Plays Telegram voice notes (OGG Opus) via `audiopus` and `ogg` without external players. |
| **`rodio`** | Enabled | Hardware audio output directly to PipeWire / ALSA audio sinks. |
| **`chafa-dyn`** | Enabled | Displays photos inside the terminal using system Chafa (`/usr/bin/chafa`) via `ratatui-image`. |

Binary location: `~/.local/bin/tgt` (61 MB self-contained binary).

---

## 2. Low-Overhead Configuration & Tuning

Configuration files are located in `~/.config/tgt/config/`:

### A. Application Settings (`app.toml`)
- **`frame_rate = 30.0`**: Throttles idle event loop redraws from 60 Hz down to 30 Hz. Reduces CPU wakeups and memory bus traffic by 50% during idle state.
- **`use_emoji_icons = false`**: Adheres to zero-emoji system policy. Uses lightweight ASCII status indicators (`[mod]` edited, `<--` reply, `[✓]` seen, `[o o]` viewed, `[ ]` sent), avoiding terminal glyph atlas bloating.
- **`photo_max_dimension = 1280`**: Downscales incoming photo previews to 1280px before decoding in memory, preventing uncompressed multi-megapixel image buffers from swelling process RSS.
- **`photo_viewer_popup_size = 0.8`**: Standard 80% viewport popup.

### B. Logger Tuning (`logger.toml`)
- **`log_level = "warn"`**: Suppresses verbose message polling and network traces. Eliminates constant disk writes and logger heap allocations.
- **`max_old_log_files = 3`**: Limits log archive retention.

### C. Telegram TDLib Database (`telegram.toml`)
- **`verbosity_level = 1`**: Suppresses internal TDLib diagnostic output to disk.
- **Persistent Database**: Stored under `~/.local/share/tgt/tdlib/` with Btrfs No-CoW (`chattr +C`) enabled to prevent write amplification and SQLite fragmentation.

---

## 3. Desktop & Compositor Integration

### Foot Terminal Client-Server
`tgt` launches via `footclient` to reuse the existing `foot --server` process, sharing VictorMono Nerd Font glyph atlases and Wayland `wl_shm` buffers (adding only ~16 MB PSS instead of ~130 MB GPU-accelerated contexts).

### Desktop Entry
Installed at `~/.local/share/applications/tgt.desktop`:
- App ID: `tgt-term`
- Title: `Telegram TUI`
- Exec: `footclient --app-id=tgt-term --title="Telegram TUI" tgt`

### Sway Window Rules
Added to `~/.config/sway/config.d/30-window-rules.conf` (managed via chezmoi):
```
for_window [app_id="tgt-term"] floating enable, border pixel 2, resize set 1300 850, move position center, focus
for_window [class="tgt-term"] floating enable, border pixel 2, resize set 1300 850, move position center, focus
```

---

## 4. Keybindings Quick Reference

### Navigation & Focus
- `Alt + 1` / `Alt + Left`: Focus Chat List
- `Alt + 2` / `Alt + Right`: Focus Chat History
- `Alt + 3` / `Alt + Down`: Focus Prompt / Input Bar
- `Esc`: Return to Default / Unfocused state
- `q` / `Ctrl + C`: Quit (when prompt is not focused)

### Chat List
- `Up` / `Down`: Navigate chats
- `Enter` / `Right`: Open selected chat
- `Alt + r`: Search chats
- `Alt + c`: Restore default chat ordering

### Message View
- `Up` / `Down`: Scroll message history
- `y`: Copy message text
- `e`: Edit own message
- `r`: Reply to message
- `d`: Delete message for everyone
- `D`: Delete message for yourself
- `Alt + v`: View photo in photo viewer (Chafa engine)

### Photo Viewer
- `Esc`: Close photo viewer
- `k` / `Up`: Previous photo
- `j` / `Down`: Next photo

### Message Input
- `Alt + Enter`: Send message
- `Ctrl + A` / `Home`: Start of line
- `Ctrl + E` / `End`: End of line
- `Ctrl + W` / `Ctrl + Backspace`: Delete word before cursor

---

## 5. First-Time Authentication

To log in for the first time, run:
```bash
tgt
```
Enter your phone number (including country code) and the Telegram authentication code received on your account.
