---
name: bluetooth-autoconnect
description: Bluetooth auto-connect and refusal on this machine - the three dialers (bt-autoconnect, bt-auto-trust, blueman AutoConnect plugin), BlueZ block semantics, and the Q20i refusal toggle (Win+Shift+Enter). Use when debugging Bluetooth reconnects, auto-connect behavior, block state, or refusal.
version: 1.1.0
---

# Bluetooth auto-connect & refusal

Verified 2026-10-18 against live system (BlueZ 5.87, kernel 7.2.9-cachyos).

## Devices

- Adapter `AC:F2:3C:9F:5C:FE` (hci0, RTL8852). Adapter must stay powered.
- soundcore Q20i `B0:38:E2:78:9B:FE` - refusal toggle target.
- Boult BassBox `9E:74:98:79:5D:15` - normal auto-connect target.
- Katana S K2 `CC:04:2E:90:66:02` - HID, not involved.

## The three auto-connect dialers (source-verified)

All three must respect a refusal, or the device reconnects within ~60 s:

- `bt-autoconnect.service` -> `~/.local/bin/bt-autoconnect --daemon` (targets from `~/.config/bt-autoconnect/devices.json`). Redials 2 s after any target reports `Connected: no`; retries offline targets with backoff 20 s -> 300 s cap; also on resume and adapter power-on. Patched 2026-10-18 to skip `Blocked` targets.
- `bt-auto-trust.service` -> `~/.local/bin/bt-auto-trust`. Trusts every paired device; at start+5 s dials (`bluetoothctl connect`) every paired+trusted+disconnected audio device; routes audio to it on connect. Patched 2026-10-18 to skip `Blocked` devices.
- `blueman-applet` (systemd user unit `blueman-applet.service`), plugin `AutoConnect`: dials every device in dconf key `org.blueman.plugins.autoconnect services` on startup, on adapter power-on, and **every 60 s** (`AutoConnect.py: GLib.timeout_add(60000, self._run)`). It does NOT check `Blocked`. The Q20i was removed from that list on 2026-10-18 (BassBox kept). If a device refuses to stay disconnected, check this key first.
- CLI: `bt-autoconnect -s` (status), `-o` (one-shot), `--add MAC NAME`, `--remove MAC`.
- Neither custom daemon's stdout reaches the journal on this system; verify behaviorally.

## BlueZ `block` semantics (kernel + BlueZ 5.87 source-verified)

- `bluetoothctl block <mac>` => MGMT_OP_BLOCK_DEVICE -> kernel `hdev->reject_list`.
  - Incoming BR/EDR connection requests from the device are rejected in `hci_conn_request_evt`.
  - BlueZ skips profile setup for blocked devices -> no A2DP, no PipeWire sink, no audio attached; a dialed blocked device shows a `Connected: yes` half-link with no audio plus `search_cb ... error updating services: Connection timed out` journal spam.
  - Outgoing `Connect()` is NOT filtered -> every dialer must skip `Blocked` itself. Daemons patched 2026-10-18; blueman's AutoConnect plugin cannot, so refused devices must stay out of its `services` list.
- Blocked state persists in `/var/lib/bluetooth/<adapter>/<mac>/info` (`Blocked=true`).

## Refusal toggle

- `Win+Shift+Enter` -> `~/.local/bin/bt-refuse-toggle` (sway bind in `~/.config/sway/config.d/40-keybindings.conf`; chezmoi source `dot_local/bin/executable_bt-refuse-toggle`).
- From refused: unblocks + background connect attempt => notification "Bluetooth auto-connect ON".
- From allowed: blocks + disconnects => notification "Bluetooth auto-connect OFF".
- `bt-refuse-toggle --dry-run` previews without changing state. Notifications via mako (`x-canonical-private-synchronous:bt-refuse`).

## Debugging quickies

- State: `bluetoothctl info B0:38:E2:78:9B:FE | grep -E "Blocked|Connected"`.
- Allow: `bluetoothctl unblock <mac>`; refuse: `bluetoothctl block <mac>`.
- Unknown dialer hunt 1 (userspace): `sudo dbus-monitor --system "destination='org.bluez'"`, then resolve the sender: `busctl --system call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetConnectionUnixProcessID s ":1.x"`.
- Unknown dialer hunt 2 (kernel): `sudo btmon` - host dials show `HCI Command: Create Connection` plus `Connection Locally Initiated`; device-initiated pages are rejected by the kernel block.
- Journal: `avdtp_connect_cb ... Host is down` / `search_cb ... Connection timed out` = something is dialing an offline/blocked device.
- bluetui has no block/refuse action (connect/disconnect/pair/trust only); its disconnect is a one-shot hang-up that auto-dialers intentionally undo.
