# Bluetooth Audio Stutter - Diagnosis and Session Log

**Status:** A1 (WiFi power save off) is applied and under observation.
A2 (force SBC) and B (rtw89 / btusb power-state changes) are deliberately
not applied yet - one change at a time while the fix is tested under load.

| Field | Value |
| :--- | :--- |
| Session date | 2026-10-19 evening to 2026-10-20 00:31 IST |
| Host | ASUS TUF Gaming F16 (FX608JH), CachyOS rolling |
| Kernel | 7.2.11-1-cachyos |
| Audio stack | PipeWire 1.6.9-1, WirePlumber 0.5.18-1.1, BlueZ 5.87-2.1 |
| Bluetooth radio | Foxconn / Hon Hai `0489:e122` (btusb), USB bus 1, port 14 |
| WiFi radio | Realtek RTL8852CE (rtw89, PCIe), SSID `1 floor `, 2.4 GHz ch6 |
| Headset | soundcore Q20i (`B0:38:E2:78:9B:FE`), A2DP |
| Document path | `~/.local/share/chezmoi/docs/audio/2026-10-20_BLUETOOTH_AUDIO_STUTTER.md` (exposed as `~/docs/audio/`) |

---

## 1. Objective

Two related goals:

1. Remove Bluetooth auto-connect services entirely. Connection control is
   manual only, through the `bt-select` TUI (foreground process, no daemon,
   nothing survives after it exits).
2. Diagnose and fix A2DP stutter/jitter on the soundcore Q20i (the user
   initially suspected CPU load from compiles).

---

## 2. System Context

| Item | State during this session |
| :--- | :--- |
| Internet path | USB tethered vivo I2207 phone (`2d95:600a`, rndis_host, bus 1 port 5), `10.104.169.30`, default route via `10.104.169.249`, metric 50 |
| WiFi | `1 floor ` on wlan0, `192.168.1.118`, metric 20600, gateway reachable, no WAN reachability at test time |
| Audio output | `bluez_output.B0_38_E2_78_9B_FE.1`, codec AAC, default sink |
| A2DP policy | `bluez5.roles = [ a2dp_sink a2dp_source ]`, `hfphsp-backend = "none"` |
| PipeWire graph | quantum 512, min 64, max 2048, rate 48000 |

Important consequence: normal internet traffic does **not** run over WiFi on
this machine while the phone tether is plugged in. WiFi/Bluetooth coexistence
tests therefore have to force traffic over wlan0, and wlan0 currently has no
working upstream (see section 9).

---

## 3. Timeline

| Time (IST) | Event |
| :--- | :--- |
| 2026-10-19 22:26 | `~/.config/bt-autoconnect/` updated during TUI work |
| 2026-10-19 22:36 | `selection.txt` written (soundcore Q20i only) |
| 2026-10-19 22:38 | `bt-select` and `bt-refuse-toggle` last modified |
| 2026-10-19 evening | `bt-autoconnect.service` and `bt-auto-trust.service` stopped, disabled, unit files and chezmoi sources deleted |
| 2026-10-19 23:47 | A1 applied (NetworkManager keyfile `1 floor .nmconnection` rewritten, `powersave=2`) |
| 2026-10-19 23:53:29 | One A2DP transport failure: `Failure in Bluetooth audio transport ... sep2/fd0`, sink node `...1-102` went to error |
| 2026-10-19 23:53:39 | Q20i reconnected, new sink node `...1-122` |
| 2026-10-19 23:56 - 2026-10-20 00:16 | No further transport events, no kernel `hci0` events; audio verified running |
| 2026-10-20 00:19 | Stress probe attempt 1 failed: Cloudflare 403 on 150 MB requests, zero bytes transferred |
| 2026-10-20 00:22 | Routing discovery: default route is the USB tether, not wlan0; wlan0 has no WAN |
| 2026-10-20 00:26 onward | Pre-flight verification for pending A2/B changes (module parameters, initramfs) |

---

## 4. Bluetooth Control Redesign (Manual Only)

### 4.1 Daemons removed

`bt-autoconnect.service` and `bt-auto-trust.service` (user units under
`~/.config/systemd/user/`) were:

- stopped and disabled,
- deleted from disk,
- deleted from the chezmoi source repo (working-tree deletion, not yet committed).

Verification performed:

```bash
systemctl list-unit-files | grep -iE 'bt-|bluetooth'        # only bluetooth.service + bluetooth.target
systemctl --user list-unit-files | grep -iE 'bt-|bluetooth' # only bluetooth.target
pgrep -af 'bt-autoconnect|bt-auto-trust'                     # nothing
sway -C                                                      # exit 0
```

No `bt-*` unit files or processes remain. Blocking (`bluetoothctl block`) is
what keeps unchecked devices from being re-dialed by anything else.

### 4.2 bt-select (TUI)

`~/.local/bin/bt-select` - whiptail checklist, audio devices only
(input devices such as the Katana S K2 keyboard are never listed).

| Checkbox | Applied action |
| :--- | :--- |
| Checked (ON) | `bluetoothctl unblock`, then foreground `timeout 12 bluetoothctl connect` if not already connected; if it is the only checked device, set it as default sink and move all current streams to it |
| Unchecked (OFF) | `bluetoothctl block` + disconnect if connected |

Details:

- Off is applied before on, so two devices are never intentionally connected at once.
- Checked set is written to `~/.config/bt-autoconnect/selection.txt` (one MAC per line).
- A `notify-send` summary (ON/OFF device names) is shown after applying.
- Current selection: `B0:38:E2:78:9B:FE` (soundcore Q20i only).

### 4.3 bt-refuse-toggle (Win+Shift+Enter)

`~/.local/bin/bt-refuse-toggle`, bound in
`~/.config/sway/config.d/40-keybindings.conf` line 70:

```ini
bindsym $mod+Shift+Return exec --no-startup-id ~/.local/bin/bt-refuse-toggle
```

Behavior (foreground, selection-aware):

- If every selected device is blocked: unblock all and connect with foreground
  `timeout 12 bluetoothctl connect` (auto-connect ON).
- Otherwise: block and disconnect the whole selection (auto-connect OFF).
- Verifies the resulting `Blocked:` state and reports a failure notification if
  it does not match.
- Helper modes: `--list` (MAC, name, blocked, connected), `--selected`
  (effective selection), `--dry-run`.
- Selection semantics: missing `selection.txt` = all paired audio devices;
  present but empty = nothing is toggled.

### 4.4 Inert scripts

These remain on disk but nothing references them (checked sway, systemd, fish,
zsh, udev, autostart):

- `~/.local/bin/bt-autoconnect`
- `~/.local/bin/bt-auto-trust`
- `~/.local/bin/bt-battery-notify`
- `~/.local/bin/bt-profile`
- `~/.config/bt-autoconnect/devices.json` (used only by the inert manual script)

They are cleanup candidates, not removed yet.

---

## 5. Service Audit (Read-Only)

- 23 system services and 21 user services were reviewed; all are load-bearing.
- Trim candidates identified but **not applied**:
  - `gvfs-gphoto2-volume-monitor` and `gvfs-mtp-volume-monitor` (about 13 MB RSS),
  - `cachyos-rate-mirrors.timer` (optional; mirrors already configured),
  - the inert Bluetooth scripts listed in 4.4.

---

## 6. Root-Cause Analysis

### 6.1 Evidence

Kernel (before the fix):

```
Bluetooth: hci0: link tx timeout
Bluetooth: hci0: killing stalled connection b0:38:e2:78:9b:fe
```

WirePlumber (before the fix):

```
spa.bluez5: Missing completion reports for packet ... Bluetooth adapter firmware bug?
```

Radio and power state at diagnosis time:

| Item | Value at diagnosis | Meaning |
| :--- | :--- | :--- |
| WiFi power save | on | periodic radio sleep, hurts coexistence |
| `rtw89_core.disable_ps_mode` | N | driver low-power mode enabled |
| `rtw89_pci.disable_aspm_l1` / `l1ss` / `clkreq` | N / N / N | PCIe power-state transitions enabled |
| `btusb.enable_autosuspend` | Y | BT USB device may autosuspend |
| USB 1-14 `power/control` | auto, 2000 ms delay | matches btusb autosuspend |

### 6.2 Working hypothesis

The RTL8852CE is a combo chip sharing one 2.4 GHz front end between WiFi and
Bluetooth. WiFi power save plus rtw89 power-state transitions periodically
stall the shared radio, which shows up as A2DP transport failures and
`hci0: link tx timeout`, not as a CPU problem.

An additional, unverified hypothesis from this session: the BT radio (bus 1,
port 14) and the USB-tethered internet uplink (bus 1, port 5) share the same
xHCI controller, so heavy tether traffic and A2DP share one USB 2.0 bus. This
has not been tested.

### 6.3 Classification of the 2026-10-19 23:53 event

One A2DP transport failure followed by a reconnect 10 seconds later, with no
`hci0` link timeout, is not the old radio-stall signature. It is one data
point, not proof of a fix. Current decision rule:

- No further drops over hours of loaded use: A1 was the fix; leave A2/B alone.
- Another transport error/reconnect without `hci0` timeout: apply A2 (SBC).
- `hci0: link tx timeout` / stalled-connection kills return: coexistence
  again; re-test with WiFi off, then consider B.

---

## 7. Applied Fix A1 - WiFi Power Save Off

Applied 2026-10-19 23:47 (NetworkManager keyfile mtime). The connection
profile is addressed by UUID because its name literally ends with a space
(`1 floor `).

```bash
sudo iw dev wlan0 set power_save off
nmcli connection modify 2787a05e-c867-4d75-b138-155aa8446e90 802-11-wireless.powersave 2
nmcli connection up 2787a05e-c867-4d75-b138-155aa8446e90
```

`powersave=2` means disabled in NetworkManager (0 = default, 3 = enabled), so
the setting is persistent and reapplies on every connect. `iw` alone is not
persistent.

Verified after applying:

```
Power save: off
802-11-wireless.powersave: 2 (disable)
GENERAL.STATE: 100 (connected), IP4.ADDRESS 192.168.1.118/24
ping gateway: 2 packets, 0% loss, avg 2.262 ms
kernel BT events in the following 5 minutes: none
```

---

## 8. Test-Phase Observations

- 2026-10-19 23:53:29 - single transport failure and reconnect (see 6.3).
- 2026-10-19 23:56 to 2026-10-20 00:16 - no transport events, no `hci0`
  events; audio playing, Q20i default sink, `pw-top` ERR 0 for the bluez node.
- The event rate so far is too low to conclude anything. The fix must be tested
  under realistic load (dependency downloads, video) over several hours.

Monitoring while testing:

```bash
pw-top                                     # watch the ERR column of the bluez row
journalctl -k -f -o short-iso | grep --line-buffered -i hci0
```

Post-session summary:

```bash
journalctl -k --since "-3 hours" | grep -iE 'hci0|link tx'
journalctl --user -u wireplumber --since "-3 hours" | grep -iE 'transport|missing completion'
```

How to read the outcome:

| Result | Interpretation | Next step |
| :--- | :--- | :--- |
| No events at all | A1 fixed it | Leave A2/B alone |
| Transport errors/reconnects, no `hci0` timeout | Pattern, not a fluke | Apply A2 (section 11.1) |
| `hci0` timeouts return | Coexistence again | WiFi-off control test, then B |

---

## 9. Stress-Probe Attempt and Network Findings

Goal: put WiFi under heavy load while the Q20i plays, to test coexistence.
Result: **no valid WiFi-load test has been performed yet.**

What happened:

1. First probe (4 x 150 MB from `speed.cloudflare.com`) returned HTTP 403 with
   1 byte immediately. Cloudflare's public endpoint rejects that request size;
   no load was generated.
2. The 5 MB variant returned HTTP 200 and transferred at about 7.6 MB/s - but
   over the USB tether, not WiFi:
   `default via 10.104.169.249 dev enp0s20f0u5 metric 50` (tether) versus
   `default via 192.168.1.1 dev wlan0 metric 20600` (WiFi).
3. Forcing traffic over wlan0 (`curl --interface wlan0`, also with `-4`):
   - `ip route get 1.1.1.1 oif wlan0` resolves correctly via `192.168.1.1`,
   - ping to the WiFi gateway works (avg 2.95 ms),
   - `http://192.168.1.1/` answers 302,
   - ping/HTTP to external addresses fails (curl exit 7, `http=000`).

Conclusion: the `1 floor ` WiFi currently has no working upstream (router or
WAN issue, possibly a captive portal). Until that is fixed, WiFi-load
coexistence testing must wait, or the tether must be unplugged and the WiFi
upstream resolved. The IPv6 theory was tested and ruled out (`-4` fails the
same way).

---

## 10. Pre-Flight Checks for Pending Changes (Done)

Kernel 7.2.11-1-cachyos parameter names confirmed via `modinfo`:

| Module | Parameters present |
| :--- | :--- |
| `rtw89_core` | `disable_ps_mode` |
| `rtw89_pci` | `disable_aspm_l1`, `disable_aspm_l1ss`, `disable_clkreq` |
| `btusb` | `enable_autosuspend` |

Initramfs check:

- `/etc/mkinitcpio.conf`: `MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)`
- `initramfs-linux-cachyos.img` contains 0 `rtw89`/`btusb` entries.

Therefore modprobe.d changes do not require `mkinitcpio -P`; a plain reboot
loads those modules with the new options.

---

## 11. Pending Changes (Not Applied)

Trigger: only after the decision rule in section 8 says so.

### 11.1 A2 - Prefer SBC over AAC

Edit `~/.config/wireplumber/wireplumber.conf.d/11-bluetooth-policy.conf`
line 17:

```
bluez5.codecs = [ aac sbc_xq sbc ]
```
to
```
bluez5.codecs = [ sbc sbc_xq aac ]
```

Then:

```bash
chezmoi add ~/.config/wireplumber/wireplumber.conf.d/11-bluetooth-policy.conf
systemctl --user restart wireplumber
# reconnect the Q20i (bt-select or bluetoothctl disconnect/connect)
pactl list sinks | grep api.bluez5.codec     # expect: sbc
```

If AAC is still negotiated, drop it entirely: `[ sbc sbc_xq ]`, restart
WirePlumber, reconnect. SBC is slightly lower quality but lighter and more
robust than AAC on this adapter.

### 11.2 B - Driver power-state changes (requires snapshot + reboot)

```bash
sudo snapper -c root create -d "before rtw89/btusb power-state tuning"
```

`/etc/modprobe.d/rtw89.conf`:

```
options rtw89_core disable_ps_mode=y
options rtw89_pci disable_aspm_l1=y
options rtw89_pci disable_aspm_l1ss=y
options rtw89_pci disable_clkreq=y
```

`/etc/modprobe.d/btusb.conf`:

```
options btusb enable_autosuspend=N
```

Then `sudo reboot` (no `mkinitcpio -P` needed, see section 10).

Verify after reboot:

```bash
cat /sys/module/rtw89_core/parameters/disable_ps_mode        # Y
cat /sys/module/rtw89_pci/parameters/disable_aspm_l1         # Y
cat /sys/module/rtw89_pci/parameters/disable_aspm_l1ss       # Y
cat /sys/module/rtw89_pci/parameters/disable_clkreq          # Y
cat /sys/module/btusb/parameters/enable_autosuspend          # N
cat /sys/bus/usb/devices/1-14/power/control                  # on
```

Alternative for the btusb part without a reboot (device-specific udev rule):

```
# /etc/udev/rules.d/50-btusb-no-autosuspend.rules
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0489", ATTR{idProduct}=="e122", TEST=="power/control", ATTR{power/control}="on"
```

Front-load trade-off: slightly higher idle power and heat.

---

## 12. Revert Procedures

A1:

```bash
nmcli connection modify 2787a05e-c867-4d75-b138-155aa8446e90 802-11-wireless.powersave 0
sudo iw dev wlan0 set power_save on
```

A2: change the codec list back to `[ aac sbc_xq sbc ]`, `systemctl --user
restart wireplumber`, reconnect the headset. The file is chezmoi-managed, so
`chezmoi diff` / `chezmoi apply` also works.

B: delete `/etc/modprobe.d/rtw89.conf` and `/etc/modprobe.d/btusb.conf`, then
reboot (initramfs does not contain these modules). The root Snapper snapshot
taken before the change is the backstop.

---

## 13. Current State Snapshot (2026-10-20 00:31)

| Item | Value |
| :--- | :--- |
| WiFi power save | off (persistent, profile `powersave=2`) |
| soundcore Q20i | connected, Blocked=no, default sink, codec AAC |
| Boult BassBox | Blocked=yes, disconnected |
| Selection file | `B0:38:E2:78:9B:FE` only |
| BT services | none (only `bluetooth.service` + `bluetooth.target`) |
| `rtw89` params | all `N` (unchanged) |
| `btusb.enable_autosuspend` | `Y` (unchanged) |
| USB 1-14 power control | auto, 2000 ms delay (unchanged) |
| WirePlumber policy | roles A2DP only, hfphsp none, sbc-xq enabled, msbc disabled, codecs `[ aac sbc_xq sbc ]`, latency 1024/48000 |
| PipeWire policy | quantum 512, min 64, max 2048, rate 48000 |
| Scripts/skill sync | `bt-select`, `bt-refuse-toggle`, WirePlumber conf in sync with chezmoi; skill `bluetooth-autoconnect` v1.5.0 |

Uncommitted chezmoi git changes from this session include the two deleted
`bt-*.service` sources, `40-keybindings.conf`, the skill update, and this
document. Commit when ready.

---

## 14. Known Issues / Notes

1. `bt-refuse-toggle` header comment line 13 still says "background connect";
   the implementation is foreground `timeout 12 bluetoothctl connect`
   (line 167). Comment fix pending.
2. The `1 floor ` WiFi has no WAN while the phone tether is connected; the
   coexistence test cannot run over wlan0 until that is resolved.
3. `~/docs/audio` is a symlink to `~/.local/share/chezmoi/docs/audio`; this
   file therefore lives directly in the chezmoi repo tree (untracked in git).
4. NetworkManager profile name and WiFi SSID both end with a space; always use
   the UUID (`2787a05e-c867-4d75-b138-155aa8446e90`) in scripts.

---

## 15. Sources

- RTL8852CE Linux latency/audio stutter fix:
  <https://github.com/abdustartus/rtl8852ce-linux-latency-audio-stutter-fix>
- CachyOS forum, RTL8852BE regression after firmware update:
  <https://discuss.cachyos.org/t/regression-on-a-realtek-rtl8852be-card-after-a-recent-firmware-update/13871>

---

## Appendix A - Related Files

| Path | Role |
| :--- | :--- |
| `~/.local/bin/bt-select` | manual picker TUI (applies checked/unchecked state) |
| `~/.local/bin/bt-refuse-toggle` | Win+Shift+Enter toggle, `--list` / `--selected` helpers |
| `~/.config/bt-autoconnect/selection.txt` | checked device set |
| `~/.config/bt-autoconnect/devices.json` | used only by the inert manual script |
| `~/.config/wireplumber/wireplumber.conf.d/11-bluetooth-policy.conf` | codecs, roles, latency |
| `~/.config/pipewire/pipewire.conf.d/10-low-latency.conf` | quantum/rate |
| `~/.config/sway/config.d/40-keybindings.conf` | line 70, refusal toggle binding |
| `~/.agents/skills/bluetooth-autoconnect/SKILL.md` | v1.5.0, daemonless semantics |
