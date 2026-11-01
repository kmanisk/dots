# System Clipboard & Screenshot Cheatsheet

Target machine: CachyOS Linux · Sway (Wayland) · Katana S K1 60% Keyboard (xremap)

---

## 1. Quick Reference Table

| Shortcut | Layer / Scope | Action | Description |
| :--- | :--- | :--- | :--- |
| **`Win + V`** | Sway (Global) | Open Clipboard Menu | Floating centered terminal picker with full prompt preview & search |
| **`Caps + c`** | xremap (Katana 60%) | Open Clipboard Menu | Quick one-hand access to the floating clipboard picker |
| **`Caps + .`** | xremap (Katana 60%) | Paste Clipboard | Standard `Ctrl+V` paste |
| **`Caps + Space`** | xremap (Universal) | Capture Screenshot | Fullscreen capture saved to disk and copied to clipboard; also queued only while buffer mode is ON |
| **`Caps + Shift + Space`** | xremap (Universal) | Toggle Buffer Mode | Turns screenshot accumulation ON/OFF; does not open the picker |
| **`Caps + v`** | xremap (Katana 60%) | View First Screenshot | Opens the latest clipboard screenshot in imv |
| **`Win + Alt + L`** | Sway (Global) | Screen Black Toggle | Instantly toggles display backlight off/on; keeps agent, rain audio, and downloads running |
| **`Win + Alt + D`** | Sway (Global) | Desktop Commander Scratchpad | Toggles floating agent monitor streaming live ChatGPT tool calls |
| **`Win + Ctrl + I`** | Sway (Global) | Toggle Keep-Awake | Toggles Keep-Awake / Clamshell mode (bypasses screen lock and lid sleep) |
| **`Win + Alt + S`** | Sway (Global) | Snip Region to Buffer | Interactive region select with slurp; saves and adds to buffer queue |
| **`Win + Alt + V`** | Sway (Global) | Screenshot Buffer Picker | Opens interactive selection modal to pick and paste specific buffered screenshots |
| **`Win + Alt + Shift + V`** | Sway (Global) | Stitched Paste | Merges all buffered screenshots vertically into one composite and pastes |
| **`Win + Alt + X`** | Sway (Global) | Clear Buffer | Clears active screenshot queue |
| **`Win + Alt + A`** | Sway (Global) | Toggle Auto-Buffer | Toggles whether all screenshots and copied images automatically buffer |
| **`L` (`Shift+L`)** | MPV (Window) | Loop Current Video | Toggles infinite single-file loop for overnight audio/rain playback |
| **`Ctrl + L`** | MPV (Window) | Loop Playlist | Toggles infinite playlist loop across all queued media items |
| **`Win + ?`** | Sway (Global) | Cheatsheet Menu | Opens interactive Rofi cheatsheet modal |

---

## 2. Multi-Screenshot AI Workflow

When feeding multiple screenshots of a website or UI to an AI prompt (ChatGPT, Claude, Gemini in Brave):

1. **Normal Fullscreen Capture:**
   - Press **`Caps + Space`** to capture the current screen.
   - The image is saved under `~/Pictures/Screenshots/` (or `Screenshots/Gaming` on game workspaces) and copied to the clipboard.
   - With buffer mode OFF, it is not queued and `Screenshot Done` confirms completion.
   - Press **`Caps + Shift + Space`** to turn buffer mode ON; subsequent `Caps + Space` captures are also queued until you toggle the mode OFF.

2. **Choose and Paste into Prompt:**
   - Switch to your AI chat prompt (ChatGPT, Claude, Gemini in Brave).
   - Press **`Win + Alt + V`** to open the explicit screenshot-buffer picker.
   - The centered 1760x1040 Screenshot Buffer Picker opens instantly.
   - Navigate through screenshots using **Up / Down** arrow keys with live high-res preview on the right.
   - Tap **`Space`** on the screenshots you want to send.
   - Press **`Enter`**: Only the chosen screenshots are sequentially pasted into the active prompt!
   - Press **`Alt + Enter`**: Merges and pastes the chosen screenshots as one stitched image.
   - Press **`Ctrl + A`**: Select all queued screenshots.
   - Press **`Ctrl + D`**: Remove the highlighted screenshot from queue.
   - Pasted screenshots are archived to prevent duplicates.

3. **Normal Text Paste:**
   - **`Caps + .`** always performs a normal `Ctrl+V` paste; it no longer opens or depends on the screenshot buffer.

---

## 3. Centered Floating Clipboard Manager

- **Launch:** Press **`Win + V`** or **`Caps + c`**.
- **Appearance:** 1760x1040 centered floating window, 14pt VictorMono Nerd Font, 14x14 padding.
- **Controls inside the picker:**
  - `Enter`: Pastes selected entry directly into the previous active window (Windows Win+V behavior).
  - `Alt + Enter` or `Ctrl + Y`: Copies to clipboard only without auto-pasting.
  - `Ctrl + F`: Activates deep full-text search across multi-thousand-line prompt bodies in BoltDB.
  - `Ctrl + R`: Reloads normal clipboard history.
  - `Ctrl + D`: Deletes the highlighted entry from history.
  - `Ctrl + X`: Wipes full history.
  - `Esc`: Closes the picker.
  - `Shift + Up / Down` or `PgUp / PgDn`: Scrolls the prompt preview pane.

---

## 4. Sleep & Background Audio Mode

When playing rain audio or white noise for sleeping (e.g. 10 hours) while keeping background agents active:

- **Toggle:** Press **`Win + Alt + L`** (or run `screen-black`).
- **Lid-Closed Sleep Protection:**
  - Pressing **`Win + Alt + L`** turns display panel power (DPMS) completely off instantly.
  - Pauses `swayidle` so auto-locking and idle triggers do not awaken the display.
  - Takes a systemd low-level block lock (`--what=idle:sleep:handle-lid-switch`) preventing suspend even when the physical laptop lid is shut.
  - Audio (PipeWire/WirePlumber), media players (Brave/MPV), and Antigravity agents continue running at 100% capacity with the lid shut.
- **Wakeup:** Press **`Win + Alt + L`** again to restore display power, unpause `swayidle`, and resume normal session state.

---

## 5. Media & MPV Looping Shortcuts

When playing rain videos, ambiance, or music overnight:

- **`L` (`Shift + L`):** Toggle infinite looping of the **current file** (`cycle-values loop-file "inf" "no"`). Displays on-screen notification (`File loop: inf` / `File loop: no`).
- **`Ctrl + L`:** Toggle infinite looping of the **entire playlist** (`cycle-values loop-playlist "inf" "no"`).
- **`Win + -` / `Win + _`:** Show/hide MPV floating scratchpad window.
- **`Win + Alt + L`:** Turn screen completely black while audio continues looping uninterrupted.
