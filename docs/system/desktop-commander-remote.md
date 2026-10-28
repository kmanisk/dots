# Desktop Commander Remote & ChatGPT Development Workflow

Target machine: ASUS TUF Gaming F16 (FX608JH) · CachyOS Linux · Sway (Wayland)

---

## 1. Overview & Architecture

Desktop Commander Remote allows ChatGPT (and remote MCP clients) to interact directly with this CachyOS laptop as an authenticated remote coding agent over an encrypted WebRTC/WebSocket bridge.

```text
 ChatGPT (Cloud)
       │
       ▼ (Encrypted WebRTC / WebSocket Relay)
 [Desktop Commander Remote Bridge]
       │
       ▼ (systemd user daemon: desktop-commander.service)
 Local Machine Environment
       │
       ├── Filesystem Access  :  Unrestricted (`allowedDirectories: []`)
       ├── Power & Idle State :  Keep-Awake Active (Screen dims at 2m, DPMS off at 5m)
       ├── Clamshell Mode     :  Closing lid keeps machine awake, powers down eDP-1
       └── Monitoring         :  Live scratchpad log viewer (`Win + Alt + D`)
```

---

## 2. Headless Daemon (`desktop-commander.service`)

Rather than requiring an open terminal window that could accidentally be closed, Desktop Commander runs continuously as a native systemd user daemon:

- **Service File:** `~/.config/systemd/user/desktop-commander.service`
- **Execution Target:** `/usr/bin/npx --yes @wonderwhy-er/desktop-commander@latest remote`
- **Auto-Restart:** `Restart=always`, `RestartSec=5s` (automatically reconnects if internet drops)
- **User Lingering:** Enabled via `sudo loginctl enable-linger onyx`, ensuring the service launches at boot and remains running across logouts.
- **Resource Limits:** `MemoryMax=1.5G`

### Controlling the Service
```bash
start                     # Displays daemon status and recent connection logs
dc                        # Alias for start
dc-start logs             # Streams live tool-call activity in the terminal (tail -f)
systemctl --user status desktop-commander
systemctl --user restart desktop-commander
```

---

## 3. Configuration & Filesystem Permissions

- **Configuration File:** `~/.claude-server-commander/config.json`
- **Permissions:** `"allowedDirectories": []`
  - In Desktop Commander's configuration architecture, an empty array `[]` grants the agent access to the user's filesystem without artificial directory path blocks.
  - Telemetry is permanently disabled (`"telemetryEnabled": false`).
- **Device Authentication:** Persisted in `~/.desktop-commander-device/device.json`. Device credentials survive reboots and automatically re-authorize the connection.

---

## 4. Live Scratchpad Monitor (`Win + Alt + D`)

To observe ChatGPT's tool calls and command outputs in real time without cluttering workspaces, a dedicated scratchpad is configured:

- **Trigger:** Press **`Win + Alt + D`** (or run `toggle-dc` / `scratch-toggle dc`).
- **Appearance:** Floating centered terminal window (`1500x950`), styled with 2px border, running `footclient` with 20pt Iosevka Nerd Font Mono.
- **Behavior:**
  - If hidden: Slides up instantly (<3ms), centered and focused.
  - If visible: Stashes back into the scratchpad immediately.
  - Guarded: Will not disrupt full-screen gaming sessions on Workspace 4 or media playback.

---

## 5. Clamshell & Kept-Awake Integration

The laptop can run as a 24/7 headless remote workstation even with the lid shut:

1. **Keep-Awake Default:** Session starts with Keep-Awake active (`keep-awake init`). `systemd-inhibit --what=idle:sleep:handle-lid-switch` prevents system suspension.
2. **Lid Close Handling:**
   - When the lid is closed, Sway's `lid:on` trigger runs [`lid-handler close`](file:///home/onyx/.local/bin/lid-handler).
   - Turns off the internal display backlight (`output eDP-1 dpms off`) to prevent heat trapped against the keyboard and save battery.
   - The CPU, WiFi, and Desktop Commander daemon continue running at 100% full speed.
3. **Lid Open Handling:**
   - When opened, `lid:off` runs `output eDP-1 dpms on` and reconnects Bluetooth peripherals.
4. **Automatic Screen Dimming (While Open):**
   - After **2 minutes** of idle: hardware brightness drops smoothly to 10%.
   - After **5 minutes** of idle: display enters DPMS off.
   - Any keypress or mouse movement immediately restores brightness with zero password prompt.
   - Every event is logged with timestamps in `~/.local/state/screen-dim.log`.

---

## 6. Development Workflow (Local Fix -> GitHub -> Deploy)

```text
 1. Assign Task in ChatGPT     Provide absolute paths (e.g. `/home/onyx/Projects/watchparty`)
        │
        ▼
 2. Local Execution            ChatGPT inspects files, runs incremental edits,
                               and executes tests (`cargo test`, `npm test`) directly.
        │
        ▼
 3. Live Verification          Press `Win + Alt + D` to inspect live tool calls.
        │
        ▼
 4. Git Commit & Push          ChatGPT commits locally and pushes to GitHub.
        │
        ▼
 5. CI / Live Deployment       GitHub triggers automatic deployment on Vercel / Render / Netlify.
```
