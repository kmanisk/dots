# Gaming on CachyOS — Experience & Documentation Hub

Welcome to the gaming knowledge base for the **ASUS TUF Gaming F16** (Intel Core i5-13450HX + NVIDIA GeForce RTX 5050 Mobile Blackwell `sm_120`) running **CachyOS (BORE/EEVDF)** under **Sway (Wayland)** and **i3wm (X11)**.

This directory contains battle-tested configurations, root-cause analyses, benchmark telemetry, and status reports for each configured game.

---

## 🎮 Game Directory Index

### 1. [Counter-Strike 2 (CS2)](./cs2/README.md)
- **Status:** **Working Flawlessly** (Native Linux Vulkan)
- **Performance:** **407.6 Avg FPS** / **170.3 1% Low FPS** (locked above 165Hz physical panel refresh)
- **Resolution & Scaling:** 1600x1200 4:3 stretched edge-to-edge (zero black bars) via native Wayland SDL viewport stretch; self-healing exclusive fullscreen enforcement in `cs2_video.txt`.
- **Audio Routing:** Automatically routed to `sink.peace_gaming` (Peace PUBG EQ + LoudMax limiter) via `gaming-audio-route.lua`
- **Documentation:**
  - [Status & Experience Log](./cs2/README.md)
  - [Native Wayland 4:3 Stretched Fix Log](./cs2/wayland-43-stretched.md)
  - [VProf Benchmark Telemetry Breakdown](./cs2/performance-benchmarks.md)

---

### 2. [Elden Ring](./elden-ring/README.md)
- **Status:** **Working** (Proton CachyOS-SLR / DX12 VKD3D + LSFG-VK 3x)
- **Performance:** Smooth 120+ FPS via LSFG-VK 3x (`LSFGVK_PROFILE="Elden Ring"`) and `gamescope --mangoapp -W 1920 -H 1200 -w 1920 -h 1200 -f -r 165`
- **Mods & Runtimes:** Mod Engine 2, EldenModLoader (`dinput8.dll`), CameraFix (`CameraFix.dll`), Item and Enemy Randomizer GUI (.NET 8.0 Desktop Runtime in prefix `2703476723`)
- **Key Fixes:** Blackwell VKD3D memory flags (`no_upload_hvv,force_host_cached`), `PROTON_ENABLE_NVAPI=0`, save prefix preservation
- **Documentation:**
  - [Status & Experience Log](./elden-ring/README.md)
  - [Wayland & X11 Issue-by-Issue Fix Log](./elden-ring/wayland-troubleshooting-and-fixes.md)

---

### 3. [Dark Souls III](./dark-souls-3/README.md)
- **Status:** **Working Flawlessly** (Proton DXVK + ReShade Eden CYCLES + Mod Engine 3 + Randomizer + Camera Fix)
- **Performance:** 1920x1200 165Hz via Gamescope (`--mangoapp`) + LSFG-VK (2x Frame Generation) + RTX 5050 Mobile
- **Key Fixes:**
  - Multi-DLL proxy chainloading via `WINEDLLOVERRIDES="d3d11=n,b;dinput8=n,b;d3dcompiler_43=n,b;d3dcompiler_47=n;dxgi=n,b"`
  - Mod Engine 3 integration (`me3 launch -g darksouls3 -p darksouls3-default`)
  - Case-sensitivity directory aliasing for ReShade `shaders/brussell`
  - Automated randomizer seed sync on exit
  - `ADOF [qUINT_dof.fx]` toggle for depth of field control
- **Documentation:**
  - [Master Architecture & Modding Guide](./dark-souls-3/README.md)

---

### 4. [Grand Theft Auto IV: Complete Edition](./gta-iv/README.md)
- **Status:** **Working** (Proton DXVK + Gillian's 4.9GB Modpack)
- **Performance:** Locked at 100 FPS (with loading screens clamped to 30 FPS to prevent engine deadlocks)
- **Key Fixes:** In-game Graphics API Vulkan crash resolved, 32-bit VRAM integer overflow avoided, ASI modloader enabled via `WINEDLLOVERRIDES="dinput8=n,b"`
- **Documentation:**
  - [Status & Experience Log](./gta-iv/README.md)
  - [Full Modpack & Proton Installation Guide](./gta-iv/modpack-and-proton-guide.md)

---

## 🛠️ Global Gaming Invariants & Architecture

1. **Dynamic GPU Architecture (`supergfxctl`):**
   - **`AsusMuxDgpu` (Active Baseline)**: RTX 5050 Mobile connects directly to the 165Hz eDP-1 internal panel through the hardware MUX switch. Wayland compositor and video decode run on NVIDIA (`LIBVA_DRIVER_NAME=nvidia`). Hardware digital vibrance via `nvibrant`.
   - **`Hybrid`**: Desktop runs on Intel UHD Graphics (`LIBVA_DRIVER_NAME=iHD`). 3D games offload explicitly via `prime-run` (`__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia`).
2. **Workspace 4 Isolation & Window Management:**
   - All games automatically route to **Workspace 4** (`assign [class="^steam_app_.*$"] workspace number $ws4`, `assign [class="(?i)^(cs2|gamescope|eldenring|darksouls.*)$"] workspace number $ws4`).
   - Modding utilities float on current workspace (`for_window [title="(?i).*(randomizer|cycles|reshade).*"] floating enable, move position center, focus`).
   - Notification OSDs (volume, brightness) are completely suppressed on Workspace 4 to prevent FPS drops.
   - Clean session teardown via `killgame` (`Caps + R` / hotkey), terminating all game processes without opening accidental menus.
3. **Low-Latency Display & Tearing:**
   - Sway configured with `allow_tearing yes` to minimize frame presentation latency.
   - Fractional scale bypass via nested Gamescope sessions (`gamescope -W 1920 -H 1200 -w 1920 -h 1200 -f -r 165`).
4. **Competitive Audio Routing:**
   - WirePlumber hook `gaming-audio-route.lua` automatically routes competitive games to `sink.peace_gaming` (Peace PUBG EQ + LoudMax limiter), bypassing Dolby processing for unaltered 3D audio cues.
5. **MangoHud Protection (RULE 9):**
   - Global config at `~/.config/MangoHud/MangoHud.conf` is managed by chezmoi (minimal horizontal SteamOS-style HUD based on the Elden Ring per-game config; `pci_dev=0000:01:00.0`; starts hidden — `Alt+3` toggles while the app window is focused; logging disabled).
   - In-game keys (60% keyboard — no physical F-row): `Alt+3` HUD on/off | `Alt+4` font-size presets (hidden 15 / 20 / 30) | `Alt+5` HUD position | `Alt+6` reset FPS metrics | `Alt+7` frame-cap toggle (no cap defined — no-op) | `Alt+8` reload config. MangoHud debounces hotkeys ~0.4 s — press once, pause, press again; rapid taps count once.
   - `Alt+5` advances one of MangoHud's 8 position anchors per press. This HUD is a single full-width row, so the left/center/right anchors of a row render in the same spot — the visible change is the row: top → middle → bottom (then wraps back to top).
   - `Alt+m` runs the `hudtest` preview (spinning Vulkan cube on the RTX 5050 via `prime-run`); it always forces the HUD visible (`no_display=0`), so the overlay can be inspected without launching a game.
   - Elden Ring's variant (with LSFG status text) lives in the game directory and loads via `MANGOHUD_CONFIGFILE`; retired per-game overrides are archived under `~/.config/MangoHud/archive/`.
6. **Proton Prefix Dependency Management:**
   - [Proton Prefix Dependency Guide (.NET, VC++, & Runtimes)](./proton-prefix-dependency-management.md) — Reference for `protontricks`, `winetricks`, and prefix container setups.
7. **Steam Launch Options & Runtime Portability:**
   - [Steam Portable Launch Options & Architecture](./steam.md) — Standard `sh -c 'exec "$HOME/.local/bin/<script>" "$@"' -- %command%` pattern to resolve `$HOME` dynamically, avoiding Steam container `$PATH` stripping and eliminating hardcoded paths.
