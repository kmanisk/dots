---
name: bluetooth-autoconnect
description: Bluetooth auto-connect and refusal on this machine - the three dialers (bt-autoconnect, bt-auto-trust, blueman AutoConnect plugin), BlueZ block semantics, the audio-device refusal toggle (Win+Shift+Enter), and the bt-select TUI picker. Use when debugging Bluetooth reconnects, auto-connect behavior, block state, refusal, or device selection.
version: 1.5.0
---

# Bluetooth auto-connect & refusal

Verified 2026-10-19 against live system (BlueZ 5.87, kernel 7.2.11-cachyos).

## Devices

- Adapter `AC:F2:3C:9F:5C:FE` (hci0, RTL8852). Adapter must stay powered.
- soundcore Q20i `B0:38:E2:78:9B:FE` - audio, switched per device by `bt-select`.
- Boult BassBox `9E:74:98:79:5D:15` - audio, switched per device by `bt-select`.
- Katana S K2 `CC:04:2E:90:66:02` - HID keyboard, never enumerated by the toggle and must stay connected in both states.
- Any future paired audio device is picked up automatically: Audio Sink/Source (110a/110b), A2DP (110d), Handsfree (111e), Headset (1108) UUIDs, `audio-*` Icon, or Class major 4 (A/V). Audio wins over HID, so a headset exposing an HID profile is still refused.

## Auto-connect dialers (removed 2026-10-19)

The user asked for no background services. `bt-autoconnect.service` and `bt-auto-trust.service` were disabled, removed from `~/.config/systemd/user/`, and forgotten from chezmoi. No process dials devices now; the TUI runs in the foreground and nothing survives it. The scripts `~/.local/bin/bt-autoconnect` and `bt-auto-trust` remain on disk as manual tools only. `blueman-applet` is not running and its AutoConnect `services` list is empty, so the plugin is inert even if launched. A checked (unblocked) device can still reconnect itself when powered on, because BlueZ accepts incoming connections; block it to prevent that.

Historical behavior, kept for debugging if a dialer ever comes back:

- `bt-autoconnect.service` -> `~/.local/bin/bt-autoconnect --daemon` (targets from `~/.config/bt-autoconnect/devices.json`). Redials 2 s after any target reports `Connected: no`; retries offline targets with backoff 20 s -> 300 s cap; also on resume and adapter power-on. Patched 2026-10-18 to skip `Blocked` targets.
- `bt-auto-trust.service` -> `~/.local/bin/bt-auto-trust`. Trusts every paired device; at start+5 s dials (`bluetoothctl connect`) every paired+trusted+disconnected audio device; routes audio to it on connect. Patched 2026-10-18 to skip `Blocked` devices.
- `blueman-applet` (systemd user unit `blueman-applet.service`), plugin `AutoConnect`: dials every device in dconf key `org.blueman.plugins.autoconnect services` on startup, on adapter power-on, and **every 60 s** (`AutoConnect.py: GLib.timeout_add(60000, self._run)`). It does NOT check `Blocked`. The list was emptied on 2026-10-19 (`dconf write /org/blueman/plugins/autoconnect/services "@a(ss) []"`) because every audio device is now refuse-able; keep all audio devices out of it. If a device refuses to stay disconnected, check this key first.
- CLI: `bt-autoconnect -s` (status), `-o` (one-shot), `--add MAC NAME`, `--remove MAC`.
- Neither custom daemon's stdout reaches the journal on this system; verify behaviorally.

## BlueZ `block` semantics (kernel + BlueZ 5.87 source-verified)

- `bluetoothctl block <mac>` => MGMT_OP_BLOCK_DEVICE -> kernel `hdev->reject_list`.
  - Incoming BR/EDR connection requests from the device are rejected in `hci_conn_request_evt`.
  - BlueZ skips profile setup for blocked devices -> no A2DP, no PipeWire sink, no audio attached; a dialed blocked device shows a `Connected: yes` half-link with no audio plus `search_cb ... error updating services: Connection timed out` journal spam.
  - Outgoing `Connect()` is NOT filtered -> every dialer must skip `Blocked` itself. Daemons patched 2026-10-18; blueman's AutoConnect plugin cannot, so refused devices must stay out of its `services` list.
- Blocked state persists in `/var/lib/bluetooth/<adapter>/<mac>/info` (`Blocked=true`).

## Refusal toggle & picker

- `Win+Shift+Enter` -> `~/.local/bin/bt-refuse-toggle` (sway bind in `~/.config/sway/config.d/40-keybindings.conf`; chezmoi source `dot_local/bin/executable_bt-refuse-toggle`). One-shot foreground command; it acts on the user-selected set of audio devices.
- Selection: `~/.config/bt-autoconnect/selection.txt`, one MAC per line (`#` comments allowed). Missing file = every paired audio device (legacy behavior); present but empty = nothing is toggled, a notification asks to run the picker.
- Picker: `~/.local/bin/bt-select` (modern pure-bash TUI with Vim keybindings: `j`/`k` navigate, `Space` toggle, `a` toggle all, `Enter` apply, `q`/`Esc` cancel) lists paired audio devices with connection and refusal status. OK applies immediately and writes the checked MACs to `selection.txt`:
  - checked -> `bluetoothctl unblock` + foreground connect with 5s timeout and status updates; if exactly one device is checked and connected, its `bluez_output.<mac>.1` sink becomes the default and current sink-inputs are moved to it;
  - unchecked -> `bluetoothctl block` + disconnect.
  It never lists input devices. Unchecking alone only removed the device from the keybind set, so the dialers or the speaker itself could still reconnect it; the apply step is what makes OFF durable.
- Read-only helpers: `bt-refuse-toggle --list` prints `MAC<TAB>NAME<TAB>blocked<TAB>connected`; `--selected` prints the effective selection. Single-pass inspection eliminates redundant BlueZ queries.
- Refused state = every selected device has `Blocked: yes` -> pressing allows: unblock all + non-blocking background connect each (zero UI lag). Anything else -> pressing refuses: block all + disconnect each. Notification lists the device names.
- Keyboard auto-connect: Katana S K2 (`CC:04:2E:90:66:02`) uses BLE HID over GATT (HoGP UUID `00001812-0000-1000-8000-00805f9b34fb`). As a BLE peripheral, it cannot initiate connections upon wake; it advertises. Auto-connect relies on:
  1. `/etc/udev/rules.d/50-bluetooth-power.rules`: Disables USB runtime autosuspend (`power/control="on"`, `power/wakeup="enabled"`) on Realtek RTL8852 USB adapter (`0489:e122`) so the radio remains active to receive wake advertisements.
  2. `/etc/bluetooth/main.conf.d/10-autoconnect.conf`: Configured with fast 50% duty cycle LE passive scanning (`ScanIntervalAutoConnect=60`, `ScanWindowAutoConnect=30`, `ScanIntervalConnect=60`, `ScanWindowConnect=30`).
  3. `~/.local/bin/bt-keyboard-reconnect` & `bt-keyboard-reconnect.service`: Dedicated, ultra-lightweight D-Bus daemon (0% CPU when dormant). Detects sleep disconnect, arms non-blocking async `Connect()`, catches wake beacons within milliseconds, and restarts `xremap.service` so custom layers attach immediately. Never interacts with audio devices.
- Safety: the selection is intersected with `audio_devices()`, so the Katana S K2 (or any input-only device) is never blocked or disconnected even if its MAC is hand-added to `selection.txt`.
- `bt-refuse-toggle --dry-run` previews without changing state. Notifications via mako (`x-canonical-private-synchronous:bt-refuse`).
- Verified 2026-10-19: both Bluetooth user services stopped, disabled, unit files and chezmoi sources removed; no BT daemon processes remain. TUI apply verified live: soundcore checked -> connected and default sink, BassBox unchecked -> `Blocked=yes`, disconnected, still off through a former dialer interval; keyboard untouched.

## Debugging quickies

- State: `bluetoothctl info B0:38:E2:78:9B:FE | grep -E "Blocked|Connected"`.
- Allow: `bluetoothctl unblock <mac>`; refuse: `bluetoothctl block <mac>`.
- Unknown dialer hunt 1 (userspace): `sudo dbus-monitor --system "destination='org.bluez'"`, then resolve the sender: `busctl --system call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetConnectionUnixProcessID s ":1.x"`.
- Unknown dialer hunt 2 (kernel): `sudo btmon` - host dials show `HCI Command: Create Connection` plus `Connection Locally Initiated`; device-initiated pages are rejected by the kernel block.
- Journal: `avdtp_connect_cb ... Host is down` / `search_cb ... Connection timed out` = something is dialing an offline/blocked device.
- bluetui has no block/refuse action (connect/disconnect/pair/trust only); its disconnect is a one-shot hang-up that auto-dialers intentionally undo.
