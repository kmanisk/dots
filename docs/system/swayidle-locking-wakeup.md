# Swayidle, Screen Locking & Hardware Wakeup Architecture

Target machine: ASUS TUF Gaming F16 (FX608JH) · CachyOS Linux (Kernel 7.2.11-cachyos) · Sway (Wayland)

---

## 1. Overview & Pipeline Timeline

Screen locking, display power-saving (DPMS), and hardware suspension are governed by three interacting layers:
1. **Compositor Idle Daemon (`swayidle`):** Configured in `~/.config/sway/config.d/60-autostart.conf`.
2. **Session Locker (`swaylock`):** Invoked with `-f -c 000000` (black background, daemonized).
3. **System Power Management (`systemd-logind` / ACPI):** Manages `s2idle` hardware low-power states.

### Timeline of Inactivity
```
   0 min                  5 min                  10 min                   ~30 min
─────┼──────────────────────┼──────────────────────┼────────────────────────┼────────►
  Activity             swaylock               DPMS Off                  s2idle Suspend
                      (Screen Locked)       (Displays Off)             (Hardware Sleep)
```

1. **300 seconds (5 min):** `swayidle` executes `swaylock -f -c 000000`. The session is locked, but the display remains active.
2. **600 seconds (10 min):** `swayidle` executes `swaymsg "output * dpms off"`. Panel backlight and display outputs enter D3/DPMS off.
3. **Extended Inactivity:** `systemd-logind` transitions the system from idle into hardware suspend (`s2idle`).

---

## 2. Suspend to Idle (`s2idle`) vs Display DPMS Off

Understanding why input devices behave differently requires distinguishing between software DPMS off and hardware `s2idle`:

| State | Compositor & Drivers | Userspace Processes (`xremap`, `sway`) | Wakeup Mechanism |
| :--- | :--- | :--- | :--- |
| **DPMS Off** | Running | **Active** (listening to evdev) | Any Wayland seat input event wakes outputs via `swayidle resume`. |
| **`s2idle` (Suspend)** | Low-power / D3 | **Completely Frozen** (`PM: suspend entry`) | Hardware interrupts (ACPI GPE / PCI PME) only. |

When the laptop enters `s2idle`:
- The Intel SoC enters package low-power C10 state.
- All userspace processes are frozen (`Freezing user space processes completed`).
- Software key-remapping (`xremap`), libinput event dispatch, and Wayland compositor listeners are halted.
- The machine can only be woken by hardware interrupt lines physically routed to the ACPI wake controller.

---

## 3. Peripheral Wakeup Behavior & Root Causes

### A. USB Mouse (Working)
- **Interface:** Intel xHCI USB 3.0 Controller (`0000:00:14.0`).
- **ACPI Node:** `XHCI` in `/proc/acpi/wakeup` (`XHCI S3 *enabled pci:0000:00:14.0`).
- **Sysfs Wakeup:** `power/wakeup = enabled` on the USB mouse interface.
- **Mechanism:** Moving or clicking the mouse sends a USB resume signaling packet to the xHCI host controller. The controller fires a hardware PCI PME / ACPI GPE interrupt to the Intel SoC, immediately waking the system.

### B. Internal Laptop Keyboard (Ignored during Suspend)
- **Interface:** `i8042` PS/2 Controller (`AT Translated Set 2 keyboard`, IRQ 1).
- **Embedded Controller Routing:** Hardware keystrokes route through the ASUS Embedded Controller (EC).
- **Firmware Limitation:**
  - ASUS UEFI firmware for the TUF FX608JH does not map IRQ 1 (`i8042`) as an ACPI General Purpose Event (GPE) wakeup line.
  - While `/sys/devices/platform/i8042/serio0/power/wakeup` reports `enabled`, the underlying ASUS EC does not pass keyboard scan-codes as an unmasked wake interrupt while the CPU package resides in C10 sleep.
  - Consequently, pressing keys on the built-in keyboard cannot wake the hardware from `s2idle`.

### C. Katana S K2 Bluetooth Keyboard (Ignored during Suspend)
- **Interface:** Internal Foxconn/MediaTek Bluetooth 5.3 Adapter (`0489:e122`, USB bus 1, port 14).
- **Wakeup Policy (`/etc/udev/rules.d/81-bluetooth-wakeup.rules`):**
  ```udev
  ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0489", ATTRS{idProduct}=="e122", ATTR{power/wakeup}="disabled"
  ```
- **Rationale:** Bluetooth wakeup is explicitly disabled to prevent rogue wake-loops (e.g. background peripheral reconnects or beacon scans waking the laptop inside a bag).
- **Mechanism:** During suspend, the Bluetooth radio powers down into low-power D3 state. The BLE connection to the Katana keyboard drops. The keyboard cannot communicate with the host until the host is already awake.
- **Recovery:** Upon system wake (via mouse or power button), Sway's `after-resume` hook in `~/.config/sway/config.d/60-autostart.conf` automatically reconnects the Katana keyboard within 2 seconds:
  ```ini
  after-resume 'swaymsg "output * dpms on"; bluetoothctl connect CC:04:2E:90:66:02'
  ```

---

## 4. Hardware Wakeup Matrix

| Device | Subsystem | Wake State | Hardware / Firmware Condition |
| :--- | :--- | :--- | :--- |
| **USB Mouse** | xHCI (USB) | **Operational** | ACPI GPE enabled (`XHCI *enabled`). |
| **Power Button** | ACPI PNP0C0C | **Operational** | ACPI power button event line. |
| **Lid Open** | ACPI PNP0C0D | **Operational** | ACPI lid switch sensor (`PNP0C0D:01`). |
| **Laptop Keyboard** | `i8042` / EC | **Inert** | ASUS firmware does not map PS/2 IRQ 1 to ACPI wake in `s2idle`. |
| **Bluetooth Keyboard** | `btusb` (0489:e122) | **Inert** | Wakeup disabled via udev (`81-bluetooth-wakeup.rules`) to guard battery/thermals. |

---

## 5. Diagnostic Commands

Inspect active ACPI wakeup sources:
```bash
cat /proc/acpi/wakeup | grep -E "enabled|Device"
```

Inspect kernel wakeup sources and hit counters:
```bash
sudo cat /sys/kernel/debug/wakeup_sources | grep -E "serio|XHCI|0000:00:14.0"
```

Inspect recent suspend and resume transitions:
```bash
journalctl -b 0 | grep -iE "PM: suspend|nvidia-resume|nvidia-suspend"
```
