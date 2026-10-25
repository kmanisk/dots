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
- Binary: `/usr/bin/nvibrant` (thin Python wrapper picking a version-matched
  native blob for the running driver; 615.71.09 blob present in-package).

## 2. Display mapping (detected, not guessed)

NVKMS enumerates one display with 6 connectors; only connector **2 (DP)**
reports `Success` — the internal panel (no externals attached; Sway shows
only eDP-1). CLI takes **positional per-connector values**, so the panel is
argv index 3:

```bash
nvibrant 0 0 <value>   # connectors 0,1 = 0 (disconnected, harmless)
```

## 3. CLI semantics (verified against upstream `main.cpp`)

- Range per connector: **-1024..1023**, neutral **0**. No linear relation to
  the old 1.30 CTM multiplier (different color math) — values are chosen by
  eye, not converted.
- ⚠️ **No read path exists.** Bare `nvibrant` is *not* a query: it writes
  fallback 0 to every connected output. Every invocation must pass all
  leading values, or it silently resets the panel to neutral.
- Tested value: **800** — screenshot-histogram check on identical desktop
  content showed mean saturation 0.047 → 0.126 (~2.7x). Revert: `nvibrant 0 0 0`.

## 4. Persistence & Canonical Execution (`apply-vibrance`)

Display vibrance across boot and reload is unified into the canonical one-shot helper `~/.local/bin/apply-vibrance`:

- **One-shot & Idempotent:** Runs at Sway startup via `~/.local/bin/sway-run` (and `~/.local/bin/launch-desktop`).
- **Sway Reload Hook:** Automatically re-applies upon `swaymsg reload` via `exec_always --no-startup-id ~/.local/bin/apply-vibrance` in `~/.config/sway/config.d/10-display.conf`.
- **Mode-Gated:**
  - `AsusMuxDgpu`: Reads `~/.config/nvibrant` (authoritative) and executes `nvibrant 0 0 "$NVIB_VAL"`.
  - `Hybrid`: Reads `~/.config/vibrance` and applies Intel CTM via `ctm-test --set "$VIB_VAL"`.
- **Zero Daemons:** Strictly one-shot; exits immediately without background processes, loops, or polling watchers.

## 5. CS2 note

Vibrance is applied in the dGPU display pipeline at scanout and cannot alter
render frametimes — same mechanism argument as the old CTM case. The uncapped
dGPU result stands independent of this setting.

## 6. Files

| Path | Role |
|------|------|
| `/usr/bin/nvibrant` | Tool (AUR package) |
| `~/.local/bin/apply-vibrance` | Canonical mode-aware one-shot applicator |
| `~/.local/bin/sway-run` | Sway launcher (calls `apply-vibrance`) |
| `~/.local/bin/launch-desktop` | TTY1 session launcher (calls `apply-vibrance`) |
| `~/.config/sway/config.d/10-display.conf` | `exec_always` reload hook for vibrance |
| `~/.config/nvibrant` | Authoritative dGPU vibrance value (e.g. `614`) |
| `~/.config/vibrance` | Authoritative Hybrid Intel CTM multiplier (e.g. `1.40`) |
