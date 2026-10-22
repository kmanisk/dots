# Gaming on CachyOS (i3wm X11) — Experience & Documentation Hub

Welcome to the gaming knowledge base for the **ASUS TUF Gaming F16** (Intel Core i5-13450HX + NVIDIA GeForce RTX 5050 Mobile Blackwell) running **CachyOS (BORE/EEVDF)** under **i3wm (X11)**.

This directory contains battle-tested configurations, root-cause analyses, benchmark telemetry, and status reports for each configured game.

---

## 🎮 Game Directory Index

### 1. [Counter-Strike 2 (CS2)](./cs2/README.md)
- **Status:** **Working Flawlessly** (Native Linux Vulkan)
- **Performance:** **407.6 Avg FPS** / **170.3 1% Low FPS** (locked above 165Hz physical panel refresh)
- **Aspect Ratio & Display:** 1440x1080 4:3 stretched via Intel panel hardware controller
- **Documentation:**
  - [Status & Experience Log](./cs2/README.md)
  - [VProf Benchmark Telemetry Breakdown](./cs2/performance-benchmarks.md)

---

### 2. [Elden Ring](./elden-ring/README.md)
- **Status:** **Working** (Proton Experimental / DX12 VKD3D)
- **Performance:** Stable 60 FPS capped with dynamic power profile switching (`asusctl Performance`)
- **Key Fixes:** Blackwell VKD3D memory flags (`no_upload_hvv,force_host_cached`), mouse polling rate clamped to 500Hz, save prefix preservation
- **Documentation:**
  - [Status & Experience Log](./elden-ring/README.md)
  - [Wayland & X11 Issue-by-Issue Fix Log](./elden-ring/wayland-troubleshooting-and-fixes.md)

---

### 3. [Grand Theft Auto IV: Complete Edition](./gta-iv/README.md)
- **Status:** **Working** (Proton DXVK + Gillian's 4.9GB Modpack)
- **Performance:** Locked at 100 FPS (with loading screens clamped to 30 FPS to prevent engine deadlocks)
- **Key Fixes:** In-game Graphics API Vulkan crash resolved, 32-bit VRAM integer overflow avoided, ASI modloader enabled via `WINEDLLOVERRIDES="dinput8=n,b"`
- **Documentation:**
  - [Status & Experience Log](./gta-iv/README.md)
  - [Full Modpack & Proton Installation Guide](./gta-iv/modpack-and-proton-guide.md)

---

## 🛠️ Global Gaming Invariants & Architecture

1. **Hybrid GPU Strategy:**
   - 2D desktop session runs on Intel UHD Graphics (`LIBVA_DRIVER_NAME=iHD`).
   - Games offload explicitly to dedicated NVIDIA RTX 5050 Mobile via `gamemoderun prime-run %command%` or custom wrappers.
2. **Window Management:**
   - i3wm window rule: `for_window [class="^steam_app_.*$"] fullscreen enable`.
3. **Storage & Btrfs Safety:**
   - Steam libraries reside on `/mnt/Games/SteamLibrary` with snapshot protection.
4. **Steam Launch Options & Runtime Portability:**
   - [Steam Portable Launch Options & Architecture](./steam.md) — Standard `sh -c 'exec "$HOME/.local/bin/<script>" "$@"' -- %command%` pattern to resolve `$HOME` dynamically, avoiding Steam container `$PATH` stripping and eliminating hardcoded paths.
