# NVIDIA Digital Vibrance on Wayland (dGPU mode, current)

**Status:** ACTIVE — the working vibrance implementation on this machine.
Applies only in `AsusMuxDgpu` (NVIDIA owns eDP-1). For the retired Hybrid-era
Intel system, see [`../archive/intel-hardware-vibrance.md`](../archive/intel-hardware-vibrance.md).

**Result:** `RTX 5050 → NVIDIA display pipeline → Digital Vibrance → eDP-1`.
Zero shaders, zero FPS cost, no daemon — direct NVKMS ioctl at login.

---

## 1. Package

- `nvibrant-bin 1.3.0-1` (AUR, upstream [Tremeschin/nvibrant](https://github.com/Tremeschin/nvibrant)).
  Deps: python + python-packaging. Installed 2026-10-02 under Snapper
  pre-snapshot (plus automatic pre/post transaction snapshots).
- `/usr/bin/nvibrant` is the packaged Python wrapper. As of 2026-11-08, its
  newest embedded native blob is for the **615.71.09** driver family. Using it
  with NVIDIA **620.70.06** failed `NVKMS_ALLOC_DEVICE` (`AllocDevice ioctl failed`).
- The working current backend is a native 620.70.06 executable compiled against
  the matching installed `/usr/src/nvidia-620.70.06` DKMS headers and stored at
  `~/.local/libexec/nvibrant/nvibrant-620.70.06`. No system package is replaced.
  The wrapper `~/.local/bin/nvibrant-current` selects **only an exact loaded-driver
  version**, checks real display ioctl success, and fails closed on unsupported
  versions. It neither downloads binaries nor starts any background service.

## 2. Display mapping (detected, not guessed)

NVKMS enumerates one display with 6 connectors; only connector **2 (DP)**
reports `Success` — the internal panel (no externals attached; Sway shows
only eDP-1). CLI takes **positional per-connector values**, so the panel is
argv index 3:

```bash
nvibrant-current 0 0 <value>   # connectors 0,1 = 0 (disconnected, harmless)
```

## 3. CLI semantics (verified against upstream `main.cpp`)

- Range per connector: **-1024..1023**, neutral **0**. No linear relation to
  the old 1.30 CTM multiplier (different color math) — values are chosen by
  eye, not converted.
- ⚠️ **No read path exists.** Bare `nvibrant` is *not* a query: it writes
  fallback 0 to every connected output. Every invocation must pass all
  leading values, or it silently resets the panel to neutral.
- Previous baseline tested value: **800** — screenshot-histogram check on identical desktop
  content showed mean saturation 0.047 → 0.126 (~2.7x). Revert:
  `nvibrant-current 0 0 0`. On 2026-11-08 the saved value was **614**
  (Windows-style 80%) when the native repair was tested and applied.

## 4. Persistence & Canonical Execution (`apply-vibrance`)

Display vibrance across boot and reload is unified into the canonical one-shot helper `~/.local/bin/apply-vibrance`:

- **One-shot & Idempotent:** Runs at Sway startup via `~/.local/bin/sway-run` (and `~/.local/bin/launch-desktop`).
- **Sway Reload Hook:** Automatically re-applies upon `swaymsg reload` via `exec_always --no-startup-id ~/.local/bin/apply-vibrance` in `~/.config/sway/config.d/10-display.conf`.
- **Dynamic Hardware Detection:**
  - Evaluates active DRM connector status and vendor ID (`/sys/class/drm/card*-*/status` and `device/vendor`).
  - `0x10de` (NVIDIA owns active panel): Reads `~/.config/nvibrant` and executes `nvibrant-current 0 0 "$NVIB_VAL"`.
  - `0x8086` (Intel owns active panel): Reads `~/.config/vibrance` and applies Intel CTM via `ctm-test --set "$VIB_VAL"`.
  - Reconciles cleanly across pending reboot states when `supergfxd` mode differs from physical MUX latch.
- **Zero Daemons:** Strictly one-shot; exits immediately without background processes, loops, or polling watchers.

## 5. Driver updates and shortcut verification (2026-11-08)

NVIDIA 620.70.06 changed NVKMS structures, so an old nvibrant binary selected by
`nvibrant-bin 1.3.0` was no longer compatible. **Do not downgrade NVIDIA** or
copy the old 615 blob under a new filename. A locally compiled executable from
upstream [`Tremeschin/nvibrant`](https://github.com/Tremeschin/nvibrant)
revision `9bafd52d0ab3202cdf76a49cb703e25c03a0d8af` using the exact
matching NVIDIA DKMS header tree successfully set vibrance on connector 2
(DP, the internal panel). The source fetch is pinned to this commit and SHA256
`2117557edb14a11e9e9506193b896aacc446a12ab2cfd00dd3d9ec221e131d28`.

**Automatic exact-driver rebuild (2026-11-21):** After a pacman NVIDIA driver
upgrade, the installed root-owned ALPM hook
`/etc/pacman.d/hooks/95-nvibrant-rebuild.hook` calls
`runuser -u onyx -- ~/.local/bin/nvibrant-post-update` as a **post-transaction**
step. The unprivileged wrapper invokes `nvibrant-build-local --installed --offline`
using the locally cached, pinned/SHA-256 verified upstream C++ source at
`~/.local/share/nvibrant-src/main.cpp`. It compiles against the **installed**
`/usr/src/nvidia-VERSION` DKMS headers, even when NVIDIA is disabled in Eco
mode or the old NVIDIA module is still loaded. It never needs a GPU ioctl,
network access, background service, or compositor restart. It skips already
built versions. If the source is missing or compilation fails, the hook warns
without failing the completed package upgrade; repair manually with
`nvibrant-build-local` (which fetches and verifies the pinned source if missing).

The **620.73.04** helper was successfully built offline on 2026-11-21 while
the host still ran kernel 7.3.4 and Intel Eco display mode. The native ioctl
on NVIDIA 620.73.04 **cannot be verified** until the new module is loaded and
NVIDIA drives the display after reboot. Test then with:

```bash
nvibrant-ctl inspect
nvibrant-current 0 0 "$(cat ~/.config/nvibrant)"
```

The hook source lives in `scripts/pacman-hooks/95-nvibrant-rebuild.hook` in
chezmoi and is copied root-owned to `/etc/pacman.d/hooks/` for ALPM to load.

The wrapper uses `/sys/module/nvidia/version` to select an exact
`~/.local/libexec/nvibrant/nvibrant-$version` native executable; if a matching
binary does not exist, commands fail safely with a rebuild instruction. The
build requires `g++`, the **installed** NVIDIA DKMS source tree, and `curl`
only for an initial pinned source download. The source file is verified against
its SHA-256 before compilation. An NVIDIA update that changes the upstream
NVKMS ioctl ABI might require a new audited upstream revision; do not work
around failures by pretending the old binary is compatible.

`Caps+X` invokes `nvibrant-ctl up` (+5%), and `Caps+Z` invokes
`nvibrant-ctl down` (-5%) through the active xremap universal hardware keymap.
**Current, 2026-11-10 (after user-requested rollback):** Caps+X/Z again change
vibrance by an **instantaneous** 5% step, without a 230 ms ramp or worker.
Xremap launches `/home/onyx/.local/bin/nvibrant-ctl` directly instead of using
an extra `/bin/sh -c` intermediary. The optimized Bash controller uses integer
arithmetic, a short `flock` around each read/ioctl/persistence operation to
avoid missed rapid keypresses, and an asynchronous OSD notification. It calls
`nvibrant-current` once per change, retaining the exact-driver guard and a
verified connected-panel ioctl success before the new preference is saved.
The direct-controller six-command live test on NVIDIA 620.70.06 (85% -> 90%
-> 85% -> 90% -> 95% -> 90% -> 85%) measured 12.6–17.5 ms per complete
keypress command (13.2 ms median); it preserved the user's initial raw **716**.
The original night-light, brightness and volume controls have also been
restored to immediate behavior. Physical keypress feel still needs a manual
acceptance check. Earlier smoothing attempts remain documented as history in
`docs/system/interactive-control-smoothing.md`.

### dGPU MUX transition fix (2026-11-20)

After a Windows Eco/iGPU-to-Linux dGPU MUX transition, hardware checks confirmed
`gpu_mux_mode=0`, connected `card1-eDP-1`, and NVIDIA vendor `0x10de` on
`/sys/class/drm/card1/device/vendor`. The controller had incorrectly read
`/sys/class/drm/card1-eDP-1/device/vendor` (nonexistent), so Caps+X/Z only
saved preferences using the Intel fallback without issuing an NVIDIA ioctl.
`nvibrant-ctl` now resolves the connected connector's parent `cardN` before
reading its PCI vendor. Its `inspect` command also reads the loaded NVIDIA
version correctly instead of returning an empty string.

Verified with NVIDIA 620.70.06: direct NVKMS connector 2 accepted the saved
value, `nvibrant-ctl down` applied raw `921` (95%) immediately, and
`nvibrant-ctl up` restored raw `1023` (100%) and the original saved values;
`apply-vibrance` then exited successfully. Xremap is active, but physical
Caps+X/Z keypress acceptance remains to be checked by the user.
No MUX switch, compositor restart, driver rebuild, or daemon was needed.

## 6. CS2 note

Vibrance is applied in the dGPU display pipeline at scanout and cannot alter
render frametimes — same mechanism argument as the old CTM case. The uncapped
dGPU result stands independent of this setting.

## 7. Files

| Path | Role |
|------|------|
| `/usr/bin/nvibrant` | Installed 1.3.0 AUR tool; known incompatible with NVIDIA 620.70.06 |
| `~/.local/bin/nvibrant-build-local` | Pinned cached upstream C++ source build against installed NVIDIA DKMS headers, even with NVIDIA unloaded |
| `/etc/pacman.d/hooks/95-nvibrant-rebuild.hook` | Post-transaction NVIDIA driver upgrade trigger; installed root-owned from repo source |
| `~/.local/bin/nvibrant-post-update` | Unprivileged, nonblocking offline ALPM build wrapper |
| `~/.local/libexec/nvibrant/nvibrant-$version` | Local driver-matched native executable |
| `~/.local/bin/nvibrant-current` | Exact-driver runtime dispatcher and real ioctl success validator |
| `~/.local/bin/nvibrant-ctl` | Saved-value controller invoked by the xremap shortcuts |
| `~/.local/bin/apply-vibrance` | Canonical mode-aware one-shot applicator |
| `~/.local/bin/sway-run` | Sway launcher (calls `apply-vibrance`) |
| `~/.local/bin/launch-desktop` | TTY1 session launcher (calls `apply-vibrance`) |
| `~/.config/sway/config.d/10-display.conf` | `exec_always` reload hook for vibrance |
| `~/.config/nvibrant` | Authoritative dGPU vibrance value (e.g. `614`) |
| `~/.config/vibrance` | Authoritative Hybrid Intel CTM multiplier (e.g. `1.40`) |
