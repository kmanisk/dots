# System Philosophy, Core Needs & Performance Architecture

**Target Machine:** ASUS TUF Gaming F16 (Intel Core i5-13450HX + NVIDIA GeForce RTX 5050 Mobile)  
**OS/Desktop:** CachyOS rolling (x86-64-v3, BORE scheduler) · Sway (Wayland) / i3 (X11) @ 1920x1200 165Hz  

---

## 1. User Profile, Core Needs & Use Cases

* **Primary Purpose:** Ultra-responsive, low-latency, competitive and AAA gaming rig (CS2, Elden Ring, Sleeping Dogs, Dying Light) paired with rapid lightweight development/terminal workflows.
* **Display Output:** 1920×1200 native 165Hz panel driven at maximum fluidity with instantaneous input registration.
* **Workflow:** Keyboard-centric tiling window manager (Sway on Wayland / i3 on X11), Alacritty terminal, Fish shell, Neovim/Zed, and Fuzzel/Rofi application launching.

---

## 2. Invariable Design Principles

### A. Zero Animations, Zero Eye-Candy Lag
* **No Window Transitions or Fading:** Any synthetic delay between a keypress and window presentation is eliminated. Windows map, tile, move, and vanish instantly.
* **Instantaneous UI State:** Compositor effects, blur shaders, window drop-shadows, and animation loops are disabled to conserve GPU cycles and eliminate presentation jitter.

### B. Pure Daemonless Architecture (Zero Unnecessary Daemons)
* **Ephemeral Over Resident:** Always prefer single-execution, on-demand scripts and CLI utilities (`slurp`, `grim`, `wlsunset`, `nmcli`) rather than persistent background system daemons or Electron tray backgrounders.
* **Zero Idle CPU/RAM Steal:** Background processes must not consume CPU cycles, lock memory pages, or trigger wakeups while the user is in-game.
* **No Heavy Display Managers:** Session launches directly via Getty autologin on TTY1 into Sway/i3, avoiding heavy DM memory footprints.
* **Headless Essential Services Only:** Only strictly necessary system-level components run in the background (e.g., PipeWire/WirePlumber, ananicy-cpp priority scheduler, udiskie automounter).

### C. Fast & Reliable Gaming Infrastructure
* **Direct Hardware Presentation:**
  * Sway directly bypasses compositing for fullscreen games via direct scanout (`presentation-time` protocol).
  * Direct rendering to physical panel refresh (165Hz) without double-buffering or XWayland translation penalty.
* **Dual-GPU Isolation (Optimus D3cold Offloading):**
  * Desktop, terminal, browser, and 2D surfaces stay on the Intel Raptor Lake iGPU (`LIBVA_DRIVER_NAME=iHD`).
  * Dedicated NVIDIA RTX 5050 Mobile remains asleep in runtime D3cold power state until explicitly invoked with `gamemoderun prime-run %command%`.
* **P-Core CPU Pinning:**
  * Latency-critical titles (e.g., CS2) isolate execution to Intel Raptor Lake Performance cores (threads 0–11 via `taskset -c 0-11`), completely bypassing Efficiency cores to eliminate thread scheduling jitter.
* **Btrfs nodatacow (`chattr +C`):**
  * Game installations and Wine prefixes (`/mnt/Games/SteamLibrary/steamapps/common`, `~/.local/share/Steam/steamapps/compatdata`) strictly use `chattr +C` to eliminate Copy-on-Write write amplification and frame drops.

---

## 3. Maintenance & Reproducibility Standard
* **Snapper Snapshot Baselines:** Maintain lean snapshot retention. Prune transient snapshots so exclusive Btrfs blocks do not bloat disk space.
* **Portable Chezmoi Source:** Retain zero hardcoded home paths (`$HOME` / `~`), zero personal credentials/tokens, and complete independence from machine-specific usernames.
