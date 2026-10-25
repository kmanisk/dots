# Launcher Runner Bridge

**Process orchestration bridge chaining systemd user scopes, GameMode, Gamescope, and UMU Proton runners.**

- **Project Path:** [`/home/onyx/Projects/launcher-runner-bridge`](file:///home/onyx/Projects/launcher-runner-bridge)
- **Target Pipeline:** `systemd-run --user --scope` -> `gamemoderun` -> `gamescope --mangoapp` -> `umu-run --config`
- **Platform:** CachyOS / Wayland (verified 2026-09-19)

---

## 1. Overview & Verification

The bridge standardizes game launch parameters across external launchers and scripts:
- **Clean Scope Management:** Wraps execution in an isolated transient systemd scope, guaranteeing that `systemctl --user stop <unit>.scope` terminates child processes without leaving orphaned background tasks.
- **Gamescope & MangoApp Integration:** Uses `--mangoapp` to present the overlay cleanly inside Gamescope nested sessions.
- **UMU Database Integration:** Seamlessly defaults to UMU prefix management and GE-Proton configurations.

---

## 2. Architecture & Repository Documentation

- [Upstream Repository README](./source-README.md)
