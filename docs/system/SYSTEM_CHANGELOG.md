# System Change Log

Concise cross-agent record of durable, verified workstation/configuration changes.

This is not a replacement for Git history or subsystem documentation. Use it to answer: "What changed recently that another agent should know before touching the system?"

Rules:

- Newest entries first.
- Record only verified/applied changes, not plans.
- Keep entries short and point to the owning subsystem/file when useful.
- Do not paste large diffs, logs, or transient diagnostics here.
- If a change alters current machine assumptions, also update `SYSTEM_CONTEXT.md`.

## 2026-11-01

### Theme palette, wallpaper matching, and hot-reload hardening

- Hardened `theme-set` with read-only `--check` / `--check-all` preflight, post-Base30 contrast enforcement, unresolved-template rejection, fsynced/change-aware writes, transactional rollback on promotion failure, and preservation of the Mako/Swaybar/GTK geometry owned by `ui-sync`. Generated consumers now hot-reload only when their target changes; a verified same-theme reapply changed no theme-state, Neovim-marker, or wallpaper mtimes.
- Reworked centralized wallpaper assignment to profile the actual local image pixels instead of trusting Wallhaven bucket metadata as the match authority. The best-scoring visual match remains first and alternatives are reuse-balanced; all 327 themes pass audit, all 63 curated assets are used, 48 are first choices somewhere, and maximum all-slot reuse is 35. No network fetch or asset replacement was needed for the remap.
- Verified live dark -> light -> original switching (`gruvchad` -> `github_light` -> `apollo-after-dark`) with two Neovim instances plus Foot, Fuzzel, Mako, Sway IPC, wallpaper persistence, and output scale 1.30 intact. Apollo now selects `wallhaven-r25x6m.webp` and its remembered wallpaper state matches the applied file.
- Hardened `rofi-theme`: stale cache synchronization is completed before the 327 rows are exposed, Enter preflights and synchronously applies the exact selected ID, failures stay visible with captured diagnostics, and Ctrl+R reports the real sync result instead of always claiming success. Binary-safe script-mode tests verified exactly 327 unique rows, successful same-theme no-op apply, invalid-theme error retention, and sync result handling.

### Fullscreen screenshots no longer enter the screenshot buffer

- `Caps+Space` still launches `screenshot-fullscreen`, saves the capture to the normal screenshot directory (or `Screenshots/Gaming`), and copies it to the clipboard. It does not enqueue by default; enqueueing occurs only while explicit screenshot buffer mode is enabled with `Caps+Shift+Space`.
- With buffer mode OFF the success notification is `Screenshot Done`; with buffer mode ON it becomes `Screenshot Buffered` and reports the queue count. Existing queued files are not deleted.

### Compacted Ctrl+Space scratch terminal and notification/OSD chrome

- Reduced the dedicated `scratch-term` Foot override from 16.5 pt to 16 pt; notes/DC scratchpads and the global Foot font are unchanged.
- Reduced Mako base chrome in `ui-metrics.conf` from font/padding/margin/width/radius `17/10/10/500/8` to `15/8/8/440/6`; `ui-sync` continues deriving scale-correct live values, so brightness, volume, night-light, and ordinary notifications all become slightly smaller without changing the compositor scale.

### Caps+Shift+Space controls explicit screenshot buffer mode

- `CapsLock-Shift-Space` now toggles `screenshot-buffer toggle` instead of opening the picker. `CapsLock-Space` remains the normal fullscreen screenshot action and CapsLock tap remains `Esc`.
- With buffer mode OFF, `Caps+Space` saves and copies normally with `Screenshot Done`; with buffer mode ON, the same fullscreen capture is additionally queued and reports `Screenshot Buffered`. No other xremap mappings were changed.

### Removed redundant Bluetooth keyboard reconnect daemon

- Removed the resident `bt-keyboard-reconnect.service` and Python helper after live verification showed BlueZ already owns Katana S K2 BLE HID reconnect (`ReconnectUUIDs`, retry backoff, trusted/bonded/wake-enabled device) and the custom daemon could collide with pending BlueZ connects. The keyboard remained connected after retirement; `xremap --watch=config,device` and the existing udev keyboard rule own attachment.
- Kept `bt-katana` as a one-shot manual/login/resume fallback but removed its redundant xremap restarts. This removes roughly 13 MiB PSS of resident Python memory and periodic retry wakeups without removing Bluetooth functionality.

### Waydroid protected-media diagnosis and on-demand shutdown

- Verified the post-migration Waydroid audio bridge itself is intact: `audio.primary.waydroid.so` uses the correctly mounted host Pulse socket, Android media volume is nonzero, and the host PipeWire/DAX audit remains clean. The current Android image ships ClearKey DRM only and no Widevine CDM/plugin, explaining JioHotstar protected-video black/silent playback without implicating the host DSP stack.
- Added `waydroid-stop`, a separate Fuzzel `Stop Waydroid` entry, and the desktop Stop action. The helper stops the Android session and legacy Venus service, then `disable --now`s `waydroid-container.service`; the NVIDIA setup-created boot enablement was removed so Waydroid is on-demand only. A compositor close-event guard was tested and rejected because Android activity transitions can destroy/recreate the Waydroid surface and cause false shutdowns.

### Waydroid 0.2 migration completed and launcher readiness

- Completed the `waydroid-nvidia-bin 0.2.0-1` migration with `nvidia-prolapse`, `nvidia_native_gl=off`, and the v0.2.0 vendor image. The package release gate passed all 22 Android/Android32 cases plus media checks on NVIDIA module `615.78.08`; live Android is boot-complete and SurfaceFlinger reports ANGLE on NVIDIA Vulkan/NVK.
- Hardened `waydroid-launcher` against the cold-start race where Waydroid reports `Session: RUNNING` before the client bridge is available: it now waits for `waydroid app list` to succeed before opening the UI/app. The user `Waydroid.desktop` entry used by Alt+Space Fuzzel now calls `waydroid-launcher` through the verified Sway PATH instead of a hardcoded home path. Bash syntax, desktop-file validation, source/live parity, client-bridge readiness, and the running Waydroid session were verified.

### Fish clipboard file arguments

- Extended the lazy-loaded Fish `clip` function so `clip file`, `clip file1 file2`, and glob-expanded groups such as `clip *.rs` copy regular-file contents to the Wayland clipboard; literal arguments and `<command> | clip` retain their previous behavior.
- Verified Fish syntax and all three input modes with an isolated fake `wl-copy`, leaving the real clipboard untouched; chezmoi source and live function are identical after targeted apply.

### Removed stale Dark Souls III launcher entries

- The Dark Souls III game directory is absent. Removed the four local XDG/chezmoi menu entries for the game, randomizer, CYCLES installer, and ME3 manager so Fuzzel no longer lists an uninstalled title; historical game documentation and helper scripts remain for reference.

### Centralized curated wallpaper library for every theme

- Added `theme-wallpaper-library` and moved theme wallpaper storage to `~/.local/share/theme/wallpapers/`: shared curated assets in `assets/`, preserved Omarchy/repository fallbacks in `upstream/`, and a chezmoi-managed provenance/mapping manifest. The former `~/.cache/theme/wallpapers/` cache was hash-verified, consolidated into the central root, and removed without losing unique files.
- Mapped all 327 exposed themes to three palette-matched choices while storing only 63 unique curated assets. Automated selection uses Wallhaven General/SFW 16:9 or 16:10 sources of at least 1920x1200, an explicit AI metadata/source denylist, and a conservative pre-2022 upload cutoff; local files are WebP quality 92 with no upscaling and a 2560x1600 ceiling. Metadata/date filtering is treated as conservative provenance evidence rather than proof of authorship. Added `imagemagick` to `packages/sway.txt` so a rebuild has the required `magick` normalization tool.
- `theme-set` remains network-free and now prefers the centralized curated mapping; `theme-wallpaper` cycles local mapped assets and retains `upstream/` as compatibility fallback. Verified library audit: 327/327 themes, 63/63 local curated assets, three choices per theme, selected uploads from 2014-2021 only, local dimensions from 1920x1200 through 2560x1600.
- Verified live Sway cycling on `waffle-cat`: `next` applied curated slot 2/3 and `set 1` returned to slot 1/3 with successful compositor IPC. `~/.config/current_wallpaper` points into the centralized `assets/` tree and the obsolete cache path is not recreated.

### Alt+Space launcher proportions and cursor sizing

- Kept the native Fuzzel `Alt + Space` launcher at its original compact `width=36`, `lines=10` proportions while setting `image-size-ratio=0` so the separate oversized selected-app preview is gone. Added `FUZZEL_LINE_HEIGHT=26` to the central UI metrics so `ui-sync` generates a 20px logical row at scale 1.30, giving slightly larger application icons without making the launcher feel bulky or rigid.
- Reduced the Phinger cursor from 32px to the next native 24px raster and synchronized Sway, GTK3/4, GSettings, Xresources, environment.d, and the live Sway seat.
- Verified the real Fuzzel UI after restoring the compact proportions: no large lower preview is rendered and the list keeps the minimal narrow shape with modestly enlarged row icons. `fuzzel --check-config`, `ui-sync`, source/live parity, and Sway validation are clean.

### Sway session restore cwd and backup hardening

- Fixed Foot session cwd capture: Sway reports the shared Foot server PID for every terminal surface, so the old saver stored the server cwd (`/`) and startup restore opened the ws1 shell at root, producing the Pure prompt lock indicator. Terminal cwd is now recovered per window from the Fish/Pure title, with `$HOME` fallback when it cannot be proven.
- Restore now launches Foot clients with explicit `footclient -D <cwd>` and migrates legacy plain ws1 `footclient` snapshots whose erroneous cwd is `/` to `$HOME`. Foot/Footclient are treated as multi-instance entries in both save and restore paths.
- Hardened session backups: the current valid snapshot is atomically copied rather than moved to `session.json.prev`, and the last 8 validated snapshots are retained under `~/.config/sway/session/backups/`; invalid sessions are never promoted into backup slots.
- Verified live: two consecutive saves produced ws1 cwd `/home/onyx` in both `session.json` and `session.json.prev`, preserved the pre-fix snapshot in history, `sway-session-save.service` remains enabled/active, source/live helpers match, and a direct legacy-root restore test resolves to `footclient -D /home/onyx` without launching a window.

### Neovim dashboard tabufline navigation guard

- Fixed `E5108: Invalid 'buf': Expected Lua number` from NvChad buffer navigation on the Alpha dashboard. `vim.t.bufs` is legitimately empty there, while the installed `nvchad.tabufline.next()` / `prev()` implementation dereferences its first element.
- Added a local compatibility guard in managed `lua/configs/ide.lua` that removes stale/invalid tab-buffer entries and makes next/previous navigation a no-op when no listed buffer exists. The existing command-line-window close guard remains in the same wrapper; no files under the lazy plugin directory are patched.
- Verified headlessly on Neovim 0.12.5: Alpha stays on the same dashboard buffer with empty tab state and no error, and two real listed files still cycle previous/next correctly. Source and live chezmoi targets match after apply.

### Bluetooth connection retry safety

- Removed external `timeout` wrappers from `bt-select` and `bt-refuse-toggle` connection attempts. BlueZ `Connect()` is now allowed to finish its controller page naturally, avoiding pending HCI connection attempts that could make immediate retries fail with `br-connection-busy`.
- `bt-select` now starts disconnected checked devices in parallel, reducing multi-device wait time to one controller page interval. It sets/moves audio to a Bluetooth sink only when exactly one selected device is connected; with multiple live selected sinks it preserves the current default.
- Updated the active Bluetooth/audio documentation to match the Foot-based `bluetui` launcher and the current connection semantics.

### Compact launcher and utility-TUI geometry

- Compacted the Rofi network menu and theme picker around Iosevka Nerd Font Mono, with the theme picker now 600px wide and the network menu 420px wide; the bottom command launcher remains full-width with reduced typography/padding.
- Fuzzel now takes scale-derived font/padding/border values from `ui-sync`, uses a 36-column/10-row launcher layout, and keeps the active theme's generated color include authoritative.
- Sway utility floats were reduced to 900x600 for `wifui`/`bluetui` and 900x680 for `rogtui`; each uses a 15pt per-client Foot override so the global terminal font remains independent.

### Read-only battery meter and optional cursor-raster tooling

- Fastfetch's battery row now calls the one-shot `battery-meter` helper, which reads BAT0 capacity/status and renders the slider-style display without changing ASUS charging policy.
- Added `build-cursor-sizes` as an explicit opt-in Xcursor resampling tool. `--check` is read-only; no intermediate sizes have been applied to the live Phinger themes, which currently remain at their native 24/32/48/64/96/128 sizes.
- Made the new `environment.d/30-cursor.conf` portable by using `${HOME}` in `XCURSOR_PATH` rather than a machine-specific home path.

### Cursor size reduced to 32px and both cursor tools reworked

- Found the cursor stuck at 64px with four disagreeing consumers: Sway seat and live `10-display.conf` at 64, GSettings at 64, GTK 3/4 at 64, while `environment.d/30-cursor.conf` still exported `XCURSOR_SIZE=32`. Set every consumer to 32 and applied it live through Sway IPC.
- Root cause of "changing the size does nothing": `adjust-cursor-size` clamped at 64 (the Phinger theme ships up to 128), never snapped to a size the theme actually provides (24/32/48/64/96/128), and only repaired the live Sway config, leaving the session environment, GSettings, GTK, and the chezmoi source to drift.
- Rewrote `adjust-cursor-size` to step along the theme ladder, snap absolute values, update the live seat plus all config consumers and their chezmoi sources, print a status report when run without arguments, and exit 2 at the bounds instead of silently clamping.
- Rewrote `toggle-cursor-theme` to the same contract: it preserves the current size, validates that the target theme is installed, writes both chezmoi sources, refreshes the session environment and the `~/.icons/default` Xwayland fallback, and exposes `status` and explicit `dark` / `light` arguments.
- Brought `environment.d/30-cursor.conf` under chezmoi as `dot_config/environment.d/30-cursor.conf` so `XCURSOR_THEME` and `XCURSOR_SIZE` each have one source of truth.
- Changed the cursor size keybindings from `+4` / `-4` to `+2` / `-2`; the magnitude stays a direction marker because the theme only ships six discrete sizes.
- Verified: `adjust-cursor-size` reports 32 across Sway, GTK, GSettings, Xresources, and session env; `+`/`-` step 32 to 48 and back; a dark then light round trip left the theme identical in all ten consumer rows and kept the 32px size; `sway -C` loads with no errors.

### Smaller Ctrl+Space scratchpad font

- Split the Ctrl+Space `scratch-term` font from the other scratchpads in `~/.local/bin/scratch-toggle`: it uses `SCRATCH_TERM_FONT_SIZE`, tuned through 15 pt and 16 pt before settling at 16.5 pt, while `scratch-notes` and `dc-term` keep `SCRATCH_FONT_SIZE` (17 pt). The current global `foot.ini` font is 16.6 pt.
- Verified by respawning the live client: the new `footclient --app-id=scratch-term` command line carries `-o font=Iosevka Nerd Font Mono:size=16.5:style=Regular`, and the scratchpad toggles visible at 1328x830 after the 90% output cap. `sh -n` and `chezmoi apply` were clean.

### Palette-faithful theme catalog, deduplication, and Omarchy font set

- Retired the dedicated `ds3-wallpaper` helper and removed all active callers. `Win + Shift + W` and `Alt + Shift + W` now advance the active theme's Omarchy wallpaper set through `theme-wallpaper`; the compatibility `random-wallpaper` and unbound `wallpaper-menu` also delegate only to `theme-wallpaper`. Existing DS3 image files were left untouched as ordinary user data.
- Reworked Schema 1 normalization so authored syntax hues are preserved instead of being replaced with generic spectrum targets; current Omarchy semantic values are retained separately from generated compatibility aliases, preventing repeated `theme-sync` runs from drifting palettes. Lightness-only contrast correction now guarantees body text `>=4.5:1`, syntax/focused borders `>=3.0:1`, and inactive borders `>=1.7:1`; background luminance corrects clearly wrong upstream dark/light labels.
- Updated `theme-set` and the Sway theme template to derive visibility-safe focused/inactive borders from each theme's own accent/background. A fresh 327-theme runtime audit passed with minima 4.513/3.002/3.001/1.700. The runtime normalization also reapplies the 3.0:1 syntax/non-text contrast floor after selecting authored `base_30` aliases, preventing those aliases from undoing Schema 1 correction; Synthwave '84 retains its purple identity (`#ff00ff` accent and purple `BASE0B=#8f00ff`).
- Reworked Omarchy catalog reconciliation to prefer the official validated registry catalog and registry-pinned commits, with `omarchy.org/themes` as the first fallback and legacy endpoints last. During 2026-11-01 live verification the registry hostname did not resolve from this machine, so the gallery fallback was used: 232 of 233 listed repositories were reachable and mirrored into chezmoi; the sole missing entry, `ankur311sudo/gruvu`, returned repository-not-found and was not replaced from an unofficial mirror. Old unlisted imports and duplicate repo filenames were removed. Imported preview metadata is persisted as portable `~/.cache/theme/previews/...` paths rather than embedding the local username/home directory.
- Added conservative generated-catalog deduplication with an auditable `~/.cache/theme/dedup.json`: 351 source files are present; provider/name reconciliation compiles 350 canonical inputs into 347 pre-dedupe cache names, then suppresses 20 exact or same-family near copies to expose 327 themes. Source definitions remain intact for reproducible recompilation.
- Added the full Omarchy-compatible Nerd Font package set to `packages/sway.txt` and installed the six previously missing alternatives alongside JetBrainsMono: Cascadia/CaskaydiaCove, MesloLG, FiraCode, VictorMono, BitstromWera Mono, and Iosevka. All seven packages are verified at `3.5.1-2`; the configured default font was not changed.
- Added bounded Omarchy wallpaper sets: all 232 reachable community imports now keep at most five primary repository backgrounds, with old/alternate/vertical candidates deprioritized; 21/22 locally maintained official Omarchy built-ins also map to their exact current `omacom/omarchy` background directories, while legacy `omarchy-osaka-jade` remains intentionally unmapped because current upstream has no exact matching directory. Added daemonless `theme-wallpaper` to fetch only the active/requested theme's pinned GitHub images on demand, cache them under `~/.cache/theme/wallpapers/`, cycle with `Win + Ctrl + W` / reverse with `Win + Ctrl + Shift + W`, and let `theme-set` restore cached per-theme selections without network access. First-use downloads were later optimized to libcurl parallel transfers under a per-theme `flock`, with Python validation fallback; import/theme application remain network-free. Measured serial Aetheria at 35.1s before the optimization and the real helper fetching five Ayaka images (~32 MiB) in 2.33s afterward, subject to network/CDN variance.

### Foot terminal font sizing and `foot-font` Sway fix

- After additional tuning, the current global Foot font is `Iosevka Nerd Font Mono:size=16.6` Regular via `foot-font`, with `font-size-adjustment=0.5`; notes/dc scratchpads stay at 17 pt through `SCRATCH_FONT_SIZE`, and the Ctrl+Space scratch terminal uses 16.5 pt.
- Documented that the long-lived `foot-server.service` parses `foot.ini` only at startup and `footclient` forwards just `-o` overrides, so file-based font changes need `restart-terminals`; verified by a 24 pt `foot.ini` leaving a new window at the same 147x35 grid while `-o font=...:size=17.5` changed it to 137x32.
- Fixed a `foot-font` regression that corrupted `~/.config/sway/config.d/00-variables.conf`: the `$term` insertion regex used `\s+`, matched the line's own newline, and wrote `-o font="..."` onto the next comment line, which made `sway -C` report an invalid `-o` command. The tool now only rewrites an override that already exists, never injects one, and restores the variables file if the Sway check fails.
- Verified: `foot --check-config` clean, `sway -C` exit 0 with no load errors, `swaymsg reload` clean, live `foot.ini` identical to the chezmoi source, and repeated `+0.5`/`-0.5` runs left the Sway variables file untouched.

### Theme hot-reload reliability and cache discipline

- Reproduced the intermittent `theme-set` failure as a real concurrency race: simultaneous switches shared `~/.local/state/theme/.next/`, producing missing staged files, validation failures, and occasional `FileNotFoundError` promotion errors.
- Added an `fcntl.flock()` single-writer lock across theme selection, compilation, promotion, and live dispatch; converted short reload IPC/hooks to bounded ordered execution; and made Neovim RPC/Base46 refresh complete before the lock is released instead of relying on daemon threads/background processes that could finish out of order.
- Fixed the remaining NvChad stale-theme path: `theme-set` no longer hides Base46 errors inside `pcall` or marks `~/.local/share/nvim/base46/current_theme` before compilation succeeds. Live sockets now invalidate the selected theme module and return an explicit success/error result; a successful live reload supplies the disk cache, while the no-editor fallback uses normal headless NvChad startup. Verified Pathos by forcing a temporary NvChad instance to Gruvchad/dark and switching through `theme-set`: it returned to `pathos|light`; the no-live-socket path also rebuilt and marked Pathos successfully.
- Preserved the existing Foot OSC/per-client include fix, and also repaired `theme-set --info` so Cava-capable themes no longer reference an undefined accent variable.
- Made `theme-sync` deterministic and write-if-changed, pruned stale generated JSON/preview/NvChad outputs, and fixed byte-identical preview handling. A no-change forced sync of 290 themes now measures about 0.165s after canonicalization; a five-round concurrent switch stress test completed with zero failures.
- Corrected `theme-check` so `gradient_count=0` is valid when Cava gradients are disabled; validation noise dropped from 290 warnings to the two real low-contrast themes. `theme-doctor` now reports executable hook count rather than counting `.keep`.

### Conservative stale-system cleanup

- Removed `simde` and `uthash` after verifying both were true `pacman -Qdt` dependency orphans, required by no installed package, and absent from the declarative package manifests. Snapper protection was present and package hooks also created the normal pre/post snapshots.
- Pruned Pacman package cache while retaining two installed-package versions and removed cached packages for no-longer-installed packages, reclaiming about 1.96 GiB total. No failed system/user units or zombie processes were present.
- Did not clear NVIDIA shader, Go build, browser, or other performance-sensitive caches. `uv cache prune` was intentionally not forced because active MCP `uvx` processes held the cache lock.

### Global media play/pause shortcut

- Restored the old Hyprland-style global MPRIS play/pause action in Sway on `Win + Alt + P` using a one-shot `media-play-pause` helper backed by `playerctl`.
- Added a short Mako OSD showing the resulting `Playing` / `Paused` state after each toggle; no resident media helper or polling loop was added.
- Moved ROG Aura preset cycling off that chord to `Win + Alt + [` (previous) and `Win + Alt + ]` (next), preserving the hardware controls without a binding collision.

### Desktop Commander startup persistence

- Enabled the existing chezmoi-managed `desktop-commander.service` under the user `default.target`, so the remote bridge starts automatically with the user systemd session instead of depending on a manual `dc` invocation.
- Added `desktop-commander.service` to `run_onchange_linux-20-reconcile-services.sh.tmpl` so future `chezmoi apply` / rebuilds restore the enabled state without adding a duplicate Sway autostart process.
- Verified the unit is both `enabled` and `active`, and that `default.target` now lists `desktop-commander.service` as a dependency.

## 2026-10-31

### Foot theme hot-reload correctness

- Fixed `theme-set` so Foot no longer receives SIGUSR1/SIGUSR2 after palette regeneration; Foot 1.28 uses those signals only to select the long-lived server's already-cached dark/light sections, which could restore stale Gruvbox colors.
- Existing Foot windows now receive only targeted OSC palette updates through their own PTYs, with no broad `/dev/pts/*` broadcast.
- Added a zero-resident `~/.local/bin/footclient` exec wrapper that injects the current generated `foot-colors.ini` into every new server client, so future windows match the active theme without restarting `foot --server`.
- Verified the stale-server condition directly: an unmodified Foot server client reported background `#282828`, while a client using the generated include reported the active Solarized Osaka background `#011219`.

### Unified Codex / AGY / OpenCode automation

- Added `docs/system/SUBSYSTEM_MAP.md` so fresh agents route implementation paths to the correct active docs and optional procedural skill without loading the whole documentation tree.
- Added deterministic `scripts/check-system-docs.sh` and GitHub Actions `system-docs-check`, so local and remote/cloud system commits must carry `SYSTEM_CHANGELOG.md` plus matching semantic subsystem documentation.
- Replaced stale global Codex/AGY/OpenCode machine-state instruction copies with thin chezmoi-managed pointers back to repository `AGENTS.md`.
- Added `sync-agent-skills` and an after-apply hook to expose the single `dot_agents/skills/` library to Codex, Antigravity, and OpenCode while preserving built-in/non-managed skills.
- Brought the previously live-only `reverse-engineer-anything` skill and its references under chezmoi so all three primary agents receive the same 12 custom skills.
- Reconciled the newer live `bluetooth-autoconnect` skill changes into source before applying shared governance, preserving its 2026-10-29 foreground-only/connect-timeout fixes.
- Added a mandatory authority/freshness notice to shared skills so dated machine details cannot override live state, current repo source, `SYSTEM_CONTEXT.md`, or owning subsystem docs.

### System-wide AI documentation contract

- Generalized the repository pre-commit documentation hook from Sway/UI-only detection to all durable workstation/configuration source changes in chezmoi, package/service manifests, provisioning hooks, and system helper scripts.
- AI-authored system commits now require both `docs/system/SYSTEM_CHANGELOG.md` and at least one relevant semantic Markdown document under `docs/`; the generated `SYSTEM_CONTEXT.md` snapshot does not satisfy the semantic-document requirement by itself.
- Expanded `scripts/sync-system-context.sh` to record a verified cross-subsystem runtime snapshot: OS/kernel, GPU mode and NVIDIA driver, Sway/output/scale, PipeWire/WirePlumber/default endpoints, root/Games/Windows mounts, and failed systemd-unit counts.
- Kept subsystem-specific validation layered on top: Sway/UI changes still run `sway-check`, while other subsystems remain responsible for their own strongest safe validation before completion.
- Added `SYSTEM_DOCS_EXEMPT=1` only as an explicit manual/emergency bypass; AI agents are forbidden by `AGENTS.md` from using it unless the user explicitly authorizes bypassing documentation enforcement.

### Sway reliability and reload hardening

- Made `ui-scale` persist `99-ui-scale.conf` atomically and skip unchanged writes.
- Added read-only `sway-check` and validator-gated `sway-safe-reload`; `Win + Shift + R` now uses the safe reload path.
- Made `ui-sync` avoid unnecessary generated-file writes/reloads for Mako, Swaybar, GTK CSS, and Swaylock while preserving existing behavior.
- Removed redundant display/input defaults, simplified the Foot launcher to `footclient`, and changed one-shot Sway session initialization from `exec_always` to `exec` so ordinary reloads do not restart `swayidle`, the game workspace daemon, xscroll, or other one-shot helpers.
- Verified Sway syntax, a live safe reload, unchanged long-running helper PIDs, and live `eDP-1` at 1920x1200 ~165.004 Hz with runtime scale 1.20.

### Initial cross-agent context synchronization

- Added the first `scripts/sync-system-context.sh` and pre-commit integration as a Sway/UI-only implementation; this was generalized later the same day by the system-wide AI documentation contract above.
- Added `dots-publish` as a safe explicit commit-and-push wrapper: it commits only already-staged files and never performs a broad `git add -A`.
- Established the core rule that generated runtime context never replaces agent-authored semantic subsystem documentation.

### Desktop Commander command interface

- Updated `dc-start` so plain `dc` ensures the service is running and shows status, while `dc status` is strictly read-only.
- Preserved explicit `dc start`, `dc stop`, `dc restart`, and `dc logs`; unknown subcommands now fail with usage text instead of implicitly starting the service.

## 2026-10-29

### Centralized cross-agent system knowledge

- Added `docs/system/SYSTEM_CONTEXT.md` as the canonical AI-facing current-system entry point.
- Reworked root `AGENTS.md` into a small shared bootstrap/behavior contract instead of duplicating mutable machine state.
- Added `CLAUDE.md` as a Claude-specific pointer to the same shared rules and context.
- Updated `docs/system/agent-control-plane.md` so live runtime state overlays, rather than replaces, repository documentation.
- Established explicit source precedence and a mandatory documentation-update contract for future agents.

### Current repository baseline incorporated

- Accounted for the central Sway UI-scaling architecture introduced by commit `1a533b95dd9d6c8661b8f617b5914c0d3f369f6f`.
- Kept the 2026-10-23 workstation audit as the latest broad measured-system baseline while explicitly flagging post-audit audio/Dolby work for live revalidation.
