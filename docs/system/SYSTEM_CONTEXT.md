# Canonical System Context

This is the primary machine-context document for AI agents working on this repository.

It is not a replacement for the detailed subsystem documentation. Its job is to provide one current entry point, resolve conflicts between older documents, record important invariants, and tell an agent what must be verified before making changes.

Last synchronized with repository state: 2026-10-31.
Material change history is tracked in `docs/system/SYSTEM_CHANGELOG.md` and Git; this file intentionally does not pin itself to a commit hash.
Latest broad live-system audit used as an evidence baseline: `docs/system/workstation-audit-2026-10-23.md`.

## 1. Authority and freshness

Use the following precedence when facts disagree:

1. Explicit instruction from the user in the current task.
2. Fresh live-machine command output.
3. Current source/configuration in this repository.
4. This file.
5. Relevant subsystem documentation.
6. Dated audit/report documents.
7. Archived documentation, old conversations, cached agent memory, or assumptions.

Version numbers and runtime state in this file are snapshots, not promises. Re-check them when the exact value matters.

Never copy a changing fact into multiple agent instruction files. Update it here and keep agent entry files as pointers.

## 2. Machine identity

Primary machine:

- Laptop: ASUS TUF Gaming F16 FX608JH family.
- CPU: Intel Core i5-13450HX, 16 logical threads.
- Integrated GPU: Intel UHD Graphics.
- Discrete GPU: NVIDIA GeForce RTX 5050 Laptop GPU, 8 GB VRAM.
- RAM: 16 GB installed at the current baseline.
- Internal display: 1920x1200, 165 Hz class panel.
- OS family: CachyOS / Arch Linux, x86-64-v3.
- Primary desktop: Sway on Wayland.
- Shell: fish.
- Dotfile/configuration manager: chezmoi.
- Repository: `kmanisk/dots`, default branch `master`.

The repository source under `~/.local/share/chezmoi` is the configuration source of truth where a file is chezmoi-managed.

## 3. Current verified desktop/GPU baseline

The 2026-10-23 workstation audit verified:

- Kernel: `7.3.0-2-cachyos` at audit time.
- Sway: `1.12`.
- GPU mode: `AsusMuxDgpu`.
- NVIDIA driver: `615.78.08` at audit time.
- Active internal output: `eDP-2` in that boot.
- Output mode: 1920x1200 at approximately 165.004 Hz.
- Output scale: 1 at audit time.
- Adaptive sync: disabled at audit time.
- Tearing: allowed.
- NVIDIA was the direct display GPU in the audited dGPU-only session.

Do not treat DRM card numbers, connector enumeration, or an old `eDP-1`/`eDP-2` name as permanent. Query the running compositor before scripts depend on a connector name.

### UI scaling

Sway output scaling is the central application/UI scale source. Fresh live verification on 2026-11-01 found `eDP-1` at 1920x1200, approximately 165.004 Hz, runtime scale `1.30`, with GPU mode `AsusMuxDgpu`.

Relevant files include:

- `dot_config/sway/config.d/45-ui-scale.conf`
- generated runtime `~/.config/sway/config.d/99-ui-scale.conf` (not pinned as a tracked fixed scale)
- generated runtime `~/.config/sway/config.d/99-ui-chrome.conf`
- `dot_config/ui-metrics.conf`
- `dot_local/bin/executable_ui-scale`
- `dot_local/bin/executable_ui-sync`
- `dot_local/bin/executable_sway-check`
- `dot_local/bin/executable_sway-safe-reload`

`ui-scale` writes scale state atomically and skips replacing unchanged content. `ui-sync` skips unchanged generated-file writes/reloads. Sway maintenance should use read-only `sway-check` and validated `sway-safe-reload`; `Win + Shift + R` is bound to the latter. The `Alt + Space` Fuzzel launcher keeps the compact 36-character width and 10-row proportions, uses a scale-derived 26px physical row/icon target, and enables Fuzzel's native large selected-app preview at `image-size-ratio=0.58` when filtering to only a few matches; generated web favorites carry explicit icon assets so entries such as `GitHub Profile: kmanisk` can show the GitHub logo in that preview. The synchronized Phinger cursor size is 24px; use `adjust-cursor-size` rather than editing one consumer directly. Mako/OSD chrome is intentionally compact at the current baseline (`MAKO_FONT=15`, padding/margin 8, width 440, radius 6 in `ui-metrics.conf`), and the Ctrl+Space scratch terminal uses a dedicated 16 pt Foot font override.

Remote Sway validation and connector-neutral presentation rules were verified on 2026-11-06. `sway-check` and `sway-safe-reload` validate with `WLR_BACKENDS=headless WLR_RENDERER=pixman`, avoiding the live logind/DRM seat; when `SWAYSOCK` is absent they use only a uniquely discovered same-UID IPC socket. `30-window-rules.conf` no longer moves Meetingly or `wl-mirror` to hardcoded `eDP-1`; they retain their launch output, with Meetingly floating and the mirror tiled/borderless. On the live `eDP-1` session, `sway-check` returned 0 failures/0 warnings, and the safe reload completed with the existing workspace layout and X-Lite QEMU service still active. Multi-output behavior is not yet independently tested.

Do not reintroduce stacked Chromium/device-scale overrides unless there is a measured reason. Inspect the current generated scale state before changing font or chrome sizes. ArtCraft suite applications (GridCraft, WordCraft, FilmCraft, PhotoCraft) use native Wayland flags (`GRIDCRAFT_WAYLAND=1`, etc.) via `~/.config/environment.d/40-craft-apps.conf` and `~/.local/bin/sway-run` to prevent blurry Xwayland upscaling and compounding fractional-scale multiplication; `craft-scale` (`~/.local/bin/craft-scale`) manages application-level UI scale (100% / auto baseline). See `docs/system/artcraft-suite.md`.

Workspace/browser tiling is intentionally protected from mouse-drag conversion: `00-variables.conf` sets `tiling_drag disable`, while `floating_modifier $mod normal` remains available for already-floating windows. This prevents a mapped/tiled `brave-origin` window on workspace 2 from later becoming a `user_on` floating container through titlebar or Super+mouse dragging; `Alt+Shift+Space` also routes browsers through `toggle-floating-strict` and retile-only behavior.

### Theme engine

The current theme runtime is `theme-sync` + `theme-set`, documented under `docs/theme/`. Theme changes are on-demand and use no resident watcher/daemon. Mutations are serialized by `~/.local/state/theme/.lock` (`fcntl.flock`) across staged compilation, transactional promotion, and value-carrying live IPC; do not bypass that lock with parallel direct writes to `~/.local/state/theme/.next/`. `theme-sync` prebuilds `~/.cache/theme/picker-index.json`, and `rofi-theme` opens cache-first from that compact index instead of reparsing all 327 JSON themes or scanning source trees for staleness. Existing compiled rows are therefore shown immediately; explicit import/delete paths synchronize their cache, while Ctrl+R is the deliberate manual refresh. Picker display labels suppress the leading `omarchy-` prefix only in rendered text (e.g., `everforest`), while the internal theme IDs and Rofi `info` fields remain canonical for activation, deletion and preview. Enter dismisses Rofi immediately and queues the validated `theme-set` transaction in a detached one-shot worker. Failures are surfaced through Mako/`notify-send` and `~/.local/state/theme/last-picker-apply.log`; a latest-request token drops stale detached workers before they can start, while already-running transactions remain serialized by the mutation lock.

**Sway tab color guard (2026-11-07):** The `theme-set` Sway adapter no longer paints full tab titlebars with raw `BASE01`/`bg2` (which is vivid purple for Rebecca) or uses alias `white`/`BASE07` as selected-tab text (neon pink for Moonlight). All 339 themes now derive separate low-noise `tab_active_bg` / `tab_inactive_bg` surfaces from `BASE00` plus modest neutral contrast; selected titles use `BASE05`, inactive titles use dimmed `BASE05` instead of potentially neon `grey_fg` aliases, and selected/inactive/urgent titles meet `4.5:1` contrast on their actual tab background. Authored accents remain on the narrow focus border; normal app palettes are unchanged. Live Sway IPC, generated `sway.conf`, `swaybar.conf` and `80-theme-colors.conf` agree. Validated full `theme-set --check-all` (339 pass), independent full-fleet contrast audit (339 pass), actual Swaybar IPC values after a socket-aware, theme-lock-protected live update (the first same-theme run had no `SWAYSOCK`), `sway-check` (zero errors/warnings), and preserved active `windows-dark-mode`. Details: `docs/theme/theme-implementation.md`.

The 2026-11-01 source fleet contained 351 source files (232 Omarchy community imports, 97 Base46 sources, 22 custom/built-in definitions); at that historical baseline the picker exposed 327 unique themes after duplicate suppression. **Updated 2026-11-07:** 12 new curated custom palette sources were added, compiling 363 source themes and exposing 339 unique picker themes (21 suppressed duplicates) on the live machine. All 12 new palettes are pinned Base16 imports from Tinted Theming with `assets.background_mode="solid"`, a per-theme hard opt-out from wallpaper donor matching and downloads; they use the selected scheme's Sway solid background. Existing themes retain wallpaper policy, and the active theme was preserved. See `docs/theme/curated-solid-palettes.md`. It uses deterministic JSON ordering, write-if-changed semantics, stale generated-artifact pruning, palette-faithful normalization, portable preview metadata, preview invalidation based on real content changes, and a compact picker index. Runtime `theme-set` validates all normalized colors/templates before mutation (`--check` / `--check-all`), prevents authored `base_30` aliases from undoing contrast floors, uses cheap private `.next/` writes followed by change-aware transactional promotion/rollback, preserves `ui-sync`-owned chrome geometry, skips `/proc`/GTK/hook work on no-op reapplies, and suppresses hot reloads for byte-identical targets. With no live Neovim socket it deliberately leaves Base46's marker stale instead of starting headless Neovim; `init.lua` recompiles on the next editor startup. Reload-current-config commands for Mako/Dunst/Yazi are detached because they carry no old theme values, while explicit Sway/GTK/wallpaper value updates remain ordered. Gruvbox folder-icon recoloring runs as a guarded one-shot worker with its own lock/stale-theme checks instead of blocking the theme switch on thousands of SVG files. Duplicate decisions are recorded in `~/.cache/theme/dedup.json`; source definitions remain intact for provenance/rebuilds, and hand-written Neovim themes are never pruned unless they carry the `theme-sync` generated header.

Omarchy app-specific colors are author-first without surrendering workstation ownership. Fresh imports preserve safe structured profiles from repository `alacritty.toml`, `kitty.conf`, `ghostty.conf`, `btop.theme`, `cava_theme`/`cava.conf`, `mako.ini`/`mako.conf`, `chromium.theme`, and `icons.theme` under Schema 1 `apps.*` (`assets.upstream_apps_version=3`). `theme-set` uses exact authored profiles for Alacritty, Kitty, btop, Cava, and Mako, with normalized generated tokens as per-value fallback; btop's local `main_bg=""` invariant remains authoritative. Foot is the primary terminal adapter: authored Omarchy terminal colors are translated `alacritty.toml` -> `kitty.conf` -> generated fallback per value into Foot background/foreground, cursor, selection, URL color and ANSI 0-15, and both the generated include and live OSC updates use that same translated palette. Foot fonts, sizing, keybindings and behavior stay locally owned. On 2026-11-07 the Foot hot-reload broadcaster was corrected for real client/server mode: it scans direct children of `foot --server` for their owned `/dev/pts/<n>` devices, not children of `footclient` IPC stubs, and emits one OSC 10/11/12/17/19 + 16-color payload per live window **before** Neovim RPC. A read-only scan found two Foot PTYs and a targeted no-theme-change broadcast updated 2/2; no Foot restart or terminal reset. App-painted truecolor TUI cells (e.g. Codex/OpenCode) still depend on app redraw and are not force-cleared. Details in `docs/system/foot.md`. Browser/icon/Ghostty metadata is recorded but not forced when no safe/installed adapter exists, and upstream Neovim Lua or arbitrary behavior is never executed. Older imports lazily hydrate these small text profiles into `~/.local/share/theme/upstream-apps/<theme>.json` through the detached `theme-upstream-apps` helper, so repository I/O remains outside the theme-switch critical path and stale completions cannot retheme a newer selection.

`omarchy-import --catalog` prefers Omarchy's published validated registry catalog and checks out registry-pinned commits when available; if that CDN is unavailable it falls back to the current `omarchy.org/themes` gallery, then legacy endpoints only as a last resort. During live verification on 2026-11-01 the registry hostname did not resolve from this machine, so the gallery fallback was used: 233 entries were listed, 232 repositories were reachable and mirrored into chezmoi, and `ankur311sudo/gruvu` returned repository-not-found. Repository wallpaper discovery has no numeric image cap: conventional `backgrounds/`, `wallpapers/`, and `bg/` paths are authoritative and every image in those sets is kept; non-UI images elsewhere are considered only when no conventional wallpaper path exists. Repository discovery version 3 also scopes shared-monorepo themes to the canonical wallpaper root already declared by that theme (for example `themes/everforest/backgrounds/` inside `omacom/omarchy`), so sibling built-in themes can never enter its cycle set. Import/update preserves the selected files under `~/.local/share/theme/wallpapers/upstream/<theme>/` before deleting the temporary clone.

Wallpaper runtime precedence is repository- and semantic-scoped. GitHub-backed Omarchy community themes and official built-ins are **repository-authoritative** and use only their own files under `~/.local/share/theme/wallpapers/upstream/<theme>/`. Non-Omarchy palettes never consume the generic Wallhaven mapping at runtime: `theme_engine.wallpaper_policy` resolves exact normalized identity plus explicit `~/.config/theme/wallpaper-aliases.json` mappings first, then uses `~/.config/theme/wallpaper-preferences.json` for an artistic-first semantic Omarchy donor. Semantic styles cover artistic oil/illustration, light artistic, natural art, terminal technical, blueprint technical, and synth technical; donor choice preserves light/dark polarity and scores palette colors. Base46 `gruvchad` / `gruvbox_light` still borrow official `omarchy-gruvbox`, while formerly unmatched themes now receive style/color-compatible Omarchy artwork. The palette itself never changes. Solid `Sway` background is the final no-donor fallback and also the immediate temporary background while a missing resolved repository hydrates. First-use network I/O never blocks `theme-set`: it launches one detached `theme-wallpaper hydrate <theme>` job, which downloads outside the global theme lock, then takes that lock only for the final compositor mutation and re-checks that the requested theme is still active. The same worker lazily repairs pre-uncapped caches: manifests without repository discovery version 3 are re-scanned through a blobless Git tree, existing matching files are reused, and only newly discovered backgrounds are downloaded. Slow stale fetches therefore cannot overwrite a newer theme. Hydration is deduplicated per selected palette, and afterward switching is local. **Wallpaper-cycle hotkeys (2026-11-07):** `theme-wallpaper next`/`prev`/`random` now silently no-op for explicitly solid themes, a single cached wallpaper, or a cold cache with zero/one effective declared candidate. They do not run a repository search, download, `wset` or notification for those keypresses. An explicit `fetch`/`refresh` remains available for previously uncached images; normal multiple-image cycling and theme-apply hydration are unchanged. Direct live no-op tests for one-image `dhv-magellan` and solid-only `snazzy` preserved the active theme/wallpaper pointer. See `docs/theme/wallpaper-library.md`. The historical 63-asset shared Wallhaven library remains maintenance/audit data only. See `docs/theme/wallpaper-library.md`.

Neovim/NvChad reloads are verified rather than fire-and-forget: Base46 errors are surfaced, selected theme modules are invalidated before recompilation, a successful live RPC supplies the shared disk cache, and `~/.local/share/nvim/base46/current_theme` advances only after compilation succeeds; if no live socket works, normal headless NvChad startup repairs the cache. Theme normalization preserves authored hues and only changes lightness to satisfy readability/border thresholds; background luminance overrides clearly incorrect upstream dark/light labels. NvChad presentation is polarity-aware: dark themes remain transparent, while light themes are opaque so the generated light Base46 background cannot reveal a stale dark terminal surface; live `theme-set` RPC updates transparency and theme atomically, and `lua/options.lua` does not override Base46's theme-owned `background` value. `Alt + Shift + M` and `Ctrl + Shift + M` launch the same `rofi-theme` picker; the former `ds3-wallpaper` helper is removed, and the W wallpaper chords delegate to the identity-aware `theme-wallpaper` helper.

### Playback-aware Sway dimming and idle lock

As of 2026-11-05, `keep-awake` starts playback-aware `swayidle` callbacks through the managed `media-idle-action` helper. The pre-existing 120s brightness dim, 300s active-mode DPMS-off, and inactive-mode 300s lock/600s DPMS-off timeouts remain, but defer while MPRIS reports `Playing` or a PipeWire application-owned output stream is running. This protects Brave/video/audio playback without treating always-running Dolby DSP nodes as media. Deferred actions have only on-demand 10s watchers; Sway resume/input, keep-awake mode switch, and explicit `screen-black` cancel them. The manual `screen-black` shortcut remains authoritative even while audio plays. Live testing with Brave MPRIS `Playing` and an active PipeWire stream confirmed the dim callback left brightness unchanged, DPMS stayed on, and cancel/deferred callbacks behaved as intended. Implementation: `dot_local/bin/executable_media-idle-action`, `executable_keep-awake`, `executable_screen-black`; rationale in `docs/system/swayidle-locking-wakeup.md`.

### Elden Ring non-Steam launcher

The managed Elden Ring stack under `/mnt/Games/NonSteamGames/ELDEN RING/` is a non-Steam installation. `eldenring-lsfg` launches ModEngine 2 through the dedicated Proton prefix directly and must not start or wait for the native Steam desktop client. `SteamAppId`/`SteamGameId` and `STEAM_COMPAT_*` variables are Proton/ModEngine compatibility metadata only. The live profile at `~/.config/eldenring/config_randomizer_stack.toml` is synchronized with `dot_config/eldenring/config_randomizer_stack.toml`: ModEngine injects RandomizerCrashFix, DelayedModLoader and MapForGoblins; DelayedModLoader starts CameraFix and PauseTheGame after 7 seconds. **FasterRevival v1.0.0 must remain parked**: injecting it caused the previously reproduced black startup regression. The EldenModLoader `[loadorder]` stays empty to prevent duplicate injection; MangoHud remains diagnostic-only because its Vulkan present hook froze the current stack. On 2026-11-05 a stale live config was found still injecting FasterRevival despite the fixed source. After synchronizing the two managed Elden Ring files to their live counterparts, a normal launch rendered visible, changing game frames on workspace 4 with LSFG-VK 2.0.0 at **4x**, `flow_scale=0.8`, Performance Mode enabled, vsync pacing and `preserve_swapchain_image_count=false`; the process remained alive beyond 128 seconds. Those November 3/5 4x renders remain historical evidence, but on 2026-11-06 a new focused fullscreen launch stayed essentially 100% black for over two minutes despite the correct three-DLL ModEngine profile, with FasterRevival and MangoHud absent. After terminating only that hung game, a same-session `ENABLE_LSFG=0` relaunch rendered substantially changing workspace-4 frames, with the randomizer and QoL DLLs unchanged. LSFG-VK 2.0 4x presentation is therefore **intermittently broken in the current environment** and now explicit opt-in (`ENABLE_LSFG=1 eldenring-lsfg`); the default `eldenring-lsfg`, Alt+G stable choice, and Alt+Space desktop entry run with LSFG disabled, preserving the verified playable path. The Alt+G menu also exposes an experimental 4x choice. The shared LSFG-VK profile remains unchanged for separate future debugging. Source/live drift was repaired directly because unrelated duplicate `nvim.desktop` chezmoi source/template entries currently block targeted `chezmoi apply`; fix that conflict separately, without broad configuration changes during a game repair.

### Steam client UI rendering

The managed `~/.local/bin/steam` wrapper keeps Steam desktop UI scaling at 1.0 and refreshes XWayland cursor fallbacks, but no longer forces CEF/`steamwebhelper` into software rendering. On the current NVIDIA + Sway stack, Steam's own `GPUAccelWebViewsV3=1` hardware-webview path is the verified default: NVIDIA ANGLE, GPU compositing/rasterization, video decode, and WebGL were all active, removing the sustained high-CPU software-rendering condition observed during `Loading user data...`. `STEAM_CEF_SOFTWARE=1` exists only as an explicit regression/debug fallback. See `docs/gaming/steam-client.md`.

### Managed utility scratchpad queue and Ventoy GUI

`Win+-` uses `~/.local/bin/scratch-utility-toggle` with Sway-owned window marks and `~/.local/state/scratch/utility-queue.json`. It can park multiple progress/utility windows, restore the last viewed, cycle using `Win+Ctrl+-`, or select by Fuzzel using `Win+Ctrl+Shift+-`; `Win+Shift+-` explicitly parks an eligible window. Foreign scratchpad windows, Ctrl+Space/Win+N scratchpads, terminal/editor windows, and browsers are immune. Brave still belongs in tiled Workspace 2; `Win+Alt+-` still controls UI scale. End-to-end testing with two live Zenity dialogs verified park/restore/cycle/hide and that `scratch-term` was unchanged.

Ventoy (`ventoy-bin` 1.1.18) is launched from the user desktop override to `~/.local/bin/ventoygui`. The helper temporarily grants Xwayland access only to `SI:localuser:root` for Ventoy's pkexec-elevated GTK3 process and revokes the grant on exit; polkit remains required. This resolves the Xwayland ACL mismatch without relaxing access globally. Live verification reached the Ventoy GTK3 UI and disk enumeration; no USB disk was attached and no disk was altered. See `docs/system/file-management.md`.

### Yazi square-corner presentation

On 2026-11-07, Yazi 26.9.1 was switched from rounded to square and the live `[mgr].ratio` was initially rebalanced from `[1,3,4]` to `[2,4,3]`, then tuned to `[3,7,8]` (parent 16.7%, active 38.9%, preview 44.4%) to restore preview width while improving parent filenames: `dot_config/yazi/init.lua` configures `full-border` as `ui.Border.PLAIN`; the Yazi theme engine template uses `[indicator].padding = { open = "▐", close = "▌" }` for square file-selection caps, empty `[tabs].sep_inner`/`sep_outer` and `[status].sep_left`/`sep_right` for square tab/status segments. The current generated live palette under `~/.local/state/theme/yazi.toml` was updated to match the template without changing its colors; theme switches persist the geometry **provided the live generator is synchronized**. On 2026-11-07, the live `~/.config/theme/templates/yazi.toml` was found stale and still outputting rounded glyphs; it was synchronized from the chezmoi source and `all-hallows-eve` was re-rendered without changing the selected theme. The resulting generated file now has square indicator/tab/status fields and no rounded glyphs. The active Yazi process had already exited and therefore could not receive a DDS hot reload; a new Yazi instance picks up the Lua and theme changes on launch. See `docs/system/file-management.md` and `docs/theme/theme-implementation.md`.

### Sway session persistence

Sway session save/restore is one-shot and daemonless. `sway-session-save` writes the current session atomically, keeps `session.json.prev` as the immediate validated rollback, and retains the last 8 valid snapshots under `~/.config/sway/session/backups/`. Startup restore is performed once by `sway-session-restore`; `sway-session-save.service` remains enabled for shutdown-time capture. Foot client/server mode must never use the shared Foot server PID cwd as per-window state: the saver derives terminal cwd from the Fish/Pure window title and restore launches Foot with explicit `-D <cwd>`. Legacy bare ws1 terminal snapshots containing the old erroneous `/` cwd are migrated to `$HOME`. Night-light save/restore now samples the applied `wl-gammarelay` D-Bus `Temperature` (below 6500 K = on; 6500 K = off), with the persisted `nightlight_state` preference as a fallback, rather than detecting obsolete `wlsunset` processes. `Super+E` keeps the Thunar scratchpad; `Super+Shift+E` starts tiled Yazi in Foot on demand. Runtime session snapshots are intentionally not tracked by chezmoi; implementation details and recovery commands live in `dot_config/sway/SESSION.md` and `docs/system/sway.md`.

### Optional-service residency policy and Cloudflare WARP status

Every new Linux app/service must follow `docs/system/system-philosophy.md` and `docs/system/service-residency-policy.md`: optional VM/Android/workflow services should be disabled at boot, started explicitly on demand, and stopped via their owning launcher. `~/.local/bin/system-residency-audit` is a read-only one-shot audit; use it before/after a service or package change, not as a background daemon. As verified on 2026-11-06, Waydroid is **disabled at boot** (container can remain active after a user-invoked start), Nano11 and `win10lab` use transient QEMU systemd units, Podman/Docker/libvirt are not installed, and Syncthing is disabled between password-vault synchronization windows. Do not stop active guests or agent sessions merely to produce an empty process list.

Cloudflare WARP was an unintended always-on exception: `warp-svc.service` has now been **stopped and disabled**, and the globally enabled user `warp-taskbar.service` is **masked/inactive**. However, `cloudflare-warp-bin 2026.8.2115-1` is **still installed**, pending local interactive authorization for Snapper and package removal. No WARP tunnel was active (missing registration) and USB-tethered routing remained functional. The separate October 19 static DNS resolver setup was intentionally not modified. See `docs/system/service-residency-policy.md` for the verified current state and remaining manual removal command.

### Nano11 / native QEMU-KVM Windows lab

Verified 2026-11-05: Nano11 now runs **directly on host QEMU/KVM 11.1.3**, not inside Dockur/Podman. The on-demand `~/.local/bin/nano11` launcher starts a transient `nano11-qemu.service` through `sudo -n systemd-run --collect` with `User=onyx` and unlimited memlock, then the unit is removed after normal shutdown. This avoids Desktop Commander's 1.5 GiB memory cgroup OOM limit and does not enable an idle VM daemon. Podman, the Dockur container/image, its unused dependencies, and residual rootless pause process/storage were removed after live native VM verification; no Docker/Podman runtime is required. Native QEMU runs with 12 vCPUs, 4 GiB guest RAM, q35, retained secure OVMF and TPM2 state, VirtIO-SCSI QCOW2, VirtIO NIC with stable MAC, non-GL VirtIO VGA fallback, and QEMU user-mode network forwarding of RDP **only to 127.0.0.1:3389**. The old Dockur web console on 127.0.0.1:8006 is removed. The persistent `/mnt/Games/VirtualMachines/dockur-nano11/` folder name is historical; its installed `storage/` and `media/` plus necessary `shared/` files were retained. Obsolete `shared/intel-driver.img` and the duplicate `shared/gfx.exe` were removed; the matching 7092 Intel driver installer remains at `shared/gfx_win_101.7092.exe`. A stopped and SHA256-verified pre-migration copy is at `/mnt/Games/VirtualMachines/nano11-backup-20261105/` on the same Games partition.

Linux/Sway remains on NVIDIA RTX 5050 with AsusMuxDgpu. Intel PF 0000:00:02.0 remains on patched i915; on-demand VF 0000:00:02.1 attaches to vfio-pci in an isolated group. Windows Intel WDDM driver 32.0.101.7092, matched Looking Glass B7-829 IDD/client and IDD ForceIndirectCopy=1 from the 2026-11-03 guest repair are preserved. QEMU maps **64 MiB `/dev/kvmfr0`** and a user-owned SPICE Unix socket. After the migration, a native Looking Glass smoke test received **actual FRAME_TYPE_BGRA 1920x1200 frames** and LGMP input/clipboard + SPICE audio channel negotiation. The RDP handshake succeeded and Windows shut down cleanly through QEMU ACPI. Migrated launch avoids Dockur's Intel Vulkan probes that previously caused host i915 GPU hangs; no long-duration performance or latency claim has been made. Prior guest hardware D3D11 and physical input/clipboard acceptance evidence still lives in the 2026-11-03 historical record.

Nano11 (Windows 11) retains workspace 10 and the Super+Alt+W launch shortcut; as of 2026-11-06, Alt+W instead opens X-Lite (Windows 10) on workspace 5. Alt+Shift+W opens the shared management menu. Nano11's capture release key is Right Ctrl; X-Lite is again configured for Right Ctrl by default with F12 as an explicit override, with physical operation subsequently confirmed by the user on 2026-11-07. `nano11 open` now invokes RDP recovery, **not** Dockur web UI. `nano11 logs` tails the native QEMU log. The transient VM service is not enabled at boot. The relevant source is `dot_local/bin/executable_nano11` with menu, fish, and desktop entry updates. The current authoritative runbook is `docs/virtualization/nano11-native-qemu.md`; `dockur-windows.md` and `nano11-recovery-runbook.md` are archived for historical guest repair evidence, not current Podman operations. The preserved pre-migration launchers are in `~/.local/state/nano11-direct-qemu-20261105/`. Do not detach the NVIDIA host GPU, replace UEFI/TPM data or expose blank-password guest RDP beyond loopback.

The Windows lab launcher menu routes Nano11 to workspace 10 and X-Lite to workspace 5 (X-Lite is now the default `Alt+W` target, with dedicated `Windows 10 (X-Lite)` desktop entry and `Super+Ctrl+5`; `Super+5` switches; existing `Super+Alt+5` network menu retained). As of November 7, the shared Windows menu renders only four version-neutral entries with icons, targeting the active VM or X-Lite by default. VM mutual exclusion and separate Nano11 launchers remain enforced outside the menu. A live Sway reload moved the client to workspace 5 without restarting QEMU. X-Lite currently defaults to Right Ctrl for Looking Glass capture release, with F12 available as an explicit fallback; physical input acceptance remains pending. A controlled Windows 10 guest restart on 2026-11-06 verified the X-Lite launcher running with Nano11-matched 12 vCPUs/4 GiB, CPU affinity 0-11 and a fullscreen Looking Glass client receiving real 1920x1200 frames with automatic host-refresh pacing; sustained 165 updates remain unverified. See the X-Lite runbook for the input-capture and refresh limitations. Both VMs are mutually exclusive on the Intel VF/KVMFR; never start a second guest by automatically stopping the first. On 2026-11-06 X-Lite's subsequent normal boot was verified without diagnostic USB disks or installer ISO (`media=none`, only the system QCOW2 attached); retained media can be requested only by an explicit diagnostics boot. Its Looking Glass client suppresses capture notifications and uses Sway `shortcuts_inhibitor disable` with `input:ignoreWindowsKeys=yes` and the restored `input:grabKeyboard=yes` setting for normal capture; the shared Windows menu offers FPS/UPS diagnostics. The 2026-11-06 client-only restart proved live LGMP frames and input/clipboard channel negotiation, not physical capture/release or Super workspace shortcut behavior. A later screenshot showed Microsoft Store `.msix` version 22308.1401.6.0 installing required frameworks without confirmation of completion, while WinGet's `msstore` source failed with `0x8a15005e` certificate-pinning error. No Store replacement tool has been installed by the agent; direct Store package retrieval candidates are documented in the X-Lite runbook. Physical keyboard, clipboard and audio acceptance, sustained moving-frame throughput, a browser DNS failure, and a missing clock-seconds cleanup still require verification. At 16:55 IST on 2026-11-06, the X-Lite guest stopped producing Looking Glass frames while QEMU remained alive. After a paced in-guest Windows restart request was ignored and disk I/O remained idle, one explicit guest-only QEMU `system_reset` at 17:07:05 restored boot I/O and **verified 1920x1200 LGMP frames**. The client is fullscreen on workspace 5 and three simultaneous `win10lab workspace` requests reused the same window/VM. The launcher contains a previously implemented on-demand single-client flock lock; there is no automatic guest reset. At approximately 20:09 IST on 2026-11-06 a physical screen photo again showed only the Looking Glass splash, and the existing Linux client log showed recurrent IDD host/session resets. A client-only diagnostic change (default `WIN10LAB_ALLOW_DMA=no`, reversible with `WIN10LAB_ALLOW_DMA=yes`) reconnected once and logged a 1920x1200 frame with LGMP input/clipboard, without restarting the Windows guest. This is *not yet* a proven durable repair or visual desktop acceptance; guest IDD stability and its two enabled copy-workaround checkboxes need review. The precise IDD/Windows stall cause, physical Alt+W and F12 behavior and Microsoft Store install completion after the hard reset remain unknown. A second incident at 19:46 IST on 2026-11-06 left an existing Looking Glass client showing only its splash with repeated `primaryLost`/invalid LGMP sessions and no new disk I/O; Shift and ACPI did not restore it. One additional explicit guest-only QEMU `system_reset` at 19:50:07 restored Windows boot I/O and 1920x1200 LGMP video after transient session reconnects. This is a short-term recovery, not a proven permanent IDD fix, and can lose unsaved guest data. The source-managed X-Lite launcher now warns if a focused client's most recent session event is `primaryLost`; the existing Windows menu has a separately confirmation-protected manual hard-reset option, never automatic. A read-only guest-side diagnostic clipboard probe was unconfirmed. The display stalled again at approximately 19:58:52 IST, 8m16s after its previous verified frame. A guest Win+Ctrl+Shift+B display reset did not help, and a guest-only QEMU system_reset at 20:03:04 recovered disk I/O and 1920x1200 LGMP video. A low-risk test command (`powercfg /change monitor-timeout-ac 0`) was sent into Windows using QEMU HMP keyboard input, but Windows-side execution/effective power setting **have not been verified**; a display timeout is a hypothesis, not a proven root cause. No host reboot, GPU rebinding, persistent service changes, or Nano11 changes occurred. The more proven Nano11 is preserved.

**Historical Windows runtime observations:** The following November 6 incident paragraphs describe earlier states. Use the newest Windows X-Lite section below and its owning runbook for current behavior.

**Windows 10 live warning (updated 2026-11-06 ~22:04 IST):** `Alt+W` now detects the intentionally **paused** QEMU state and opens the Windows recovery menu, rather than focusing a Looking Glass purple splash. `win10lab status` now includes `qemu_state=paused`; the menu offers separately confirmed resume or guest hard reset, and repeated critical display-source notifications are suppressed and a stale Looking Glass splash is closed when the paused-state menu opens. Sway accepted the existing client's close request without restarting QEMU. **This repairs the launcher and alert spam, not the Windows IDD fault.** VM remains paused, retains ~4.1 GiB memory and Intel VF, and Windows 11 remains stopped. See detailed runbook. Prior incident:  A recurring Looking Glass guest IDD/session loss coincided with a runaway Windows guest CPU workload: about seven QEMU `CPU n/KVM` threads each reached roughly 100%, while the purple splash persisted. The specific guest process or driver remains unidentified; prior resets were only transient recoveries. To protect host latency and heat, the active experimental X-Lite guest was **paused non-destructively** via `win10lab monitor stop`. HMP verified `VM status: paused`, and a fresh two-second CPU sample fell to 0.00 logical cores. **The paused process still owns around 4.1 GiB RAM, the Intel VF, and its QCOW2; Nano11 cannot start until X-Lite is safely stopped.** `win10lab status` presently says running whenever QEMU PID exists, even if HMP reports paused. Do not assume guest operability, or resume/reset without assessing loss of unsaved Windows/AppX work. Detailed evidence and next steps: `docs/virtualization/win10-xlite-experiment.md`.

**Windows 10 latest runtime observation (2026-11-06 ~22:25 IST):** The prior paused state is no longer current. Live HMP reports `VM status: running` (QEMU PID 142061, 12 vCPUs, 4 GiB). User supplied IDD configuration screenshot with full direct frame copies now unchecked and force indirect copy still checked, at 1920x1200/165.0040 Hz; a Linux LGMP client logged a frame and input/clipboard connections. **The CPU problem persists:** three-second read-only sample measured ~3.19 QEMU logical CPU equivalents, root cause unverified. Short frame acquisition is not sustained display stability. Preserve Nano11 and the distinct guest recovery paths. See `docs/virtualization/win10-xlite-experiment.md`.

**Windows 10 latest incident (2026-11-06 ~22:48 IST):** Looking Glass IDD lost its guest session after idle, switching direct input from LGMP to SPICE and leaving mouse/keyboard unresponsive. The managed launcher was using F12 rather than user-requested Right Ctrl; now default is `KEY_RIGHTCTRL`, with capture-on-focus and an on-demand client-only reconnect menu entry. Client-only reconnect did not recover a missing guest video source; QEMU ran ~6.98 host logical cores. HMP `stop` paused the VM non-destructively. **Current state is paused, not usable**; it still owns its memory/disk/Intel VF. A Windows-only guest power-policy/backup script is staged at `dot_local/share/win10lab/Configure-Guest-Idle.ps1` but NOT applied. Do not infer a durable solution until it is executed and Right Ctrl plus 17+ minute idle acceptance are verified. Windows 11/Nano11 remains untouched.

**Native Fish Windows VM interface (verified 2026-11-07):** A single on-demand `win` function, managed by `dot_config/fish/functions/win.fish` and `dot_config/fish/completions/win.fish`, replaces the redundant `nano11.fish` function wrapper. `win`/`win status` show both VM states; `win start|stop|logs|menu|reconnect` target X-Lite by default and `win 11 start|stop|logs|status|rdp` select Nano11. Fish source/live parity, syntax, tab completion, read-only command dispatch and guarded X-Lite restart refusal were verified. Neither underlying executable, Sway shortcut, VM state nor background-service configuration was changed. The previously running X-Lite guest was paused during the Fish-only change; see `docs/system/terminal-shell.md`.

**Windows menu and Fish shutdown (live verified 2026-11-07 ~02:20 IST):** The shared `Alt+Shift+W` / `win menu` Fuzzel frontend now exposes only four generic entries, Open Windows / Show or Hide Windows FPS-UPS / Stop Windows / Restart Windows, with actual Gruvbox-Dark icons; no VM-version labels or high-CPU pause rows. It routes to the running guest or X-Lite by default; Nano11 remains accessible via `win 11 ...` and its Sway binding. The prior X-Lite `win stop` failure was due to the QEMU paused-state refusal. An explicit stop now resumes a paused guest *only for a bounded graceful Windows shutdown* (ACPI then paced Windows keyboard fallback), re-pausing it if shutdown fails; there is no automatic hard reset/power kill. **Live test passed:** paused QEMU PID 576825 stopped via `fish -c 'win stop'`; client, monitor/socket and KVMFR/QCOW2 ownership were released, and stopped QCOW2 structural integrity passed. X-Lite and Nano11 are currently stopped; the guest's CLOCK_WATCHDOG_TIMEOUT instability is still a separate unresolved concern. Full technical details: `docs/virtualization/win10-xlite-experiment.md`.

**Guest shutdown control (verified 2026-11-07 18:05 IST):** X-Lite was fully stopped and its QCOW2 not owned. Guest NTFS showed clean flags 0x0000, clean restart state, no hibernation file, and passed a non-writing check. Added internal rollback snapshot `pre-wstop-20261107`, then installed the source-managed one-shot `C:\Windows\wstop.cmd` using a short-lived, lifecycle-locked offline NTFS mount. Byte-level hash and post-install `qemu-img check` passed; NBD disconnected. `win stop` continues ACPI first but the fallback now types just `wstop` into the guest Run dialog rather than the entire shutdown command. `win force-stop` is separate and requires exact typed confirmation; it abruptly powers off only X-Lite if explicitly invoked and risks data loss. Bash/ShellCheck, Fish completion and stopped-state tests passed; **execution of `wstop` inside a running guest is still unverified**. No guest boot, QEMU reset, Intel/NVIDIA rebind, Nano11 change or permanent service. Backups: `~/.local/state/win10lab/wstop-20261107/`; runbook: `docs/virtualization/win10-xlite-experiment.md`.

**Windows/Linux focus toggle (verified 2026-11-07 ~19:12 IST):** The user confirmed the current Right Ctrl capture and Windows/Super key behavior works. Added the global xremap chord `CapsLock+Tab` invoking `~/.local/bin/win-focus-toggle` (source `dot_local/bin/executable_win-focus-toggle`), switching between the running X-Lite Looking Glass client on Sway workspace 5 and the last Linux workspace using native Sway `workspace back_and_forth`. From Linux, the helper confirms a running VFIO guest and existing client; no VM startup/reset or guest keystroke injection. `xremap --validate-config`, Bash/ShellCheck, source/live parity and live 2 → 5 (Looking Glass focused) → 2 round-trip passed with unchanged QEMU PID 59835. The physical Caps+Tab chord itself awaits user testing; global xremap remains active with config-watch. No changes to Sway bindings, Right Ctrl, guest disks or daemons. Backup: `~/.local/state/win10lab/caps-tab-focus-20261107/`. See `docs/system/xremap.md`, `docs/system/sway.md` and `docs/virtualization/win10-xlite-experiment.md`.

**Looking Glass Right Ctrl status visibility (verified 2026-11-07 ~18:43 IST):** The launcher previously suppressed capture notifications with `win:alerts=no`. Only that option was changed to `win:alerts=yes`, without changing any Sway, xremap, shortcut-inhibition, Windows-key forwarding or input-capture settings. A client-only reconnect kept the same Windows QEMU PID 38249, focused the new client PID 43915 fullscreen on workspace 5, and verified 1920x1200 LGMP video/input and clipboard. The configured escape key remains `KEY_RIGHTCTRL`; **the user subsequently confirmed the Right Ctrl capture toggle works on 2026-11-07**. Backup: `~/.local/state/win10lab/rctrl-alerts-20261107/`. See `docs/virtualization/win10-xlite-experiment.md`.

**Windows workspace-5 keyboard/capture routing (source and live verified 2026-11-07 ~18:29 IST):** Changed the X-Lite Sway `for_window` rule from `shortcuts_inhibitor disable` to `enable`; Looking Glass now passes Windows/Super keys (`input:ignoreWindowsKeys=no`). Existing `input:captureOnStart=yes` and `input:captureOnFocus=yes` request capture on guest startup and on focus return, retaining `KEY_RIGHTCTRL` as the escape key and `autoCapture=no` to avoid immediate recapture after user release. Removed `--inhibited` from global Super+`1..0` and Super+`u/i/o/p` workspace bindings; those keys reach *any* focused shortcut-inhibiting client (including games), while working as host workspace switching outside capture. `Alt+Shift+W`, `Alt+W`, `Super+Ctrl+5` remain protected `--inhibited` host controls. Sway 1.12 headless config validation, `sway-check` (0 errors/warnings), safe live reload, Bash/ShellCheck, and chezmoi/live parity succeeded. After installing and reloading, a separately tracked controlled X-Lite startup (`win10-input-acceptance-20261107.service`) verified QEMU PID 33283 running, Looking Glass PID 33339 focused/fullscreen on workspace 5 with 1920x1200 BGRA frames and LGMP input; client metadata records `escape=KEY_RIGHTCTRL`. During early guest activity a 3-second QEMU CPU sample measured 3.54 logical cores, not established idle. **Physical single-press Right Ctrl capture release, return-to-workspace auto capture and guest Windows-key delivery remain to be tested by the user**. xremap/Nano11/GPU/guest disks unchanged. Backups: `~/.local/state/win10lab/input-capture-20261107/`; runbook: `docs/virtualization/win10-xlite-experiment.md`.

### Windows X-Lite Micro10 experimental lab

**Latest repair (2026-11-07):** Authorized diagnostics identified heavy KVM HPET emulation (141,945 MMIO exits/0.503 s, reduced to 5/0.501 s after reference-clock/synthetic-timer enlightenments). A later USB-free clean boot exposed a distinct **0x101 CLOCK_WATCHDOG_TIMEOUT, vCPU 6**, with LGMP loss and automatic Windows restart. X-Lite had disabled crash dumps/event logging; the backed-up guest helper enabled small dumps/event logging and captured the real failure. The launcher now adds `hv-relaxed=on` to `host,kvm=on,hv-time=on,hv-vpindex=on,hv-synic=on,hv-stimer=on` as a **controlled compatibility test**, not a stability claim. A USB-free 30-minute trial was tracked by `win10-relaxed-idle.service` (started 01:37:29 IST with observer PID 577205 and QEMU PID 576825); its earlier process IDs and test state are historical, not current. Four managed clean stops/offline QCOW2 checks passed. 12 vCPUs/4 GiB, BIOS/AHCI, Intel hardware D3D11, PF i915/VF vfio-pci/NVIDIA remain preserved. Normal GPU mode omits USB tablet; basic VGA recovery retains it. Monitor AC/DC Never and 1920x1200@165 verified, rollback retained. Bidirectional focused clipboard and silent SPICE/PipeWire output passed; physical Right Ctrl/Super shortcuts were subsequently confirmed working by the user on 2026-11-07; audible quality was not independently accepted. Store absent, current UserDataSvc DLL present. The shared menu was subsequently simplified to four Windows-only actions while the underlying launchers retain VF mutual exclusion, client-only recovery, FPS controls, metadata and bounded logs; Nano11 installation/launcher remain untouched and stopped. No forced reset/off, host reboot/rebind, new permanent daemon or CPU cap. Evidence/current acceptance: `docs/virtualization/win10-xlite-experiment.md`.


As of 2026-11-06, a **separate experimental Windows 10 Pro 22H2 build 19045.3757** X-Lite Micro10 guest was installed and booted through a new on-demand `win10lab` native QEMU launcher. Its isolated 40 GiB virtual disk is `/mnt/Games/VirtualMachines/xlite-micro10/storage/win10lab.qcow2`; ISO `media/xlite-micro10-19045.3757.iso` is retained (original downloaded 7z extracted and deleted as requested). The third-party ISO's unattended file creates a blank-password admin account and weakens protection; test guest **outbound IPv4 NAT is now enabled by user request** (QEMU user-mode `e1000e`, no hostfwd; offline option `WIN10LAB_NETWORK=0`), but the ISO's blank-password Admin and weakened protections make this guest unsafe for sensitive online use. The current VM uses **4 GiB RAM** rather than its historical 3 GiB initial-install baseline. A clean, stopped internal QCOW2 snapshot is `clean-xlite-pre-intel-vf`. With virtual VGA and **before Intel graphics/IDD**, Windows reached a desktop and Task Manager showed **39 processes and 0.6/3.0 GiB RAM used**. Before the driver installation, cold boot with Intel VF `0000:00:02.1` black-screened virtual VGA; PCIe root-port hotplug subsequently exposed the device. On 2026-11-06, the signed Intel graphics driver **32.0.101.7092** installed through `pnputil` and the Windows PCI `8086:A78B` device changed from Code 28 to **Code 0**. The matched Looking Glass **B7-829 IDD** and IVSHMEM driver then installed; configuring `ForceIndirectCopy=1` and nominal `1920x1200@165.004` succeeded. Linux received actual **1920x1200 BGRA LGMP frames** with input/clipboard and SPICE audio channels, including after a cold boot with the Intel VF and 64 MiB KVMFR already attached. The `win10lab glass` command launches the matched client and now defaults to **IDD-only QEMU video** (`-vga none`) when Intel VFIO is active. On 2026-11-06, a guest display audit found Windows opening apps on the fallback VGA primary monitor (1024x768) while the 1920x1200 LG IDD was secondary and appeared empty. Removing emulated VGA only from GPU mode fixed this: both Windows Settings and Task Manager became visible in Looking Glass after a clean guest reboot. Plain `win10lab start` still retains VGA-only recovery; Nano11 and its GPU setup remain unchanged. The Micro10 launcher now recreates and binds only the Intel SR-IOV VF when it disappears after a host reboot, refusing a non-i915 PF or shared IOMMU group; a live 2026-11-06 test restored VF `0000:00:02.1` with the PF still on i915. A guest audit identified `WUDFHost.exe` high CPU with loaded `lgidd.dll` (do not disable UMDF); the taskbar seconds/DPI cleanup is staged but not verified applied due concurrent guest input. A November 6 stabilization audit independently verified D3D11 hardware creation on Intel 8086:A78B (feature level 11.0), guest DNS/IPv4 and HTTPS HTTP 200 from the Windows Update endpoint, again after clean VM relaunch. Windows Update remains blocked by guest-disabled BITS/wuauserv. Lifecycle locks, pre-rebind isolation/ownership checks and paced HMP shutdown recovery are source-managed. Repeated input was cleared by a user-requested guest reset; its origin and physical input/clipboard acceptance remain unresolved. Sustained 165 UPS, audible playback quality and unattended long-term stability are **not verified**; some test sessions ended with unexplained clean QEMU exits. `win10lab` defaults to no VF for recovery; keep the known-good Nano11 VM separate, untouched and stopped when testing the VF. The managed `win10lab stop` now falls back from ignored ACPI power events to an on-demand guest Windows shutdown through paced QEMU HMP keyboard input (the older localhost VNC fallback failed in IDD-only mode); an earlier fallback test exited cleanly and `qemu-img check -q` passed. Current details: `docs/virtualization/win10-xlite-experiment.md`. Nano11 remains the better-tested Windows guest; Micro10 now has verified Intel VF Code 0 and real Looking Glass capture but is still experimental, uses isolated outbound NAT, and is not validated for multi-hour sessions or another host cold boot.

### Waydroid / Android runtime

As of 2026-11-02, `waydroid-nvidia-bin 0.2.0-1` is installed on the RTX 5050 dGPU-only session and the 0.2 migration is complete. `/var/lib/waydroid/waydroid.cfg` selects `nvidia_driver_mode = nvidia-prolapse`, `nvidia_native_gl = off`, and the v0.2.0 vendor-image OTA; the release gate passed all 22 Android/Android32 cases plus media checks against NVIDIA kernel module `615.78.08`. Live verification showed Android booting with SurfaceFlinger GLES on ANGLE/NVIDIA Vulkan/NVK. The managed `waydroid-launcher` starts the disabled `waydroid-container.service` on demand, starts `wd-venus.service` only for Venus mode, and waits for the Waydroid client bridge before opening the UI. `waydroid-stop` stops the session and restores `waydroid-container.service` to disabled/inactive. `waydroid-restart` composes those existing stop/start helpers to perform a full clean restart and reopen Android; Alt+Space exposes separate Restart/Stop Waydroid entries, and Fish aliases are `wd`/`wds`/`wdr` for launch/stop/restart. Automatic stop-on-Sway-window-close is intentionally not used because Android activity transitions can replace the `app_id=Waydroid` surface and look like a close event. Host Sway pointer devices, `/dev/udmabuf`, the Waydroid Pulse socket mount, and the PipeWire/DAX stack were verified healthy. As of 2026-11-02, reversible Kitsune/Magisk root is installed through WaydroidSU in the existing system overlay; the base `system.img` and NVIDIA `vendor.img` remain unchanged, `Kitsune Mask` (`io.github.huskydg.magisk`) is installed, and `magiskd` is running. A clean cold boot re-verified Play Store, Houdini ARM translation, networking, the Waydroid audio HAL, and ANGLE on NVIDIA Vulkan/NVK. ADB-shell `su` remains denied until explicitly granted in Kitsune superuser policy. Pre-root rollback data is retained under `~/waydroid-backup-pre-magisk-20261102/`. The current Waydroid image contains ClearKey DRM but no Widevine CDM/plugin, so protected JioHotstar playback may be black/silent; do not treat that as a generic host audio-routing failure or attempt to spoof hardware-backed Widevine/attestation.

### Auto-synchronized live workstation snapshot

The block below is maintained by `scripts/sync-system-context.sh` for every durable workstation/configuration commit made from the live chezmoi repository. It records measured runtime facts across the desktop/GPU, audio stack, mounts, kernel, and basic system health. The repository pre-commit hook refreshes and stages only this generated block automatically; agents must still update the relevant semantic subsystem documentation and changelog themselves.

<!-- AUTO:SYSTEM_STATE:BEGIN -->
> Auto-synchronized from the live workstation by `scripts/sync-system-context.sh`. This is measured runtime state, not semantic documentation. Do not edit inside these markers.

- Last live sync: **2026-11-07**.
- OS/kernel: `CachyOS` / `7.3.1-1-cachyos`.
- GPU mode: `AsusMuxDgpu`.
- NVIDIA: `NVIDIA GeForce RTX 5050 Laptop GPU`, driver `615.78.08`.
- Sway: `sway version 1.12`; validation: **PASS**.
- Active output: `eDP-1, 1920x1200 @ 165.004 Hz, scale 1.30, adaptive sync disabled`.
- Persisted generated UI scale: `1.30`.
- Sway reload path: `sway-safe-reload` (validates before `swaymsg reload`).
- Audio: PipeWire `1.6.10`, WirePlumber `0.5.18`.
- Default audio sink: `bluez_output.9E_74_98_79_5D_15.1`.
- Default audio source: `ghelper-audio`.
- Root mount: `/dev/nvme0n1p6[/@] btrfs /`.
- Games mount: `/dev/nvme0n1p5 ntfs3 /mnt/Games`.
- Windows mount: `/dev/nvme0n1p3 ntfs3 /mnt/windows`.
- Failed systemd units: system `1`, user `0`.

These values are a convenience snapshot for cross-agent context. Exact runtime-sensitive values must still be re-queried before diagnosis or modification.
<!-- AUTO:SYSTEM_STATE:END -->














## 4. System design invariants

The stable design philosophy is defined in `docs/system/system-philosophy.md`. Important operational invariants are:

- Gaming latency, stable frametimes, and a responsive terminal-first desktop take priority over visual effects.
- Avoid animations, blur, shadows, and unnecessary compositor/UI overhead.
- Prefer on-demand tools over resident processes.
- Do not add a daemon merely for convenience when a one-shot/event-driven mechanism works.
- Preserve the direct dGPU MUX path when it is intentionally active.
- P-core-only launch policies may be used for latency-sensitive games such as CS2 where the existing launcher requires them.
- Keep Snapper retention lean and avoid destructive Btrfs operations.
- Preserve portable chezmoi configuration: no hardcoded personal usernames, secrets, or machine-private credentials.
- Make the smallest robust fix and preserve unrelated work.

## 5. Audio baseline and freshness warning

The 2026-10-23 audit verified:

- PipeWire `1.6.9`.
- WirePlumber `0.5.18`.
- 48 kHz graph rate with quantum 512 in the audited setup.
- A persistent processed microphone path named `ghelper-audio` was functioning at that audit.
- ASUS speaker DSP, gaming audio routing, and A2DP-only Bluetooth policy were functioning in that audit.

Important freshness warning: audio/Dolby reverse-engineering work continued after the 2026-10-23 audit. Therefore, before changing microphone defaults, virtual sources, PipeWire filters, WirePlumber rules, or OBS routing, always inspect the live graph and current repo source. Do not assume the audit's default source is still active.

Primary references:

- `docs/audio/`
- `docs/system/audio-pipewire.md`
- `docs/system/audio-stack-status.md`
- `docs/ASUS_SPEAKER_DSP_MANIFEST.md`
- `docs/ASUS_SPEAKER_DSP_PARITY_REPORT.md`

## 6. Storage and filesystem caution

Storage documentation has changed over time and older documents may conflict with the actual current layout.

In particular, `docs/system/SYSTEM-REPRODUCIBILITY.md` contains historical assumptions about `/mnt/Games`, Btrfs, Hybrid GPU operation, and bootstrap behavior that must not be treated as current runtime truth without verification.

Before filesystem, mount, Steam-library, CoW/NoCoW, Snapper, or partition changes, verify at minimum:

```sh
lsblk -f
findmnt /
findmnt /home
findmnt /mnt/Games 2>/dev/null || true
findmnt /mnt/windows 2>/dev/null || true
sudo snapper list-configs 2>/dev/null || true
```

Never recommend `chattr +C`, Btrfs repair operations, filesystem conversion, or mount-option changes based solely on an older document.

## 7. Core workflow and tools

The workstation is intentionally keyboard-first and terminal-heavy.

Common components include:

- Sway/Wayland.
- Foot and Alacritty terminals.
- fish shell.
- Neovim/NvChad and Zed.
- Fuzzel/Rofi-style launch workflows.
- xremap for keyboard remapping. Katana S K2 reconnect is managed by `bt-keyboard-reconnect.service`, now a native C `sd-bus`/`sd-event` daemon built from managed `~/.local/bin/bt-keyboard-reconnect.c` through the content-addressed launcher `~/.local/bin/bt-keyboard-reconnect`. It handles disconnect/backoff plus resume/adapter/session signals when BlueZ's native retry window expires; live verification measured about 3.5 MiB RSS / 0.4 MiB PSS dormant in epoll and confirmed automatic reconnect plus xremap fallback attachment. `bt-katana` remains a one-shot fallback, while xremap dynamically watches input device nodes.
- PipeWire/WirePlumber for audio.
- Steam/Proton/native Wayland gaming tools.
- systemd user services only where persistent behavior is justified.

Iosevka Nerd Font is the current preferred UI/terminal family in recent configuration; installing alternatives does not change that default. The full Omarchy-compatible programming-font set is package-managed as of 2026-11-01: JetBrainsMono Nerd Font, CaskaydiaCove/Cascadia, MesloLG Nerd Font, FiraCode Nerd Font, VictorMono Nerd Font, BitstromWera Nerd Font, and Iosevka Nerd Font.

## 8. Protected and high-risk areas

Before touching these areas, inspect current docs and source carefully:

- CS2 launcher and game-specific launch wrappers.
- MangoHud configuration.
- GPU/MUX switching and NVIDIA environment variables.
- PipeWire/WirePlumber routing and DSP.
- Btrfs/Snapper/filesystem operations.
- bootloader/initramfs configuration.
- systemd services that affect login, audio, GPU, suspend, or hardware control.
- encrypted chezmoi source and age identities.

Do not remove protection, immutability, or safety wrappers just to make an edit easier.

## 9. Agent control plane

For agents with live-machine access, prefer the existing control-plane commands:

```sh
agent-context system
agent-refresh
agent-check system
```

`agent-context` is the preferred bootstrap because it combines durable repo rules with fresh runtime state.

Runtime-generated state such as `~/.local/share/agent/environment.json` is evidence about the current machine, not permanent configuration. Do not commit generated runtime state into this repository.

See `docs/system/agent-control-plane.md` for the control-plane architecture.

Cross-agent routing is centralized: Codex, Antigravity/AGY, and OpenCode global instruction files are thin pointers back to this repository, while `dot_agents/skills/` is the canonical procedural skill library. `sync-agent-skills` exposes that library to each agent without copying skill contents. Use `docs/system/SUBSYSTEM_MAP.md` to decide which docs and optional skill belong to a task.

Desktop Commander Remote is a persistent user-systemd bridge on this workstation. `desktop-commander.service` is enabled under `default.target`, so it starts automatically with the user systemd session; chezmoi restores that enablement through `run_onchange_linux-20-reconcile-services.sh.tmpl`.

ChatGPT desktop launches via the packaged `/usr/share/applications/chatgpt.desktop` and the chezmoi-managed `~/.config/chatgpt-flags.conf` (`--ozone-platform=wayland`). The Fuzzel `Alt+Space` menu retains only the native ChatGPT app, not the former chatgpt.com favorite. `Super+Alt+G` focuses the running ChatGPT window or launches it via a one-shot, chezmoi-managed helper. See `docs/system/sway.md` for the mechanism and Linux overlay caveat.

KeePassXC is the current Linux password-manager client. Its encrypted KDBX database is intended to live under `~/Sync/KeePass/`, replicated through Syncthing folder ID `keepass-vault` with simple 10-version history. To preserve the workstation's daemonless design, `syncthing.service` is disabled from persistent startup; `keepassxc-sync` opens only short pre/post sync windows around KeePassXC use and stops Syncthing afterward. Brave uses KeePassXC-Browser through the local native-messaging host; the vault/master password and any recovery material remain outside chezmoi. See `docs/system/password-manager.md`.

## 10. Documentation map

Use this file to choose the next source, not as a reason to load the entire documentation tree.

- `docs/README.md`: global documentation index.
- `docs/system/system-philosophy.md`: stable goals and non-negotiable design principles.
- `docs/system/workstation-audit-2026-10-23.md`: last broad measured workstation audit at this sync.
- `docs/system/SYSTEM-REPRODUCIBILITY.md`: provisioning/recovery reference; verify stale assumptions before using.
- `docs/system/SYSTEM_CHANGELOG.md`: concise material system-change history for agents.
- `docs/system/SUBSYSTEM_MAP.md`: task/config-path routing to owning docs and optional skills.
- `docs/system/password-manager.md`: KeePassXC, Syncthing, Brave integration, and Android credential-sync baseline.
- `docs/audio/`: audio architecture and detailed DSP/routing docs.
- `docs/display/`: Wayland, dGPU, display, vibrance, brightness.
- `docs/gaming/`: game-specific launch/runtime configuration.
- `docs/theme/`: Base46/theme synchronization architecture.
- `docs/virtualization/`: Waydroid and Windows virtualization.
- `docs/bootloader/`: boot and Plymouth/GRUB customization.
- `docs/projects/`: custom project documentation.

Read only the relevant branch of documentation for a task.

## 11. Required update contract for every agent

For every verified durable workstation/configuration change made by an AI agent, documentation is part of the same implementation task:

1. Update the implementation in the correct source-of-truth file.
2. Validate the changed subsystem with the strongest safe check available.
3. Update at least one relevant detailed Markdown document under `docs/` so the resulting behavior and operational assumptions are discoverable without chat history.
4. Update the semantic portions of this file when a current-state fact, invariant, important path, protected baseline, or cross-agent assumption changes. The auto-managed runtime snapshot is refreshed by the local pre-commit hook for every durable system commit.
5. Append a concise verified entry to `docs/system/SYSTEM_CHANGELOG.md` for the commit.
6. If an older document now conflicts, correct it or explicitly mark the conflicting portion historical/stale.
7. Do not report the system change complete until the implementation, validation, and documentation are synchronized.

The repository pre-commit hook enforces steps 3 and 5 for local system commits and refreshes the generated runtime snapshot automatically. It does not write semantic documentation on behalf of the agent. Do not update current-state documentation for speculative plans; put future work in the appropriate roadmap/future document.

## 12. Known documentation conflicts to resolve gradually

The following are explicitly not authoritative when they disagree with fresher evidence:

- Older Hybrid/iGPU-desktop descriptions versus the verified `AsusMuxDgpu` baseline.
- Old internal-panel connector names versus live `swaymsg -t get_outputs` results.
- Old storage filesystem assumptions versus live `findmnt`/`lsblk` results.
- Old usernames or absolute `/home/<name>` paths in documentation versus portable `$HOME`/`~` configuration policy.
- Old audio defaults versus live PipeWire/WirePlumber state after ongoing Dolby/DSP work.

Agents should fix these conflicts opportunistically when working in the affected subsystem, rather than performing broad unrelated documentation rewrites.
