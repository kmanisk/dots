# System Change Log

Concise cross-agent record of durable, verified workstation/configuration changes.

This is not a replacement for Git history or subsystem documentation. Use it to answer: "What changed recently that another agent should know before touching the system?"

Rules:

- Newest entries first.
- Record only verified/applied changes, not plans.
- Keep entries short and point to the owning subsystem/file when useful.
- Do not paste large diffs, logs, or transient diagnostics here.
- If a change alters current machine assumptions, also update `SYSTEM_CONTEXT.md`.

## 2026-11-13

### Local Coder Policy Gateway production promotion and three-mode security architecture

- Promoted the Local Coder Policy Gateway to production under dedicated system user `localcoder` (UID 947, GID 947) running system unit `chatgpt-local-coder-policygate.service` on ports 3000 (MCP) and 3001 (Admin UI).
- Implemented three operational security modes:
  - `STRICT`: Read-only inspection by default; signed operator approval required for mutations and executables; no sudo.
  - `STANDARD` (Default): Trusted project workspaces under `/srv/local-coder/projects/`, development commands, git inspection without repeated approvals; signed approval for sudo/destructive actions.
  - `YOLO` / `FULL ACCESS`: Root-operator interactive signed lease (`policygate-operator yolo --duration <min>`) with time limit; narrow escalation broker execution (`/usr/local/bin/local-coder-escalation-broker`); automatic revert on expiry or `yolo --off`.
- Sandboxing: `ProtectHome=yes`, `ProtectSystem=strict`, `BindReadOnlyPaths=/home/onyx/.local/share/chezmoi:/srv/local-coder/context/chezmoi`, `BindPaths=/srv/local-coder/workspace /srv/local-coder/projects`.
- Bridge authorization: eliminated obsolete `SECURITY_PRIVILEGED_COMMAND_REQUIRED` error via scoped single-use HMAC token injection when operator approved or YOLO is active.
- Tool restoration: 35 tools active including safe read-only Git tools (`git_status`, `git_diff`, `git_log`, `git_branch`), process supervision (`start_process`, `process_output`, `stop_process`, `clear_processes`), `system_context`, and `chezmoi_inspect`.
- Monitor styling: overhauled `local-coder-status` and scratchpad `local-coder-monitor` (`Win + Alt + D`) with vibrant high-contrast ANSI colors, category color-coding, and 12-hour AM/PM timestamps (`%I:%M:%S %p`).
- Audit integrity: append-only `+a` ledger at `/var/log/local-coder-policygate/audit.jsonl` verified against trusted root anchor.
- Rollback tested and verified: stopping `chatgpt-local-coder-policygate.service` and starting user unit `chatgpt-local-coder.service` restores legacy setup in 1.1s. Owning documentation: `docs/system/chatgpt-local-coder.md`, `docs/system/agent-control-plane.md`.

### Atlas IDD continuation preflight and media checksum verification

- Verified stopped clone disk integrity, paired IDD-on/off OVMF checksums, GPU-binding preflight and zero residency findings through Local Coder. Retained selected matching B7-829 upstream source; documented historical mode mismatch and remaining runtime profiling/cadence gates. Requested LTSC ISO matches supplied hashes and independent HeiDoc catalog SHA256; original authenticated Microsoft hash metadata remains unavailable. No new VM experiment, restore, guest/host configuration change or accepted fix. User subsequently explicitly approved sudo, but Local Coder rejected the privileged probe with SECURITY_PRIVILEGED_COMMAND_REQUIRED (managed mode requires an authorization token). Connected tool schema lacks auth_token and no token-grant tool is exposed; agent_status incorrectly reports open access. No connector security settings were changed. Runtime work remains blocked by that connector authorization mismatch; all three VMs remain stopped. Evidence: `docs/virtualization/atlas-21h2-baseline.md` and clone `inspection/atlas-idd-continuation-preflight-20261113.md`.

### Isolated Atlas Looking Glass IDD CPU regression and timer A/B confirmed

- Created a **standalone** Windows 10 Atlas 21H2 A/B clone at `/mnt/Games/VirtualMachines/atlas-21h2-ab-20261113/`, with distinct QCOW2/OVMF storage, on-demand launcher, scoped CPU/thermal monitor, VNC port and four paired experimental snapshots. Verified all guest test boots stopped cleanly, watchdog windows passed and QCOW2 checks succeeded. No original Atlas, Nano11, NVIDIA, Intel PF, system service/autostart or shared launcher changes.
- Guest PnP `ROOT\DISPLAY\0000` (Looking Glass Indirect Display Device) **enabled** averaged 1.173 host QEMU cores at idle. Disabling this exact display device lowered CPU to ~0.22 cores, with a verified 0.217-core cold-boot repeat. Keeping IDD enabled while deleting only `useplatformtick` averaged 1.090 cores; independently deleting only `disabledynamictick` averaged 1.147 cores. Thus IDD-enabled activity is the proven idle CPU regression, not either Atlas timer tweak alone; the underlying capture/driver mechanism remains unresolved. Clone left **stopped at the verified low-CPU IDD-disabled checkpoint**, so Looking Glass is **not available** on that fallback.
- All changed Windows settings were restricted to the disposable clone. Both original Atlas and Nano11 remain stopped and untouched. Verified logs and recovery: `docs/virtualization/atlas-21h2-baseline.md` and clone `inspection/atlas-ab-findings-20261113.md`. No commits or pushes.

## 2026-11-12

### Unpinned native ChatGPT app from Workspace 2 and updated Win+Alt+G focus summoner (verified)

- Removed `chatgpt` from the Workspace 2 browser assignment/move rules in `dot_config/sway/config.d/30-window-rules.conf` and `~/.config/sway/config.d/30-window-rules.conf`, allowing ChatGPT to open directly on whichever workspace it was launched from with `border pixel 2` and `floating disable`.
- Updated `dot_local/bin/executable_chatgpt-focus` and `~/.local/bin/chatgpt-focus` (`Win+Alt+G`) to dynamically query the active workspace and summon any existing ChatGPT window (`app_id` or `class`) to the active workspace (`move to workspace <name>, focus`), or launch a new instance on demand.
- Updated documentation in `docs/system/sway.md`. Verified with `sway-check`, `sway -C`, and live reload. No commits or pushes made.

### Tuned Win + Alt + D Local Coder monitor font size in Foot scratchpad to 15 pt (verified)

- Tuned the `dc-term` Local Coder monitor scratchpad font in `dot_local/bin/executable_scratch-toggle` and `~/.local/bin/scratch-toggle` by adjusting `SCRATCH_DC_FONT_SIZE` to 15 pt (tuned from 17 pt and 12 pt per user request).
- Terminated the existing running `dc-term` instance and verified fresh spawn with `size=15`. Updated `docs/system/foot.md` and `docs/system/chatgpt-local-coder.md`. No commits or pushes made.

### Atlas Looking Glass B7-829 short frame success and GPU device-removal regression (verified)

- The separate offline Atlas 21H2 VM passed VGA/VFIO/post-Intel-driver 60-minute idle checks and explicit Intel D3D11 render/readback. A pre-IDD partial QCOW2 snapshot and paired OVMF vars were preserved. Matching B7-829 IDD briefly delivered actual 1920x1080 and 1920x1200 BGRA frames, but a later client test lost the LGMP source and QEMU rose to approximately five host CPU cores. Guest IDD log confirms 0x887A0005 (D3D12 GPU device removed/suspended); cause remains undetermined. The exact Atlas VM was manually paused and shut down gracefully by the bounded `atlas21h2-lg-regression-shutdown-20261112.service` (exit 0); stopped QCOW2 integrity check passed. Atlas is stopped and NOT Looking-Glass-stability-accepted. No Nano11 changes, guest network, legacy LG Host service, daemon, host GPU rebinding, committed or pushed files. Details: `docs/virtualization/atlas-21h2-baseline.md`.

### Implemented passwordless root permissions and transparent sudo elevation for Local Coder

- Configured ChatGPT Local Coder agent prompt instructions (`CODEX_AGENT_PROMPT`, `MCP_QUICKSTART`, `/home/onyx/Projects/AGENTS.md`) to establish passwordless root authority (`(ALL) NOPASSWD: ALL`), enabling ChatGPT to manage packages (`sudo pacman`), systemd units (`sudo systemctl`), and system configuration directly via `run_command` without password prompts.
- Created `src/lib/sudo-fs.ts` providing transparent privilege escalation (`readFileSafe`, `writeFileSafe`, `unlinkSafe`, `mkdirSafe`, `rmDirSafe`, `copyFileSafe`, `moveFileSafe`, `statSafe`, `readdirSafe`). When standard Node.js user permissions encounter `EACCES` or `EPERM` on root-owned or system files outside `$HOME` (e.g. `/etc/`, `/boot/`, `/usr/`), filesystem tools automatically elevate using non-interactive `sudo -n tee`, `sudo -n cat`, `sudo -n rm`, and `sudo -n mkdir`.
- Updated `src/tools/filesystem.ts`, `src/lib/patch.ts`, and `src/lib/checkpoint.ts` to utilize safe filesystem operations. Validated that writing and reading files in root-restricted paths (tested via `/etc/test-mcp-root.txt` and `/etc/mcp-test-root-verify.txt` over live MCP JSON-RPC tools/call) succeeds with automatic checkpointing and without permission crashes.
- Rebuilt TypeScript project (`tsc`), passed all 10 test suites (43 tests), restarted `chatgpt-local-coder.service`, and verified live `/health` and tool invocation over loopback and Funnel. Updated `docs/system/chatgpt-local-coder.md`.

### Configured ChatGPT Local Coder MCP server and Tailscale Funnel lifecycle

- Cloned `hoangcoderr/chatgpt-local-coder` at commit `bc2ce5e6cb12fac20633065fb122fabbbb5c98c3` into `/home/onyx/Projects/chatgpt-local-coder`.
- Installed `tailscale 1.104.5` and `pnpm 12.19.0` via `pacman -S --needed` after pre-installation Snapper snapshot #519 (post-snapshot #520); added to chezmoi package manifests `packages/common.txt` and `packages/development.txt`.
- Built TypeScript project with `pnpm run build` (`tsc`) and ran all 10 unit/integration test suites (43 tests passed, 0 failed).
- Created owner-only `.env` (mode 0600) with generated 256-bit `MCP_TOKEN` and `ADMIN_TOKEN`, binding `HOST=127.0.0.1`, `PORT=3000`, `ADMIN_PORT=3001`, `CHATGPT_TOOL_PROFILE=slim` (27 tools), and `WORKSPACE_PATH=/home/onyx/Projects`.
- Created on-demand systemd user service `chatgpt-local-coder.service` (disabled at boot per residency policy) and operational lifecycle controllers `local-coder-start`, `local-coder-status`, `local-coder-stop`, and `local-coder`.
- Verified local health check at `http://127.0.0.1:3000/health`, verified unauthenticated root returns HTTP 404, and verified token-authenticated MCP JSON-RPC `initialize` and `tools/list` handshake returning HTTP 200 and session ID.
- Verified live Tailscale Funnel forwarding on `https://onyx.tail646579.ts.net` proxying loopback port 3000; public MCP `initialize`, `tools/list` (27 tools), and live `agent_status` tool call succeeded over public HTTPS Funnel with Admin UI (port 3001) verified unreachable externally.
- Retired `desktop-commander.service` (disabled, stopped, and removed from user units), reclaiming ~250MB RAM; re-wired `Win + Alt + D` scratchpad to toggle `local-coder-monitor` displaying live status, Funnel state, and streaming `.mcp-audit.log` tool calls.
- Consolidated connector details file strictly into `/home/onyx/Projects/chatgpt-local-coder/chatgpt-connector.txt` (mode 0600), removing duplicate files.
- Verified clean shutdown via `local-coder-stop`, freeing ports 3000/3001 and leaving zero unexpected resident daemons (`system-residency-audit` passed with 0 findings). Documented in `docs/system/chatgpt-local-coder.md`.

## 2026-11-11

### Consolidated user captures and photos into central Media library

- Verified `/mnt/Games` NTFS3 `nocase`: `Other`/`other` resolve to the same inode, while only `others -> Other` was a redundant symlink (safely unlinked). Tracked `media-consolidate-20261111.service` exited 0 after copying and SHA256-verifying 506 Sway screenshots (273,768,215 bytes) into `/mnt/Games/Other/Media/Screenshots`, preserving original screenshots in a dated Btrfs backup and linking old screenshot path to the new library. Two loose MP4s moved to `Recordings/Imported` by atomic rename; two MW4 edited clips and a downloaded image copied and verified under `Videos/Edits` and `Photos/Downloads`, with old paths linked for app compatibility and backups retained. Existing COD MW4, Surya, Waydroid data and unrelated project assets untouched.
- GSR UI v6.1.7 saves to `Recordings/GPU-Screen-Recorder`, `Recordings/Replays`, `Screenshots` using its untracked user-owned JSON config, backing up the prior config first; no codec/audio changes. OBS output remains `Recordings` with existing AV1/7 GiB splitting, and both Waydroid read-only binds remain valid. Sway screenshot helpers add an offline NTFS-unmounted fallback under `~/Pictures/Screenshots-Offline` without changing hotkeys. Verified source/live shell syntax and media symlink access; no new service, package, reboot, commit or push. Details and rollback: `docs/system/media-library.md`.

### Hardened OBS WebSocket recording shortcuts after follow-up audit

- Fixed `obs-record start` launching another OBS when the running instance's WebSocket was unavailable, and `obs-record stop` force-signaling OBS on WebSocket failure. Both now fail safely; `stop` never terminates OBS. Reworked the one-shot standard-library WebSocket v5 client to verify the upgrade, authenticate with the OBS-generated password and validate replies. Activated `auth_required=true` and 0600 permissions in untracked OBS-owned plugin settings, because prior unauthenticated WebSocket was listening beyond loopback. Original helper/config backed up locally (including private password). An isolated authenticated mock server passed handshake/status/stop and no-fallback-on-failure tests. OBS itself was closed, so no live capture/key injection test was performed; existing Sway bindings and recording format unchanged. See `docs/audio/obs-recording.md`. No commit or push.

### Repaired OBS Studio recording shortcuts and eliminated duplicate instance dialog

- Diagnosed why `Alt + Shift + X` spawned an "OBS is already running!" popup instead of stopping recording: Sway's bindings executed nonexistent CLI argument `obs --stoprecording`, which attempted to launch a secondary OBS instance.
- Enabled OBS built-in WebSocket v5 (`~/.config/obs-studio/plugin_config/obs-websocket/config.json`) on `127.0.0.1:4455` without authentication.
- Created `~/.local/bin/obs-record` (managed in `dot_local/bin/executable_obs-record`) to interact directly with OBS over WebSocket: `start` begins recording (or launches OBS if closed), `stop` issues `StopRecord` and notifies with the output filename, and `status` queries live recording metrics.
- Updated `40-keybindings.conf` and `50-gaming-mode.conf` to invoke `obs-record start` and `obs-record stop`. Validated with `sway-check` and `sway-safe-reload`. Verified live start/status/stop cycle without duplicate instance errors.


### Atlas Intel VFIO and signed guest driver verified; post-driver idle pending

- The isolated Atlas test VM passed 240/240 samples of VFIO-only idle (mean 0.182 host cores, peak 0.27, 89 C package peak, zero safety pauses). The Intel 32.0.101.7092 display driver was installed offline via its signed INF after the bundled GUI installer failed; Windows Device Manager reported the Intel UHD VF working properly, and DxDiag Render confirmed WDDM 2.7 and Direct3D acceleration enabled. A normal ACPI shutdown, stopped-disk QCOW2 check (exit 0), and VFIO cold boot preserved the working Intel driver. A separate post-driver 60-minute idle check is running as `atlas21h2-postdriver-idle-20261111.service`; its outcome is not yet verified. No Looking Glass, guest network, host GPU rebinding, Nano11 changes, commits, or pushes. Details: `docs/virtualization/atlas-21h2-baseline.md`.

### Waydroid vendor OTA and cropped-content display recovery (observed, verified)

- The user's Waydroid Updater installed MAINLINE vendor build `eng.aleast.20261022.130727` at 02:48:31 IST and restarted Android. Before that update, a fresh screenshot showed Android content occupying only ~65% of an otherwise correctly tiled Sway Waydroid window; a compositor-only resize did not correct it. After the update/restart a new window covered its full tile, and a workspace 2->1->2 switch retained full content. Update-vs-restart causality is not isolated. No assistant-induced Waydroid restart, persistent display override or Android-data change.
- Verified NVIDIA 620.70.06 Venus/ANGLE rendering, `sys.boot_completed=1`, Waydroid IP, installed Google Photos/Kitsune, direct-subsurface workaround and both driver/subsurface read-only checks. `waydroid-container` and `wd-venus` remain disabled at boot and active on demand; residency audit 0 findings. Source of truth: `docs/virtualization/waydroid-guide.md` and `docs/virtualization/waydroid.md`. No commit or push.

### Retiled a stale full-workspace Brave floating window on workspace 2

- Live Sway IPC found Brave Origin main window ID 264 as `floating=user_on`, almost full-display, hiding tiled tabs on workspace 2. Its existing `for_window`/`tiling_drag disable` protections operate at map-time/input-time and did not retroactively correct the previous floating state. Issued `[con_id=264] floating disable`; verified the same browser window in the normal tabbed tiling tree at workspace size 1476x923, with zero remaining workspace 2 floats. `toggle-floating-strict` continues to retile browsers; Sway validation passed. Existing mouse/keyboard guards were already source/live-synchronized; no new watcher/daemon, source-rule change, config reload, browser restart, extra window or commit/push. An arbitrary future external Sway IPC float remains outside these protections. See `docs/system/sway.md` section 9.

### Atlas idle/cold boot acceptance and isolated VFIO test

- The separate Windows 10 Atlas VGA guest passed 60 minutes idle (mean 0.155 cores, max 0.33 cores, 82 C peak, zero safety pauses), two graceful ACPI shutdowns, stopped-disk image check, baseline internal snapshot atlas-clean-20261111 with matching OVMF vars, and a cold boot to desktop.
- Added an opt-in start-vfio launch mode guarded against binding errors and IOMMU overlap. Host Intel PF remained i915, VF already vfio-pci, NVIDIA host remained intact. QEMU with VF started and displayed Windows over VNC; no driver/3D acceleration validation or Looking Glass yet. The separate monitored 60-minute VFIO-only idle run is active under atlas21h2-vfio-idle-20261111.service. No commit or push.

## 2026-11-10

### Corrected oversized OBS Qt interface without changing global display scale

- Diagnosed live OBS process `QT_SCALE_FACTOR=1.5` from an untracked user `.desktop` entry, superimposed on Sway output scale 1.30. Managed a corrected per-OBS native Wayland launcher (`QT_QPA_PLATFORM=wayland QT_SCALE_FACTOR=1.0`) in chezmoi and applied the same override to existing default and gaming-mode OBS Alt+Shift+R/X hotkeys without rebinding keys. Backed up original desktop/Sway files. `desktop-file-validate`, `sway-check`, `sway-safe-reload`, and source/live parity passed; OBS was gracefully restarted without interrupting an active recording. Verified actual process Qt scale 1.0, native Wayland window, visually smaller interface, screen/audio capture reconnection, and preserved AV1 CQP18/60 FPS/7 GiB recording setup. Global Qt/GTK scale, Sway output scale, theme and PipeWire untouched; no service, commit or push. See `docs/audio/obs-recording.md`.

### Fixed recurrent Waydroid hwcomposer/SurfaceFlinger crashes via Sway-safe composition

- Reproduced repeated paired `SIGABRT` dumps in `hwcomposer.waydroid.so` and Android `surfaceflinger` while the NVIDIA Venus ABI check was healthy. The persistent `persist.waydroid.use_subsurface=true` matches upstream's direct-subsurface failure mechanism on non-KWin compositors (#21). With Waydroid stopped, backed up the root config and changed only this property to `false`; regenerated host/guest property files using offline `waydroid upgrade -o`. Verified runtime false, working Sway UI and Android IP, Settings/Play Store/full-UI switching, unchanged compositor PIDs for over two minutes and zero new core dumps in that test window. Exact internal abort and longer-term stability not proven.
- Added managed `waydroid-subsurface-ensure` and integrated it into the existing on-demand `waydroid-driver-ensure` so a future NVIDIA setup won't silently restore the unsafe `true` default. No daemon, automatic boot service, Android data reset, NVIDIA driver update, unrelated edits, commit or push. Bash/ShellCheck, Python compile, healthy no-op checks passed. Owner docs: `docs/virtualization/waydroid-guide.md` and `docs/virtualization/waydroid.md`.

### Confirmed Atlas desktop and staged formal idle test

- The isolated Windows 10 Pro Atlas guest completed offline OOBE and reached the Atlas desktop with taskbar, with no networking, Intel VFIO, Looking Glass or host shares. Installation/first-login watchdog's first 32 samples peaked at 2.78 QEMU host CPU cores and 83°C with no safety event; those numbers are **not** an idle baseline.
- A recoverable transient user-unit 60-minute idle trial is configured with 60-second settle time and a verified-PID QEMU thermal/CPU watchdog. Results must be verified from `monitor/latest-idle.status.json` before claiming success. No commit or push.

### Isolated offline Atlas 21H2 QEMU baseline prepared and Windows Setup reached

- Verified the downloaded Atlas v0.5.2 21H2 ISO as Windows 10 Pro **19044.1889**, a customized unsupported build. Created independent 64 GiB QCOW2 and OVMF vars for a 4 GiB/6-vCPU SATA/VGA/VNC-only VM with no NIC, VFIO, Looking Glass or host shares. Nano11 remains the sole normal desktop backend and is unchanged.
- Added on-demand `atlas-lab` source/live launcher and `atlas-monitor` script for bounded CPU/thermal monitoring and safety pause. Created read-only unattended installation floppy targeting only the fresh disk; corrected the image's invalid empty ProductKey using a public non-activating Pro installation key. Verified Windows Setup reached file-copy stage and the disk was receiving writes.
- No complete guest install, Windows desktop login, clean guest shutdown or 60-minute idle pass is yet claimed. All later verification results must be recorded in `docs/virtualization/atlas-21h2-baseline.md`. No commit or push.


### Google Photos-ready OBS recording segmentation

- Enabled OBS 33.0.1 automatic recording splits **by size** (`RecSplitFile=true`, `RecSplitFileType=Size`, `RecSplitFileSize=7168` MB) so each segment targets about 7 GiB, below Google Photos' published 10 GB/video normal backup limit. Preserved NVENC AV1 CQP18/P6, native 1920x1200 60 FPS, Rec.709 SDR, 48 kHz AAC, Hybrid MP4 and `/mnt/Games/Other/Media/Recordings`. Backed up pre-change `basic.ini` and restarted OBS gracefully. The new Wayland window, output profile, AV1 support and active audio streams were verified; no 7 GiB split test or actual Photos playback upload was performed. Details: `docs/audio/obs-recording.md`. No commit/push or new services.

### Configured OBS NVENC AV1 recording location and verified audio capture routing

- Gracefully restarted OBS 33.0.1 after backing up its live profile, encoder and scene JSON. Updated both recording-folder settings to existing `/mnt/Games/Other/Media/Recordings`; kept native 1920x1200 60 FPS/NVENC AV1/P6/Hybrid MP4, increased CQP fidelity 20->18, set Rec.709 limited SDR, retained 48 kHz stereo AAC 320 kbps and muted mic. Pinned the mic capture to existing `ghelper-audio` without changing the PipeWire graph; left default-following output monitor intact for games routed through different DSP paths. New OBS Wayland window and screen/audio capture streams returned after restart.
- Audio static is not conclusively resolved: the OBS warning about capture and audio-monitoring device overlap persists even though source monitoring is off, and the sampled old recording did not clip. A fresh short listening test remains necessary. No extra services, DSP changes, application removal, commit or push; app-owned OBS config is intentionally not checked into chezmoi. Evidence, settings and rollback: `docs/audio/obs-recording.md`.

### Recovered stale Waydroid session and added conservative launcher self-healing

- A Venus-mode Android session reported RUNNING with UNKNOWN guest IP and no Sway window. GUI relaunch returned zero without a surface; guest app service and GPU driver checks passed. Previous SurfaceFlinger crashes were observed, but their connection to this later stall is unproven. The existing `waydroid-restart` recovered the guest IP, new Waydroid window, and app access with no data reset.
- Updated live and chezmoi `waydroid-launcher` to detect only the triple condition (RUNNING + UNKNOWN IP + no Sway surface) twice on explicit invocation, then invoke the existing clean `waydroid-stop` once and proceed. Five isolated condition tests, Bash/ShellCheck, and healthy real no-restart launch passed; future naturally stale branch remains to be verified. No resident watcher, auto-boot service, unrelated change, commit or push. See `docs/virtualization/waydroid-guide.md` and `docs/virtualization/waydroid.md`.

### Recovered Waydroid on NVIDIA 620 and added on-demand driver self-repair

- Diagnosed `waydroid-container.service` failure: NVIDIA `620.70.06` lacks the exact public ABI profile required by the prior `nvidia-prolapse` vendor image gated on `615.78.08`. The upstream `android/compute` gate refused the update (issue #41); no unsafe ABI bypass. Recovered via upstream `waydroid-nvidia-setup --mode venus --native-gl off --refresh 165`, restoring the official vendor image without touching userdata/Magisk. Verified Android boot complete, Sway window, Play Store/Kitsune Mask entries, NVIDIA RTX 5050 Venus/ANGLE Vulkan SurfaceFlinger and disabled-at-boot system/user services.
- Added `waydroid-driver-ensure` and integrated it into the managed `waydroid-launcher`: on-demand compatibility check, polkit-authorized same-mode repair, Venus fallback, lock to prevent concurrent setup, correct renderer selected after switching, and restoration of disabled-at-boot policy; no resident watcher. ShellCheck, healthy no-op check, source/live parity and subsystem lifecycle audit passed; future real driver-mismatch repair path is not yet tested. Detailed recovery and rollback: `docs/virtualization/waydroid-guide.md` and `docs/virtualization/waydroid.md`. No commits or pushes.

### Repaired stale Fuzzel entries and enabled Anger Foot LSFG 2x

- Removed the unowned `~/.local/share/applications/vesktop.desktop` pointing at removed `/usr/bin/vesktop` and only its matching `~/.cache/fuzzel` recency entry. Updated `discord://` handling to installed `discord.desktop`, synchronizing the live and chezmoi MIME map while preserving existing Codex/RAR preferences. Fixed the other visibly broken user-level launcher, `btop.desktop`, by switching from absent Alacritty to installed `footclient` (same `app_id=btop` Sway floating behavior). Confirmed no other missing top-level command in visible user/system application entries; preserved other apps and Waydroid exports. Source of truth: `dot_config/mimeapps.list`, `dot_local/share/applications/btop.desktop`.
- At the user's request, Anger Foot's Alt+G and desktop entries now explicitly include `nonsteam-run --lsfg 2x`, with MangoHud still disabled. Its game executable, existing Proton prefix, patched DLL and saved settings were untouched. LSFG profile validator and launcher dry-run passed; actual in-game frame generation has **not** been tested. Managed desktop source: `dot_local/share/applications/proton-anger-foot.desktop`; detailed docs: `docs/system/sway.md` and `docs/gaming/anger-foot.md`. No commit/push, packages, daemons or restart.

### Set MangoHud and LSFG 2x defaults for newly registered non-Steam games

- `proton-add-game` now passes `--mangohud --lsfg 2x` into new menu/desktop entries by default, with `--no-mangohud`, `--no-lsfg` and `--lsfg 3x|4x` overrides. This is a registration-time default only: direct `nonsteam-run` calls, Steam titles, existing custom registrations, Anger Foot's known presentation workaround and Elden Ring/Bloodborne special launchers are unchanged. ASUS Performance remains exclusively opt-in. Verified default, opt-out and 4x dry-run commands without starting a game or writing game files. Owner doc: `docs/gaming/nonsteam-run.md`.

### Audited and hardened unified non-Steam Proton runner and registration

- Fixed `nonsteam-run` self-matching `pgrep -f` guard (could prevent Proton launch) with prefix-scoped `flock`; removed dangerous prelaunch wineserver kills and automatic edits to game install `dxvk.conf`. Added managed read-only fallback, strict flag/runner/prefix validation, side-effect-free `--dry-run`, robust menu registration and stable title-prefix behavior. Kept `--perf`, MangoHud and LSFG opt-in; `--perf` now restores the previous actual ASUS profile; LSFG 2x/3x/4x now enables `LSFGVK_ENV=1` with its installed DLL. Existing special Bloodborne and Elden Ring launchers remain unmodified.
- Fake-Proton scenario tests verified argument preservation, opt-in environment, mode restoration and repeated safe desktop/menu registration with paths containing spaces. The Anger Foot executable, its different patched/backup DLL hashes, `compatdata/anger-foot`, `steam_appid.txt` 1978590 and fullscreen/DXVK files were inspected but not modified. A real Anger Foot rendered-title-screen test is still outstanding. Updated `docs/gaming/nonsteam-run.md` and affected game docs; no commit/push.

### Implemented universal nonsteam-run wrapper and refactored proton-add-game

- Replaced per-game standalone script generation in `~/.local/bin/` with a single universal launcher: `~/.local/bin/nonsteam-run`.
- Added granular CLI flags to `nonsteam-run`:
  - `-p, --perf`: ASUS Performance mode during gameplay, restoring Balanced on termination.
  - `-m, --mangohud`: attaches MangoHud telemetry overlay (`MANGOHUD=1`).
  - `-l, --lsfg <2x|3x|4x>`: Lossless Scaling frame generation multiplier (LSFG-VK).
  - Isolated prefix resolution, NVIDIA RTX 5050 Mobile dGPU offload, and safe DXVK defaults.
- Refactored `proton-add-game` to register titles directly into `~/.config/rofi/custom-games.list` via `nonsteam-run`, avoiding per-game executable script creation in `bin`.
- Removed legacy `anger-foot-run` and updated Anger Foot registration to use `nonsteam-run`.
- Added fish function `~/.config/fish/functions/nonsteam-run.fish`. Verified menu integration, argument handling, and documentation in `docs/gaming/nonsteam-run.md`.

### Restricted ASUS Performance power profile switching to Elden Ring

- Removed automatic `asusctl profile set Performance` invocation and trap restoration from `anger-foot-run`, `bloodborne-run`, and the `proton-add-game` template engine.
- Preserved hardware performance profile switching exclusively for `eldenring-lsfg` / `eldenring-launch-inner` per system gaming policy.
- Verified live: system remains on Balanced profile; updated owning documentation in `docs/gaming/anger-foot.md` and `docs/gaming/bloodborne-bbport.md`.

### Resolved Anger Foot black screen regression on launch

- Root-caused persistent startup black screen to three compounding factors:
  1. Unity `LogoScreen.IntroRoutine` WebM video preparation stall (`WaitUntil(() => _videoPlayer.isPrepared)` hung indefinitely due to missing container GStreamer codecs).
  2. Xwayland mode-switch stall triggered by `ExclusiveFullScreen` mode at 1.3x fractional scaling.
  3. Vulkan swapchain presentation stall caused by MangoHud layer hooking before FIFO swapchain establishment.
- Patched `LogoScreen.Start` in `Assembly-CSharp.dll` to directly invoke `LoadTitleScreen(3)` (`LoadingTransition.FadeFromBlackOnly`), cleanly bypassing the video hang. Pre-patch backup kept at `Assembly-CSharp.dll.bak`.
- Added `dxvk.conf` with `dxgi.allowFse = False` / `d3d11.enableExclusiveFullscreen = False` and set `"FullScreenMode": "FullScreenWindow,1"` in prefix `Settings.json`.
- Disabled MangoHud in `~/.local/bin/anger-foot-run` (`MANGOHUD=0`) and enforced `PROTON_ENABLE_NVAPI=0`.
- Verified live: game boots directly into 3D Title Screen on Sway Workspace 4 with full audio, 3D character/environment rendering, and responsive UI controls. Detailed in `docs/gaming/anger-foot.md`.

### Re-enabled REA MCP tools in Codex

- Restored the `mcp_servers.rea` stdio registration in the app-owned `~/.codex/config.toml` with command `/home/onyx/.local/bin/rea`, args `mcp`, 30 s startup and 450 s tool timeout. The registration had been absent since the 2026-10-26 disable; existing Codex settings were preserved and a timestamped pre-change config backup was kept.
- Verified with `codex mcp get rea` (enabled, stdio), `rea doctor --client codex --json` (`registration:codex` healthy), and a direct MCP `initialize` handshake returning `rea` 6.8.0. No native analysis engine (Ghidra, Hopper, IDA, JADX, Kuna) is installed, so engine-dependent operations remain unavailable. Restart Codex to load the server. Details in `docs/system/agent-control-plane.md`.

### Removed incompatible absolute USB tablet from running Nano11

- Confirmed QEMU had both PS/2 relative mouse and selected USB HID Tablet, a documented Looking Glass source of cursor misalignment/click offsets. Resolved tablet precisely to `/machine/peripheral-anon/device[0]` and hot-unplugged **only that device** using HMP `device_del`. Verified `info mice` shows exclusively active PS/2 Mouse, `info usb` shows no tablet, and guest remains running at 6 GiB with LGMP input.
- Removed `-device usb-tablet` from source/live `nano11` for future clean boots; retained USB XHCI controller and all existing guest/RDP/capture settings. No reboot or disk changes. Human pointer acceptance still required; details and rollback in `docs/virtualization/nano11-native-qemu.md`.

### Recovered Nano11 restart and verified running 6 GiB guest

- The requested `win restart` waited on Windows ACPI guest shutdown past the existing 120-second limit. The guest stopped, but no automatic relaunch occurred. Verified disk/process/unit state and started Nano11 once without force poweroff. Live QEMU PID 39649 reports 6 GiB and 12 vCPUs; the Looking Glass client received 1920x1200 frames and connected input/clipboard.
- Made normal `nano11 stop` / `restart` more tolerant of slow Windows exit: wait 180 rather than 120 seconds, emit periodic progress, and check the shutdown boundary again. No VM restart was used to test this revised code, so runtime acceptance remains pending.

### Unified Alt+W and Caps+Tab focus toggle

- Moved xremap global `Alt-w` from `rofi-windows open` to the existing one-shot `win-focus-toggle` action used by `CapsLock-Tab`. Both keys now navigate between the existing Windows workspace 5 and the previous Linux workspace without launching a stopped guest. Kept Caps+Esc for starting Windows, Alt+Shift+W for the menu, and other shortcuts. Updated the helper notification to point to Caps+Esc instead of Alt+W. Source/live xremap and helper parity, validator and service restart tested; physical chord acceptance remains user-side. No VM stop or restart.

### Restored original instant interactive controls; reduced Caps+Z/X vibrance latency

- Reverted native volume `volume-notify`, backlight/subzero `change-brightness`, and `wl-gammarelay` night-light `toggle-nightlight` / `adjust-nightlight` **byte-for-byte** to pre-smoothing backups and tracked Git HEAD. Existing Fn/Caps/gesture chords, native mute, OSD/game notification policy, backlight and gamma limits, and current user settings remain intact. The smoothing experiment below is historical, not currently active.
- Replaced the transient vibrance ramp with a direct native NVIDIA ioctl per Caps+X/Z press, using optimized integer-only Bash on the hotkey path, a short serialization lock, and nonblocking OSD; eliminated xremap's intermediate `/bin/sh -c` launch for those two keys. Exact NVIDIA 620.70.06 driver-match guard retained. Live six-step up/down test completed with 12.6–17.5 ms command latencies (median 13.2 ms) and restored the starting 85% raw 716 level. `smooth-control` is no longer used by any active control. Owner docs: `docs/system/interactive-control-smoothing.md`, `docs/display/nvidia-vibrance.md`, `docs/system/xremap.md`.

### Prepared Nano11 6 GiB allocation for next launch

- Changed only the Nano11 QEMU memory option `-m 4G` -> `-m 6G` in the chezmoi and live launcher. Existing guest PID was still running at 4 GiB and was not restarted, stopped or hotplugged. Kept all existing CPU, VFIO, IDD, startup and stop settings. Verified Bash syntax and source/live parity; next-launch memory confirmation pending.


### Smoothed interactive vibrance, night-light, brightness and volume controls

- Added `smooth-control`, a stdlib, short-lived per-domain ramp worker with atomic target updates and separate `flock` guards. Updated existing `nvibrant-ctl`, `change-brightness`, `volume-notify`, `toggle-nightlight` and `adjust-nightlight` launchers without rebinding any keys. Nominal smoothstep durations: vibrance 230 ms, brightness 190 ms, volume 160 ms, night light 280 ms. Direct mute and original OSD/workspace suppression remain instantaneous; no new service or compositor animation.
- Verified with NVIDIA 620.70.06 and active PipeWire/gamma relay: vibrance 614->716->614 plus rapid up/up/down/down coalescing; volume 100->95->100; hardware brightness 0->5->0 and below-zero gamma 1.00->0.95->1.00; night-light 4500->4600->4500 K. Original state restored. Fixed a notification AWK error caught in the first live vibrance test; isolated script backups retained at `~/.local/state/smooth-controls-backup-20261110/`. See `docs/system/interactive-control-smoothing.md`.

### Set up oguri animated wallpaper daemon and control tooling

- Installed `oguri-git r116.8b47791-1` from AUR (Snapper snapshot 474/475 created) providing `/usr/bin/oguri`, `/usr/bin/ogurictl`, and `/usr/bin/oguri-swaybg`. Added `oguri-git` to `packages/aur-explicit.txt`.
- Configured chezmoi template `dot_config/oguri/config` with strict key=value syntax (no surrounding spaces around `=`). Provisioned sample animation asset `~/.local/share/oguri/oguri-cap.gif`.
- Added on-demand systemd user service `oguri.service` (disabled by default to honor zero-idle CPU principles for competitive gaming) and management helper `dot_local/bin/executable_oguri-wallpaper` with fish completions.
- Verified daemon startup, IPC socket creation (`/run/user/1000/oguri`), dynamic `ogurictl output` updates, toggle lifecycle, and clean return to Sway's underlying static wallpaper upon daemon stop. Created reference guide `docs/display/oguri.md`.


### Added local Dusk Linux painted/minimal wallpapers without replacing theme defaults

- Reviewed the 1,507-image `dusklinux/images` gallery and manually selected 25 artistic/minimal images (14 dark, 11 light), using pinned source revision and per-image SHA-256 metadata. Downloaded/normalized them locally to ~11.8 MiB WebP under `~/.local/share/theme/wallpapers/dusklinux/`; image binaries are **not** tracked because the upstream repo has no license/artist attribution.
- Added the managed metadata, explicit `theme-curated-art-fetch --fetch` restore helper, local color/style matcher, and small `theme-set` / `theme-wallpaper` adapters. Existing Omarchy images remain first and default, while up to three curated options are added per eligible theme. In the 339-theme test, 327 had three supplementary options and all 12 deliberately solid palettes stayed solid. Tested 25/25 local assets, all theme preflights, selection priority and read-only no-network cycling; verified current `windows-dark-mode` wallpaper was not changed. No daemon, startup downloader, commit or push. See `docs/theme/dusklinux-curated-artwork.md`.

### Retired unstable Windows 10 X-Lite; preserved clean-ISO rebuild knowledge

- At user's explicit request, the isolated X-Lite/Micro10 VM was permanently removed after confirming both QEMU guests stopped, no X-Lite disk writer or mount, valid single-image backing chain and five QCOW2 internal snapshots. Unique tracked job `retire-xlite-vm-20261110-retry1.service` finished successfully (exit 0), deleting only `/mnt/Games/VirtualMachines/xlite-micro10/` (~23 GiB). Nano11 and its separate backup were verified present and left untouched; no force-stop, host GPU rebind or host reboot.
- Condensed successful setup procedures and repeated Looking Glass/idle 7–11-core runaway CPU findings into one reusable guide `docs/virtualization/windows-vm-rebuild-guide.md`. Removed old specialized X-Lite launcher, desktop entry, guest-only scripts, outdated dedicated docs and state; retained general Nano11 controls.
- Switched shared `windows-backend`, `rofi-windows`, `win-focus-toggle`, native Fish `win`/completions and Sway window assignment to Nano11-only. `win 10` now rejects explicitly; existing on-demand `win`, Alt+W, Caps+Esc, Caps+Tab, Windows menu, RDP/restart and emergency controls preserved. Source/live syntax, menu and source parity validated without starting Nano11. No commit/push.


### Windows tools optical fallback and unified Caps+Esc / Alt+W actions

- Verified live QEMU had attached the read-only `WIN10TOOLS` USB storage image; Windows Explorer nevertheless showed only C:. The underlying USBSTOR/automount problem is unresolved. A readonly SATA hard disk was rejected and SATA optical hotplug was unsupported; the unattached HMP block backend was cleaned up. Created a verified ISO9660 optical image containing `OPTIMIZE.PS1` and changed opt-in `WIN10LAB_TOOLS=1` future boots to use a read-only AHCI SATA CD-ROM at port 2. QEMU startup smoke test and Bash/ShellCheck passed. No guest reboot or data modification; next-boot Windows enumeration is not yet verified. The debloat script remains unexecuted.
- Added global xremap `CapsLock-Esc` and `Alt-w` actions pointing to the same existing `rofi-windows open` helper; removed duplicate Sway plain Alt+W binding. Bare CapsLock→Escape, Caps+Tab Linux/Windows toggle, Alt+Shift+W menu and all other Windows/Super mappings remain intact. xremap and Sway validation passed; physical chord tests are still required. Backups are in `~/.local/state/win-caps-esc-20261110/`. Owning docs: `docs/virtualization/win10-xlite-experiment.md`, `docs/system/xremap.md`, `docs/system/sway.md`. No commit/push.

### Contained Windows 10 IDD/CPU stall and staged reversible guest optimization

- Windows 10 X-Lite's Looking Glass producer failed after 21m55s, LGMP input/clipboard sessions were lost, and the guest's QEMU PID 149949 used 4.97 host CPU cores with package temperature about 86–88°C. Sent HMP `stop` to preserve memory/disk and eliminate QEMU CPU consumption, then used the existing guarded paused-VM `win10lab stop` via tracked `win10-graceful-recovery-20261110-012441.service`. The guest exited cleanly (0) without force-poweroff. Offline `qemu-img check -q` passed (tracked `win10-offline-qcow-check-20261110-012619.service`); transient monitor/TPM/SPICE sockets were gone. Other host loads were preserved. This is a safe recovery, **not** a permanent fix for the repeated X-Lite IDD/0x101 issue.
- Prepared but **did not run** Windows `Optimize-Guest.ps1` (read-only audit by default; backed-up service/task/registry changes on explicit apply; restore supported). The separate read-only `WIN10TOOLS` FAT16 media holds the script and only appears on an opt-in `WIN10LAB_TOOLS=1` boot. Normal VM boots remain free of extra USB devices, and no Microsoft Store/AppX, graphics, security, networking or Power BI prerequisites were changed. QEMU media options, Bash/ShellCheck and source/live parity were checked; PowerShell guest execution has not been tested.
- The physical Caps+Tab still failed with the earlier F23 workaround. Verified `xremap.service` lacked `SWAYSOCK`; updated the on-demand focus helper to resolve the active Sway socket, restored direct xremap launch and added inhibited `Alt+Ctrl+Tab` fallback. Helper testing with missing socket environment, xremap and Sway validation, and service restart passed. Physical chord acceptance still pending. Owning docs: `docs/virtualization/win10-xlite-experiment.md`, `docs/system/xremap.md`, `docs/system/sway.md`; no commit/push.

### Earlier F23 Caps+Tab trial (superseded 2026-11-10)

- Replaced xremap's direct `CapsLock-Tab` launch with reserved `F23`, bound in Sway as `--inhibited --no-repeat F23` to the existing on-demand `win-focus-toggle` helper. This moves focus switching into the compositor's shortcut-inhibition-aware binding path for both selectable Windows VM backends; no xremap daemon, VM setting, Right Ctrl behavior or guest input configuration was changed.
- Verified xremap config, `sway-check` (0 warnings), source/live parity and Sway reload. With X-Lite running and its Looking Glass window focused, Wayland-injected F23 toggled Windows workspace 5 → Linux workspace 2; the reverse 2 → 5 → 2 also passed. Physical Caps+Tab and Nano11 input acceptance remain to be confirmed by the user. Backups: `~/.local/state/win-caps-tab-20261110/`; documented in `docs/system/xremap.md` and `docs/system/sway.md`. No commit/push.

### Native Discord voice works over Jio USB

- Installed official `discord 1:1.0.168-1` after a root Snapper snapshot and added it to the gaming package manifest. The native client showed Voice Connected in LEGENDS/Gaming with Wi-Fi disconnected; Discord-owned UDP port 57674 to 104.29.139.89:19301 was [ASSURED]. No VPN or persistent Discord service.
- Brave/Vesktop still failed WebRTC ICE/DTLS; this is a verified working native-client workaround, not a fully diagnosed browser root cause. Live MTU 1500 is temporary, the saved MTU 1372 unchanged. See `docs/system/discord-jio-voice.md`.
- Corrected stale WARP installed-state docs after verifying complete package/service removal. Preserved unrelated uncommitted edits; no commit/push.

## 2026-11-09

### Fixed mpv visibility and ChatGPT scratchpad & border handling

- Configured Sway window rules in `30-window-rules.conf` for media players (`mpv`, `vlc`, `celluloid`, `totem`, `amberol`): players open tiled in tabbed view (`floating disable, layout tabbed, focus`). Added fish function `~/.config/fish/functions/mpv.fish` that automatically dismisses `scratch-term` upon launching `mpv` so the dropdown scratchpad never obscures the tabbed video window beneath it. Verified `mpv` active in Workspace 2 tabbed container alongside Brave and ChatGPT.
- Added explicit Sway rules assigning `chatgpt` to workspace 2 (`floating disable, border pixel 2, layout tabbed`), resolving missing borders caused by client-side decorations (CSD).
- Added `chatgpt`, `mpv`, `vlc`, `celluloid` to `PROTECTED` in `~/.local/bin/scratch-utility-toggle` so `Win+Shift+-` cannot accidentally banish them to the utility scratchpad queue. Updated `chatgpt-focus` to discover both tiled and floating instances. Applied via chezmoi and reloaded Sway with `sway-safe-reload`. No commit or push.

### Installed signed AeroFTP 4.2.7 on CachyOS

- Installed `aeroftp-bin 4.2.7-1` from the upstream-maintained AUR package after reviewing its PKGBUILD. Upstream release SHA-256 and Sigstore verified, and desktop/MIME/icon registration completed. Installed WebKitGTK 4.1 and the package's other missing dependencies without upgrades or removals; Snapper package hooks created root snapshot pairs 458/459 and 460/461.
- Added `aeroftp-bin` to the chezmoi AUR manifest and `docs/system/aeroftp.md`. `/usr/bin/aeroftp` and `aeroftp-cli --version` were verified; on-demand service audit had zero outstanding findings. The graphical window and Google Drive OAuth sign-in were not yet tested. No new daemon, commit, or push.

## 2026-11-08

### Restored NVIDIA digital vibrance after 620.70.06 driver upgrade

- `nvibrant-bin 1.3.0` lacked matching NVIDIA 620.70.06 NVKMS structure layout and its 615 fallback failed `AllocDevice ioctl`, breaking Caps+X/Z despite valid xremap mappings. Built a pinned upstream `nvibrant` executable against the installed 620.70.06 NVIDIA DKMS headers and installed a user-scoped versioned binary, with managed `nvibrant-current` exact-driver enforcement and `nvibrant-build-local` rebuild helper. The repaired `apply-vibrance` reports failures, and managed `nvibrant-ctl` applies before saving and no longer claims success for a failed ioctl or writes when inspecting.
- Verified NVIDIA 620.70.06 on RTX 5050 AsusMuxDgpu: connected DP connector 2 returned `Set vibrance (614) Success`; startup applicator passed; the Caps+X/+Z command path completed 70%/65% round trip while preserving original 614; xremap was active and its watched portable `$HOME`-based bindings validated. No driver downgrade, system package replacement, compositor restart, daemon, commit or push. Physical keypress acceptance remains separate. See `docs/display/nvidia-vibrance.md` and `docs/system/xremap.md`.

### Added persistent `win switch 10|11` wrapper for the entire Windows desktop

- Introduced `~/.local/bin/windows-backend` (`dot_local/bin/executable_windows-backend`) as a single persistent, no-daemon selector. `win switch 10|11` gracefully stops the other running VM, verifies exit, stores the new preference atomically, then opens that VM on workspace 5. `win select 10|11` changes preference only if safe; `win current` reads selected/active/effective backend. Active VM takes precedence, both-active conflicts fail closed, default is 11 until changed; `~/.local/state/windows/selected` is private.
- The same selection now drives Fuzzel/Rofi `rofi-windows`, `Alt+W`, `Super+Alt+W`, `Super+Ctrl+5`, unprefixed Fish `win` actions and global `CapsLock+Tab`; no xremap mapping changed. Explicit per-guest commands remain available for recovery.
- With both guests stopped, verified selecting 10 affected Fish status and Fuzzel menu routing, then restored 11 and confirmed private state persisted. A mocked Fish round-trip passed stop11 → launch10 → stop10 → launch11; injected failed stop preserved state and did not launch. Added bounded cleanup of stale Nano11 LG/RDP windows and KVMFR ownership after verified shutdown. Bash/ShellCheck, Fish syntax, Sway validation/reload and source/live checks passed. No real guest was started, stopped or reset as part of the selector test; an actual transition remains untested. Preserved existing source changes and VM disks; no commit or push.

### Switched shared Windows controls to native Nano11, preserving X-Lite

- Switched the default behind `Alt+W`, `Super+Ctrl+5`, `Alt+Shift+W` Fuzzel menu and native Fish `win` from X-Lite to the existing Nano11 guest. Nano11's Looking Glass and RDP now use **workspace 5**; xremap `CapsLock+Tab` is unchanged but its helper recognizes either running VM. Nano11 client explicitly uses Right Ctrl, capture-on-focus, keyboard grab, Windows-key forwarding, visible alerts and Sway shortcut inhibition. `win 10 ...` and both separate disks/UEFI/TPM states are preserved.
- Added `nano11 force-stop [--now]` so the existing menu's emergency stop continues to work with Nano11, using a lifecycle lock, exact disk-verified PID, HMP `quit` and same-PID SIGTERM fallback; normal ACPI stop remains separate. Interactive CLI still requires `FORCE POWER OFF`, while the menu uses explicit `--now`. Bash/ShellCheck and invalid-argument refusal passed. **No real Nano11 emergency powercut was executed.**
- Verified live/source parity, Fish syntax, `sway-check` (0 warnings), Sway reload, five generic icon menu entries, native Nano11 QEMU PID `323585` (12 vCPU/4 GiB), Intel PF on `i915`/VF on `vfio-pci`, and X-Lite stopped. Looking Glass produced Windows 11 build 26200 1920x1200 BGRA frames with LGMP input/clipboard and SPICE audio; Caps+Tab helper completed **5 → 2 → 5** with Nano11 focused.
- Separate host issue discovered: loaded NVIDIA module **615.78.08** versus installed NVIDIA userspace **620.70.06**, with NVML mismatch and Looking Glass EGL falling back to llvmpipe (~1.6 host CPU cores). No reboot/driver change attempted. Physical keyboard acceptance and real emergency-stop validation remain outstanding. Backups: `~/.local/state/windows-backend-switch-20261108/`. Details: `docs/virtualization/nano11-native-qemu.md`, `docs/system/sway.md`, `docs/system/xremap.md`, `docs/system/terminal-shell.md`.

## 2026-11-07

### Made Windows emergency stop one click; staged isolated idle-timer test

- At the user's explicit direction, changed the **Force Stop Windows** menu entry to call `win10lab force-stop --now` directly, without a second terminal/prompt. Preserved the backend's lifecycle lock, QCOW2-verified process ownership, HMP quit and verified-PID SIGTERM fallback; the direct CLI without `--now` remains confirmation-gated and normal `win stop` stays graceful. **Live-verified:** hard-stopped paused X-Lite PID 149709; QEMU exited, Nano11 stayed stopped, and the offline QCOW2 integrity check passed. Guest unsaved data was not guaranteed preserved.
- Examined earlier guest 0x101 CLOCK_WATCHDOG_TIMEOUT (minidump) and separate UMDF/Looking Glass System 10110/10111 failures. An `hv-relaxed` idle run still lost source at 25m46s; later run lost LGMP after 15m15s with QEMU using 10.89 host cores. As a **next-boot A/B hypothesis, not a verified repair**, changed only X-Lite QEMU `-machine` to `hpet=off`, matching one timer attribute of the known-working Nano11 VM. Backed up the launcher and created stopped-QCOW2 snapshot `before-hpet-off-20261107`; diskless KVM probe, Bash/ShellCheck and live/source parity passed. No Windows boot was performed under this setting because host package temperature was ~90 C with unrelated Playwright CPU load. Work remains blocked on safe 30-minute idle/driver acceptance, not on the menu implementation. Details: `docs/virtualization/win10-xlite-experiment.md`.

### Previous confirmation-gated Windows VM force-stop menu entry (superseded later on 2026-11-07)

- Added a fifth icon-backed **Force Stop Windows** action to the existing generic Fuzzel/Rofi Windows menu, without changing its normal Stop/Restart/Open/FPS wiring, Sway bindings, Nano11 or the guest. When X-Lite is running, the new action launches a one-shot Foot terminal outside fullscreen guest workspace 5 (when applicable) to invoke the pre-existing `win10lab force-stop` confirmation. The user must type `FORCE POWER OFF` before its locked, verified-QEMU-PID monitor-quit/SIGTERM path runs; it never auto-escalates `win stop` or sends SIGKILL.
- Verified Bash/ShellCheck, exact five icon/text rows rendered without a VM startup, and chezmoi/live launcher parity. Both guests were stopped; no actual hard kill occurred. The host nevertheless reached 96 C and ~5700 RPM fan; a two-second measurement attributed ~1.0 CPU core to an active Playwright Chromium test and ~0.8 core to a Brave renderer. Thus, this current thermal event was independent of QEMU, while prior guest clock/IDD CPU-runaway episodes remain unresolved. Backups: `~/.local/state/win10lab/menu-force-stop-20261107/`; runbook: `docs/virtualization/win10-xlite-experiment.md`.

### Reviewed full chezmoi worktree for publication; privileged upgrade deferred

- Audited 93 modified tracked files, four legacy file deletions, and 89 new files (approximately 475 KB), including workstation, theme, audio, virtualization, keyboard, tooling, package-manifest, and documentation changes. Gitleaks working-tree scan found **zero** secrets; JSON/TOML/Python/Fish/Bash/XML/YAML parsing found **zero** errors; Sway validation reported zero failures/warnings and `theme-set --check-all` passed 339 themes. Initial `origin/master` matched local base revision `6473e84`.
- Snapper `root` and `home` configurations exist, but Desktop Commander rejected the requested privileged `sudo snapper create` commands. No baseline snapshot was created and no `pacman -Syu`/AUR upgrade was started without that protection. The Btrfs filesystem had approximately 21 GiB free (86% used), with 8.6 GiB in the pacman cache. Existing snapshots, caches, VM disks, and resident services were left intact. The update remains pending a permitted privileged execution path.

### Added Caps+Tab Windows/Linux workspace focus toggle

- Following user's confirmation that Right Ctrl capture release and guest Windows/Super keys work, added a **global** xremap `CapsLock-Tab` chord that executes the one-shot `win-focus-toggle` helper. It switches to existing Looking Glass workspace 5 or Sway's previous Linux workspace; no new daemon, state file, guest launch, restart or change to working Sway shortcuts.
- `xremap --validate-config`, Bash/ShellCheck and source/live parity passed. Direct helper round-trip **2 → 5 (Looking Glass focused) → 2** passed on the running X-Lite guest without changing the QEMU PID. Physical chord acceptance remains to be tested. Backup and details: `docs/system/xremap.md`, `docs/system/sway.md`, `docs/virtualization/win10-xlite-experiment.md`.

### Calmed Sway tab/title colors for all themes; fixed Rebecca and Moonlight

- Found 6 of 339 themes with below-4.5:1 selected-tab text contrast. Rebecca used strong purple as a full-width tab surface and Moonlight inherited neon-pink text from a syntax-oriented alias; Gold Rush and other themes could also make noisy tab backgrounds. Derive restrained Sway-only selected/inactive surfaces from each `BASE00`, choose selected title `BASE05` and muted, dimmed `BASE05` for inactive title labels (instead of color-noisy imported grey aliases), and enforce 4.5:1 selected/inactive/urgent title contrast. Preserve authored accent on narrow focus border and all application palettes.
- Updated theme source generator, live engine, Sway and swaybar templates, generated reload-safe rules; a same-theme apply generated the new files but lacked the remote Sway socket, so a bounded 11-command IPC batch under the theme lock finalized the live Sway colors without changing current selection. `theme-set --check-all` and independent contrast sweep passed **339/339**, Sway bar runtime values match, and `sway-check` passed 0 errors/warnings. See `docs/theme/theme-implementation.md`.

### Made one-wallpaper and solid wallpaper shortcuts silent no-ops

- `theme-wallpaper next`/`prev`/`random` now exit without network discovery, downloads, notification or redundant `wset` when the theme is solid-only, one valid cached image, or has no cache and zero/one declared candidate. Existing multi-wallpaper cycling and manual fetch/refresh remain unchanged; shortcut chords untouched.
- Mock-tested hotkey paths for all three commands and live-tested one-image `dhv-magellan` and solid-only `snazzy` without state changes. Chezmoi/live helper parity and syntax verified. See `docs/theme/wallpaper-library.md`.

### Added 12 curated solid-background themes to the picker

- Compared 327 existing picker themes with published Tinted Theming Base16 palettes; added 12 uniquely named managed custom sources: Catppuccin Frappé/Macchiato, Ayu Mirage, GitHub Dark Dimmed/Light High Contrast, PaperColor Light, Edge Light, Moonlight, Rebecca, Snazzy, Zenbones, and Woodland. Source URLs and a pinned upstream commit plus YAML hashes are embedded in each source JSON. No existing theme was removed.
- Added explicit `assets.background_mode="solid"` handling before wallpaper donor matching; new themes never request donor image downloads and use their own base background color. Existing themes' wallpaper resolution remains unchanged. Verified all 12 palette preflights, foreground contrast, live/chezmoi source parity, and generated preview assets; picker now exposes 339 themes (previously 327) and `theme-sync` second run is a no-op. Preserved the active theme, with no service/install/restart, commit or push. See `docs/theme/curated-solid-palettes.md` and `docs/theme/wallpaper-library.md`.

### Restored Looking Glass Right Ctrl capture-state alerts

- Diagnosed missing green Capture Enabled/Disabled text: X-Lite launcher passed `win:alerts=no`, suppressing Looking Glass on-screen alerts. Changed only this option to `win:alerts=yes`; preserved Right Ctrl, capture-on-focus, Sway inhibition, working Windows/Super shortcuts and xremap.
- Bash/ShellCheck, source/live parity and client-only reconnect passed. QEMU PID 38249 was unchanged; Looking Glass client PID 43915 received 1920x1200 LGMP video/input on workspace 5. Physical Right Ctrl tap-to-toggle remains pending user acceptance. No VM/host reset, commit or push. Runbook: `docs/virtualization/win10-xlite-experiment.md`.

### Fixed recurrent rounded Yazi indicators after theme switching

- Diagnosed the rounded selection/status bars as a **live-template drift**, not the Yazi border plugin: `~/.config/theme/templates/yazi.toml` still held the older rounded glyphs, even though chezmoi's generator already defined square indicators. Added explicit square tab separators in the source, synchronized the live generator with a `/tmp` backup, then re-rendered the already-selected `all-hallows-eve` theme through `theme-set`.
- Verified source/live generator parity, valid TOML, `[indicator].padding` square `▐`/`▌`, empty `[tabs]` and `[status]` separators, and absence of rounded Powerline glyphs in the regenerated live theme. Yazi wasn't running; the next launch picks up these settings. The separate Foot server hot-reload fix remains installed, verified in its own entry below. No services, restarts, commits or pushes.

### Fixed Foot server theme hot reload and reduced mixed dark/light repaint

- `theme-set` previously tried to reach live Foot terminals through `footclient` child processes; those IPC clients have none. Now discovers the actual slave PTYs of immediate `foot --server` children and delivers the full OSC foreground/background/cursor/selection/16-color payload to existing windows **before** Neovim's color redraw, without restarting Foot or resetting TUI content.
- Verified live Foot `/dev/pts/0` and `/dev/pts/1` discovery and 2/2 OSC payload delivery for the current theme. Mocked all 21 palette commands and absence of screen-clearing controls; Python parse, source/live parity and targeted diff validation passed. Preserved the user's active theme; a global light/dark test was skipped because the theme changed during setup. Explicit app-painted truecolor cells remain outside terminal-level reload control. See `docs/system/foot.md` and `docs/theme/theme-implementation.md`.

### Repaired X-Lite workspace-5 input capture and guest Windows-key forwarding

- Changed only X-Lite's Sway window rule to honor its shortcuts inhibitor, and Looking Glass to forward Windows/Super keys to the guest. Its existing capture-on-start/focus and Right Ctrl release settings are preserved, without `autoCapture` re-grabbing after a manual release.
- Changed host Super+number (`1..0`) and Super+`u/i/o/p` workspace shortcuts to respect *active* keyboard inhibitors; this also affects captured games/remote sessions. Protected `Alt+Shift+W`, `Alt+W` and `Super+Ctrl+5` host recovery shortcuts remain intact. Global xremap, VM disks, GPU topology and Nano11 are unchanged.
- Installed exact source/live updates, passed Bash/ShellCheck and headless Sway configuration validation, reloaded Sway 1.12 safely and passed `sway-check` with zero errors/warnings. A subsequent tracked, non-destructive Windows 10 startup confirmed a focused workspace-5 Looking Glass client receiving 1920x1200 frames and LGMP input, with `KEY_RIGHTCTRL` in its launch metadata. Early-boot QEMU measured 3.54 logical cores; longer-term idle behavior remains unverified. Physical Right Ctrl short-tap, auto capture on focus return and guest Windows-key delivery still require user acceptance. See `docs/virtualization/win10-xlite-experiment.md` and `docs/system/sway.md`.

### Offline Windows shutdown helper and confirmation-only force stop

- With X-Lite stopped, verified Windows NTFS clean/unhibernated and QCOW2 unowned; created internal rollback snapshot `pre-wstop-20261107`. Installed hash-verified `wstop.cmd` at `C:\Windows\wstop.cmd` via short-lived offline NTFS mount. Disconnected NBD and passed `qemu-img check`.
- Updated `win stop` ACPI fallback to invoke only `wstop` via QEMU Win+R, replacing full-command keystroke injection. Added separate `win force-stop`, gated by interactive `FORCE POWER OFF` confirmation, for QEMU quit / verified PID SIGTERM as a last resort; it is not automatic and risks guest data loss.
- Bash/ShellCheck, Fish syntax/completions, source/live parity and stopped-state tests passed. No guest boot or hard poweroff test was performed; Windows-side invocation remains unverified until next supervised running-VM stop. No Nano11 or service changes. See `docs/virtualization/win10-xlite-experiment.md` and `docs/system/terminal-shell.md`.

### Removed provider prefix from visible theme picker names

- The Rofi theme picker shows `everforest [ACTIVE]` instead of `omarchy-everforest [ACTIVE]` and strips the leading `omarchy-` for other prefixed labels. The internal row value and `ROFI_INFO` retain canonical theme IDs, protecting selection, metadata, delete and active-theme behavior. Verified the current 327-theme catalog contains no resulting label collisions; only the picker rendering changed, not theme data or caches. See `docs/theme/theme-implementation.md`.

### Simplified theme-picker labels without renaming theme IDs

- `rofi-theme` now hides the `omarchy-` prefix in visible list labels only, so `omarchy-everforest` appears as `everforest`. Canonical IDs, Rofi `info`, active markers, swatches, apply/delete paths, and preview identity remain unchanged. Verified all 327 picker rows and all 22 prefixed labels against the cache index; no name collisions. See `docs/theme/theme-implementation.md`.

### Restored clean Windows-only VM menu and paused-guest stop

- Replaced the version-heavy shared Fuzzel menu with four generic Windows entries and restored icon rendering via Gruvbox-Dark; no version names/high-CPU pause rows appear. The active guest remains selected automatically, with Nano11's separate launcher and keyboard chord preserved.
- Corrected `win stop` for an explicitly paused X-Lite VM: temporarily resume only to request graceful Windows ACPI/keyboard shutdown, then re-pause on timeout/error instead of forcing a reset. Removed the high-CPU jargon from the paused launcher prompt.
- **Live verified** `fish -c 'win stop'` against a paused QEMU guest: it exited, released monitor/TPM/Looking Glass, VF-related shared memory and QCOW2 owners, and passed offline `qemu-img check`. Bash/ShellCheck and source/live parity passed. No guest forced reset, VM replacement, GPU rebind, extra service, commit or push. Technical evidence and rollback: `docs/virtualization/win10-xlite-experiment.md`.

### Consolidated Windows VM commands in native Fish

- Added a lazy-loaded `win` Fish function with `win [10|11] start|stop|status|logs`, the shared `win menu`, Windows 10 client reconnect and Nano11 RDP/restart access, plus contextual Fish tab completions. `win` without arguments reports both guests. The underlying launchers retain their VF ownership, pause/restart and shutdown safeguards.
- Removed only the obsolete forwarding-only `nano11.fish` wrapper from live and chezmoi Fish directories. Kept the actual `nano11` and `win10lab` executables and preserved unrelated Fish configuration.
- Verified Fish syntax, live/source parity, completions, both read-only status paths and refused Windows 10 bare restart; no guest start/stop/reset, additional service, GPU change, staging or commit. Details: `docs/system/terminal-shell.md`.

### Added on-demand Super+Alt+G ChatGPT launcher

- Added a narrow Sway binding to `chatgpt-focus`: focus the existing native Wayland `app_id=chatgpt` window or launch the packaged `chatgpt` client using existing Wayland flags. No new resident service or global focus changes.
- Validated targeted Sway source/live parity and documented the keybinding in `docs/system/sway.md`; no changes to existing VM, gaming, or terminal chords.

### Made native Wayland the default for the ChatGPT desktop app

- Created chezmoi-managed `dot_config/chatgpt-flags.conf` and verified its live `~/.config/chatgpt-flags.conf` counterpart contains `--ozone-platform=wayland`; confirmed the running ChatGPT window is native `xdg_shell`.
- Removed the sole ChatGPT web favorite from `dot_config/rofi/favorites.list` and synced Fuzzel favorites. Verified the generated web entry is gone and the packaged `chatgpt.desktop` is the only matching application entry; all other favorites retained. No Sway reload, running-app restart, new daemon, or package changes. Details in `docs/system/sway.md`.

### Diagnosed X-Lite HPET overhead and clock-watchdog crashes

- KVM statistics/trace identified HPET emulation: 141,945 MMIO exits/0.503 s before reference-clock/synthetic-timer enlightenments, 5/0.501 s afterward. Four managed Windows shutdowns, resource release and offline QCOW2 checks passed; Intel hardware D3D11 and NAT DNS/IPv4/HTTPS remained functional. No guest hard reset/forced off, host GPU rebind/reboot or Nano11 installation change.
- A 30-minute host observation averaged 0.918 cores without LGMP loss, but subsequent clean acceptance failed in 99 s with a guest-internal restart. Backed-up small-dump/event logging exposed **0x101 CLOCK_WATCHDOG_TIMEOUT on vCPU 6**. Added only `hv-relaxed` for a new tracked USB-free idle/progress test; permanent stability is not claimed. Preserved paging/automatic restart and IDD compatibility/watchdog settings.
- Verified guest AC/DC monitor Never and corrected a diagnostic 1919 override to real 1920x1200@165. Normal LG mode omits USB tablet; basic VGA recovery retains it. Bidirectional clipboard passed while focused, silent PCM reached a running Looking Glass PipeWire output, and a motion sample showed 97.81 FPS/95.81 UPS (not sustained 165 unique frames). Physical capture/host keys/audible quality remain pending.
- Improved shared menu source/paused states, move-here, client-only reconnect, Nano11 FPS instructions, cached state, runtime media reporting and Win10 FPS metadata. Added bounded timestamped log rotation, paced shutdown and guest evidence/resolution/idle helpers. Six mocked menu states and shell checks passed. Detailed evidence, ongoing acceptance and rollback: `docs/virtualization/win10-xlite-experiment.md`; launcher UI: `docs/theme/theme-implementation.md`.

## 2026-11-07

### Yazi square styling and balanced three-pane layout

- Replaced Yazi's rounded `full-border` plugin corners with `ui.Border.PLAIN`; added Yazi 26.9.1 `[indicator].padding = { open = "▐", close = "▌" }` in the theme generator for square file hover/selection indicators, and removed rounded status caps using `[status].sep_left` / `sep_right` empty glyphs.
- Tuned the `yazi.toml` manager ratio from `[1,3,4]` to `[2,4,3]`, then to `[3,7,8]` (parent 16.7%, files 38.9%, preview 44.4%) after user feedback that the preview had become too narrow. The live and chezmoi files match and parse as TOML; Yazi must be reopened for the layout change.
- Synced live `~/.config/yazi/init.lua` and palette-managed `~/.local/state/theme/yazi.toml`, checking TOML syntax and source/live values. The open Yazi instance had exited before the update, so the next Yazi launch is needed for the Lua plugin change. No new plugin or service. See `docs/system/file-management.md` and `docs/theme/theme-implementation.md`.

## 2026-11-06

### Preserved paused X-Lite state and prevented queued shutdown input

- Verified QEMU 142061 paused, no LG client, zero CPU over three seconds; PF i915/VF vfio-pci/NVIDIA bindings unchanged. Compared Nano11 timer/CPU/input configuration without starting it. USB tablet and missing Hyper-V synthetic timers remain candidates, not diagnosed causes.
- Added/live-tested refusal of `win10lab stop` for non-running QEMU states, preventing shutdown keystrokes queued while paused. Syntax/ShellCheck, source/live parity and Sway validation passed; no guest resume/reset, disk edits or GPU rebinding.
- Hardened the prepared guest power helper to inspection by default, checked backup/restore and explicit monitor-only apply; added one-shot Windows event/process/interrupt collector. Installed host copies only; Windows runtime validation and 30-minute acceptance are blocked on explicit resume approval. Detailed evidence/rollback in `docs/virtualization/win10-xlite-experiment.md`.

### Hardened Sway window placement and remote validation

- Removed hardcoded `eDP-1` moves from Meetingly and `wl-mirror` rules; Meetingly remains floating with a 1px border and `wl-mirror` tiled/borderless on their launch output. No compositor display mode, scale, GPU mode, service policy, or unrelated window rule changed.
- Made `sway-check` and `sway-safe-reload` validate via headless/pixman rather than contending for the active DRM seat, with uniquely matched same-UID Sway IPC fallback for remote shells. Applied source/live counterparts; Bash syntax, source/live parity, headless validation and `sway-check` passed (0 failures/0 warnings). `sway-safe-reload --quiet` succeeded, preserving workspaces 1/2/5 and the active X-Lite QEMU service. Multi-output placement not tested; no commit/push.

### Windows 10 idle capture key repair and guest-side failure (partial)

- Restored `win10lab` default escape key from F12 to requested Right Ctrl; retained capture-on-focus and explicit held-key release on focus loss, without forced auto-capture, preserving F12 as an override. Added a client-only `reconnect-input` command and Windows menu action, with scripts installed and linted.
- Client-only reconnect failed because the Windows IDD guest source was unavailable despite a working SPICE connection. QEMU consumed ~6.98 logical CPU equivalents; one non-destructive HMP pause contained the load, without resetting the guest or touching host GPU bindings.
- Added a Windows PowerShell one-shot with a power-scheme backup, monitor/standby idle-timeout settings and readback verification. It is **staged, not executed**; physical Right Ctrl and idle-duration acceptance remain outstanding. Nano11 was preserved.

### Windows 10 IDD screenshot and persistent high guest CPU (diagnostic observation)

- User unchecked "Force full direct frame copies" in Looking Glass IDD B7-829 configuration, while "Force indirect copy" and LG-only-monitor remained checked with 1920x1200/165.0040 Hz. This is a screenshot-supported guest change, not agent modification; effective stability is not yet proven.
- Live read-only HMP showed Windows 10 had resumed from the previously documented pause. Client logged LGMP 1920x1200 frames and input/clipboard. QEMU still measured **3.19 logical CPU equivalents** over three seconds, so the runaway/idle CPU regression remains unresolved. No VM, Sway, VFIO, GPU, service or guest settings changed by this check.

### Windows 10 paused-state launcher and notification repair

- Corrected `win10lab status` to report the QEMU HMP paused state separately from a live PID. `Alt+W` / `win10lab workspace` now opens the existing recovery menu when paused, rather than focusing an unusable Looking Glass splash.
- Removed repeated source-lost notifications on each focus; paused-state entry now closes only the stale Linux Looking Glass splash before showing the recovery menu. Added two separately confirmed menu actions for paused guests: resume (may again saturate CPUs), or intentional guest hard reset (when paused, `system_reset` followed by `cont`). Neither executes automatically or on ordinary Alt+W.
- Validated shell syntax, ShellCheck, installed source/live parity and actual HMP `paused` and corresponding Fuzzel menu output; Windows QEMU remained paused without new guest resets, host GPU changes, resident daemons, disk alterations or Nano11 launch. Display/IDD failure remains unresolved; see virtualization runbook.

### Windows 10 guest vCPU spin paused to protect host (runtime incident)

- At ~21:53 IST the Windows 10 X-Lite guest remained frozen at Looking Glass splash. Seven QEMU guest vCPU threads measured roughly 97-100% each. LGMP session had been lost after ~17 minutes. Windows/IDD root cause unverified.
- Issued reversible HMP `stop` (pause), not an ACPI poweroff or hard reset; HMP reported `paused`, measured QEMU CPU dropped to zero over two seconds, and host CPU package fell from 77 C to 68 C. Its RAM/QCOW2/Intel VF remain owned, so the paused VM is not a replacement for a clean on-demand stop.
- No boot, GPU binding, VM hardware, packages, resident services or Nano11 changes. See the incident runbook before resuming or restarting, and keep prior unsaved guest work risk explicit.

### Verified Sway rules and synchronized X-Lite workspace references

- Read-only Sway audit: headless `sway -C` and `sway-check` passed with zero failures/warnings; 238 bindings had no identical mode/flag/chord collisions, and all 53 locally referenced helpers existed. Current Sway/chezmoi fragments match; the fullscreen X-Lite Looking Glass client is present on workspace 5 and the browser remains tiled on workspace 2. No compositor, helper, service or VM process was changed by this audit.
- Verified that `docs/system/sway.md` and `docs/system/SYSTEM_CONTEXT.md` now reflect the concurrent X-Lite workspace-5 update; historical workspace-9 evidence remains historical. The audit itself made no Sway configuration changes, and no commit or push was performed.

### Stabilized existing Windows 10 VM lifecycle and verified Intel D3D/NAT

- Independently verified Windows 10 Intel VF hardware D3D11 creation (8086:A78B, feature level 11.0), guest DNS/IPv4/HTTPS and live 1920x1200 LGMP capture, including after a clean QEMU relaunch; PF remains i915 and NVIDIA/Sway operational. Update endpoint responds, but guest-disabled BITS/wuauserv block Windows Update.
- Added serialized start/stop, isolation/ownership checks before VF rebind, safe TPM PID cleanup, mode validation, transient BASE propagation, runtime-file cleanup and complete HMP response handling. Replaced the failed IDD-only VNC shutdown fallback with tested paced HMP guest shutdown. Concurrent starts reused one PID, invalid mode failed safely, clean stop released resources and offline QCOW2 checks passed.
- A user-requested guest reset cleared repeated input; exact cause and physical keyboard/mouse/clipboard/audio acceptance remain unresolved. Measured IDD CPU about 25% of one vCPU with client / 12.5% without; no UMDF or driver removal. Another host cold boot was not tested. Added read-only JSON verification script; updated owning guide and marked older lab notes historical. Targeted chezmoi application hit a pre-existing duplicate nvim.desktop source; intended files installed directly with source/live parity. No commit/push. See `docs/virtualization/win10-xlite-experiment.md`.

### Fixed recurrent Elden Ring black screen by defaulting frame generation off

- Verified a running, visible, focused Elden Ring fullscreen window remained entirely black (>99.9% black captures) for minutes with the correct RandomizerCrashFix/DelayedModLoader/MapForGoblins profile, CameraFix/Pause loaded, and both FasterRevival and MangoHud absent. ModEngine log and game executable were present; the game ignored standard window close and was terminated individually, without save modifications.
- Controlled relaunch using `ENABLE_LSFG=0` / `DISABLE_LSFGVK=1` rendered changing compositor frames on workspace 4 (about 23% black; average per-channel frame difference 3.187) with identical game mods. LSFG-enabled presentation caused this session's hang, though its lower-level driver/present interaction remains unresolved; earlier 4x successes are historical.
- Normal `eldenring-lsfg` and Alt+G now default to stable no-LSFG; Alt+G retains an explicitly labeled experimental LSFG 4x choice (`ENABLE_LSFG=1`), with the shared LSFG-VK configuration and all mods, saves, Proton prefix, GPU configuration left intact. See `docs/gaming/elden-ring/README.md` and `wayland-troubleshooting-and-fixes.md`.

### Retired Cloudflare WARP startup and added on-demand service audits

- Found `cloudflare-warp-bin 2026.8.2115-1` running `warp-svc.service` continuously despite missing registration. Stopped and disabled system `warp-svc.service`; masked globally enabled user `warp-taskbar.service`. Confirmed both inactive afterward and USB-tethered route intact. The package is still installed: pre-removal Snapper via polkit required authentication, and that attempt was canceled; no package removal claim is made.
- Audited Waydroid (boot disabled, may run when invoked), Nano11/win10lab (transient QEMU), Syncthing (disabled between vault sync windows), and absent Podman/Docker/libvirt daemons. Left current guest sessions and needed Bluetooth, PipeWire, GPU and agent services untouched.
- Added read-only one-shot `system-residency-audit`, `docs/system/service-residency-policy.md` and an `AGENTS.md` check for future optional app/service installations. No watcher, new background daemon or DNS modification.

## 2026-11-06

### Isolated Windows X-Lite Micro10 experimental VM

- Extracted and verified the user-provided Windows X-Lite Micro10 SE archive, retained `/mnt/Games/VirtualMachines/xlite-micro10/media/xlite-micro10-19045.3757.iso` (SHA256 `b413bc20f04f543dbdf0127cf8ea519a65c8ed5e93692cf86334e4f6bd5d9837`), and deleted the source `.7z` as requested. WIM confirms Windows 10 Pro 22H2 build 19045.3757 and verified file data.
- Created a distinct offline QEMU test guest: `dot_local/bin/executable_win10lab` with separate 40 GiB sparse QCOW2, a SeaBIOS/standard VGA recovery display at loopback VNC 5912, `-nic none`, and transient systemd QEMU unit. Windows installed and booted; Task Manager measured **39 processes / 0.6 GiB of 3 GiB guest RAM** before graphics drivers. Saved `clean-xlite-pre-intel-vf` internal QCOW2 snapshot after a clean shutdown and passed `qemu-img check`.
- Probed Intel VF `0000:00:02.1` without changing host PF/NVIDIA or Nano11: attaching at cold boot produced black guest screen; hotplug into a dedicated QEMU PCIe root port **after guest desktop boot** succeeded without losing standard VGA. Prepared separate FAT driver media with known Intel 32.0.101.7092 and matched Looking Glass IDD installers. **Micro10 Intel WDDM/Direct3D and Looking Glass IDD remain unverified**; leave the VF optional and default to virtual VGA. Guest remains network-isolated because third-party ISO creates an empty-password admin.
- Added `docs/virtualization/win10-xlite-experiment.md` and updated system context/subsystem navigation. Left existing Nano11 Windows 11 disk, firmware, TPM, backup and launcher untouched. No commit/push.

### Verified Micro10 Intel driver and Looking Glass IDD capture

- Installed signed Intel `32.0.101.7092` driver-only INF in offline Windows 10, with PCI `8086:A78B` changing from **Code 28 to Code 0** in the guest; no test-signing bypass or host GPU binding changes.
- Installed matching Looking Glass IDD B7-829 with IVSHMEM, applied `ForceIndirectCopy=1` and nominal 1920x1200@165.004 modes, restarted IDD PnP successfully. Linux B7-829 client received actual **1920x1200 BGRA LGMP frames**, LGMP input/clipboard and SPICE audio channels.
- Verified a fresh VFIO-equipped VM cold boot followed by new Looking Glass frames; one client ran 35 seconds to deliberate timeout. Added and validated `win10lab glass` on-demand command and GPU-mode status. **One-command launch from a fully stopped VM** booted Windows 10, survived an initial IDD restart, received 1920x1200 LGMP frames and ran until a deliberate 40-second client timeout with QEMU still running. Three internal Micro10 snapshots are preserved (`clean-xlite-pre-intel-vf`, `intel-7092-code0`, `intel7092-idd-b7-1920x1200`). Default plain `win10lab start` remains no-VF recovery mode; no permanent service or guest networking was added.
- Verified a robust graceful stop path for the stripped guest: ACPI power button was ignored, so `win10lab stop` invoked the new source-managed local VNC keyboard helper to issue Windows `shutdown /s /t 0`, without killing QEMU. The transient unit then exited normally; VNC listener disappeared and `qemu-img check -q` passed. No resident helper or guest network was introduced.
- Fixed invisible Windows 10 application windows in Looking Glass. The guest had two active virtual displays: 1024x768 VGA was Windows primary, while 1920x1200 IDD was secondary. The Windows projection API did not fix the default. Tested a clean restart with `-vga none` only in the VFIO/IDD mode: Windows Settings and Task Manager became visible inside Looking Glass. `win10lab glass` now defaults to IDD-only; normal `win10lab start` keeps the VGA recovery path. No Nano11 changes, host GPU rebinding, networking or idle daemon introduced.
- Still experimental: independent D3D11 creation, actual 165 UPS, audio/input latency, post-driver RAM/process baseline, and sustained unattended stability not tested; some shorter sessions ended with unexplained clean QEMU exits. See `docs/virtualization/win10-xlite-experiment.md`. Nano11 stays unchanged, separate and protected. No commit or push.

### Increased Micro10 to 4 GiB, restored Intel VF after reboot and added outbound NAT

- Updated source-managed `win10lab` and verified the live native QEMU process uses **4096 MiB** and an IPv4 user-mode NAT `e1000e` NIC without port forwards. Windows `ipconfig` showed guest address `10.0.2.15/24` and gateway `10.0.2.2`; independent DNS/HTTPS remained unverified. `WIN10LAB_NETWORK=0` still provides a deliberate offline boot, and a running VM rejects a conflicting requested network mode.
- Found Intel PF `00:02.0` still bound to i915 but `sriov_numvfs=0` after host reboot. Added an isolated and guarded VF recreation/binding helper; verified the Intel VF reappeared as `00:02.1` on `vfio-pci` in singleton IOMMU group 24. Nano11 and host NVIDIA were not touched.
- Guest audit identified Windows `WUDFHost` driver-host CPU as `lgidd.dll` (0.92–2.17 CPU seconds per six seconds) and a nonstandard 130-DPI scale. Preserved UMDF/IDD and 64 MiB KVMFR; did not arbitrarily disable necessary guest services or enlarge the shared buffer. Staged clock-seconds/DPI cleanup PS1 with registry backups, **not confirmed applied**, because guest UI automation was racing another active session. Updated `docs/virtualization/win10-xlite-experiment.md` with detailed all-in-one installer failure/rollback gates. No commit/push.

## 2026-11-05

### Migrated Nano11 from Dockur/Podman to native QEMU/KVM

- Replaced the rootless Dockur wrapper with an **on-demand QEMU 11.1.3/KVM** process in a transient `nano11-qemu.service` (`systemd-run --collect`, running as the regular user). Preserved the existing Intel SR-IOV VF on vfio-pci, 12 vCPUs, 4 GiB guest RAM, the secure OVMF/TPM identity, VirtIO-SCSI disk, **64 MiB KVMFR**, matched Looking Glass IDD/client, SPICE audio, and localhost RDP. The host NVIDIA/Sway display remains untouched.
- Investigated and fixed two migration blockers: Desktop Commander's 1.5 GiB memory cgroup OOM-killed an inherited QEMU; the transient systemd system unit avoids that limit. Missing Arch `qemu-hw-display-virtio-gpu` module made `virtio-vga` segfault; installed the core plugin. Selected non-GL VirtIO VGA fallback to avoid Dockur's known Intel `vulkaninfo` GPU hangs.
- Backed up the **stopped** VM disk plus firmware/TPM state to `/mnt/Games/VirtualMachines/nano11-backup-20261105/` and matched the QCOW2 SHA256. This is a separate copy on the same Games partition, not an off-machine backup.
- Verified shell/ShellCheck, package and source/live parity, clean Windows ACPI shutdown, restart/reuse and an actual **cold start after removing Podman**. The guest responded to RDP on `127.0.0.1:3389` and Looking Glass received genuine **1920x1200 LGMP frames** with LGMP input/clipboard and SPICE audio channel negotiation. No claims about sustained 165 UPS, audible audio or newly measured end-to-end latency.
- After successful migration removed the stopped Dockur container, both unused rootless images (~713 MiB), Podman and its 10 unneeded dependency packages, unused QEMU EGL/GL modules (~106 MiB packages removed overall), stale pause process and remaining container metadata. No container daemon or service is needed for Nano11.
- Reclaimed ~1.6 GiB on the Games partition by deleting only the unattached `shared/intel-driver.img` and SHA256-identical duplicate `shared/gfx.exe`, keeping `shared/gfx_win_101.7092.exe`, audit evidence, installed QCOW2 and backup. The `dockur-nano11/` directory name remains for stable paths; it no longer refers to a runtime dependency.
- Updated chezmoi `executable_nano11`, Windows menu, fish wrapper, desktop entry, `packages/development.txt`, `SYSTEM_CONTEXT.md`, virtualization subsystem map and current [Nano11 native QEMU runbook](../virtualization/nano11-native-qemu.md). Old Dockur documents are marked archival. **No commit or push was made.**

### Restored Ventoy graphical launch under Xwayland

- Ventoy's pkexec-elevated GTK3 process forces X11 while the live Xwayland access list permits only the desktop user. Added on-demand `ventoygui` wrapper to grant `SI:localuser:root` temporarily, run the existing polkit-authenticated `/usr/bin/ventoygui`, and revoke that grant on exit; added a managed user desktop override for reliable Fuzzel launch. No wide-open X permissions or bypass of authentication.
- Confirmed the GUI initialized and enumerated disks, then exited cleanly. The ACL returned to user-only; no USB was attached and no disk was modified. See `docs/system/file-management.md`.

### Completed isolated multi-window utility scratchpad queue

- Replaced the single-window utility scratchpad logic with a marked, ordered queue: `Win+-` toggle/last-viewed, `Win+Shift+-` explicit park, `Win+Ctrl+-` cycle, `Win+Ctrl+Shift+-` Fuzzel selection. `Win+Alt+-` continues to adjust UI scale; existing browser Workspace 2 rules and dedicated terminal/notes/Neovim scratchpads are untouched.
- Verified two live Zenity dialogs park independently, cycle one-at-a-time, restore the last viewed and hide again; the native `scratch-term` kept its original unmarked scratchpad state. No permanent daemon. `sway-check` and validated live reload passed. See `docs/system/sway.md`.

### Added Bloodborne (bbport Windows port) Proton stack and Alt+G launcher

- Set up Proton runner (`GE-Proton11-7-x86_64`) and dedicated prefix at `~/.local/share/Steam/steamapps/compatdata/bloodborne` for Supermedo's Bloodborne Windows port (`bbport`).
- Configured launcher metadata in `%APPDATA%\bbport-launcher\settings.json` and `bbport.ini` (`upscaler=dlss`, `output_res=1920x1080`, unlocked frame rate, fullscreen, and direct `game_dir` mapping).
- Resolved incomplete archive extraction by merging 481 audio/cutscene/parts files left in PeaZip temporary folder into `Bloodborne/game` and creating `/mnt/Games/NonSteamGames/Bloodborne` symlink.
- Created wrapper script `~/.local/bin/bloodborne-run` (source of truth: `dot_local/bin/executable_bloodborne-run`) managing GPU mode offloading, Sway Workspace 4 auto-focus, and Asus Performance power profile.
- Integrated `Bloodborne (bbport)` and `Bloodborne Settings (GUI)` into `~/.local/bin/rofi-games` (`Alt+G` menu) and documented the subsystem in `docs/gaming/bloodborne-bbport.md`.

### Enforced strict immunity for terminals and Neovim against utility scratchpad

- Hardened `scratch-utility-toggle` with a multi-layered immunity filter: dedicated scratchpads (`Ctrl+space` terminal `scratch-term`, `Win+n` Neovim notes `scratch-notes`, Spotify, Desktop Commander), all Foot terminals, and all Neovim editor instances (checked across `app_id`, `class`, `instance`, and window title patterns) are strictly immune.
- `scratch-utility-toggle` will never hide, summon, or hijack immune windows when toggled via `Win + -`.
- Updated `Win + Shift + -` / `Win + _` to route through `scratch-utility-toggle send`, preventing raw Sway scratchpad movement of immune windows and displaying a notification if an immune window is targeted.
- Verified live: terminal and `scratch-term` remained completely unmoved and hidden in their dedicated slots without interference. `sway-check` passed with 0 errors/warnings.

### Playback-aware Sway idle dimming and screen power

- `keep-awake` now sends dim/DPMS/idle-lock callbacks through on-demand `media-idle-action`, detecting real playback through MPRIS `Playing` and running PipeWire application streams. Audio/video playback defers the 2m dim and 5m power-off (or lock in non-keep-awake mode); once playback ends, deferred actions apply unless input resumed. Virtual DSP sinks do not count as playback.
- Manual `screen-black` keeps its immediate screen-off behavior and cancels pending watchers. No permanent service is introduced. Verified live Brave playback blocks dim and DPMS, watcher cancel/end logic, Sway idle service arguments and script syntax.

### Restored Thunar fullscreen tiling and preserved floating extraction dialogs

- Diagnosed window management behavior where Thunar main windows opened as fixed 1180x720 floating windows centered over background applications instead of taking the full screen workspace.
- Removed forced floating rules for `app_id="(?i)^thunar$"` in `dot_config/sway/config.d/30-window-rules.conf` and `~/.config/sway/config.d/30-window-rules.conf`, restoring default tabbed/tiled fullscreen presentation for main Thunar file manager windows.
- Preserved floating centered presentation for archive extraction and file management dialogs (`peazip`, file progress, rename, preferences, properties, and confirmation prompts).
- Restored `$mod+e` keybinding in `dot_config/sway/config.d/40-keybindings.conf` to launch regular tiled Thunar (`exec thunar ~`).
- Verified via `sway-check` (0 errors, 0 warnings) and reloaded live compositor configuration via `sway-safe-reload`.

### Fixed Thunar breadcrumb button text invisibility under active themes

- Diagnosed invisible text on checked breadcrumb buttons in Thunar's location bar (`ThunarLocationButtons`): `dot_config/theme/templates/gtk.css` assigned `color: {{accent}}` against `background-color: {{one_bg2}}`. In themes where `one_bg2` is mapped to the accent color (such as `windows-dark-mode` where both are `#0078d4`), the foreground matched the background identically, resulting in a solid blue block with illegible text.
- Updated `dot_config/theme/templates/gtk.css` and live `~/.config/theme/templates/gtk.css` to explicitly enforce `color: {{white}}` for `.thunar .location-bar button:checked`, `:active`, and their nested `label` nodes, aligning them with the rest of the file view selection styles.
- Recompiled and applied the theme via `theme-set windows-dark-mode`.
- Verified live across Thunar mount points and subfolders: path buttons render crisp white text over the accent background when active/checked. `sway-check` passed with 0 errors/warnings.

### Restored Elden Ring rendering by synchronizing its parked-mod profile

- Found that `~/.config/eldenring/config_randomizer_stack.toml` and the ModEngine copy still injected the known-incompatible FasterRevival DLL, even though the chezmoi source omitted it. Reapplied only the corrected source profile and matching `mod_loader_config.ini`; ModEngine now injects RandomizerCrashFix, DelayedModLoader and MapForGoblins, while FasterRevival stays installed but parked.
- Verified the regular non-Steam launcher spawned `eldenring.exe` and LSFG 4x/Performance Mode, then rendered distinct changing fullscreen frames while focused on Sway workspace 4. Synced the stale 2x menu/notification labels from their already-correct source. No commits/pushes, unrelated mods or MCP changes.
- Unrelated duplicate `nvim.desktop` source/template blocked `chezmoi apply`; changes were applied directly to the diff-verified Elden Ring targets with temporary backups. This unrelated source collision remains to be addressed separately.

### Fixed Foot terminal link navigation and headless Neovim launches

- Diagnosed link navigation failure when activating Foot URL jump mode (`Alt+o`): `xdg-open` generic handler ignored `Terminal=true` on `nvim.desktop`, causing clicked file links (`file://...`) to spawn headless, windowless Neovim background processes without an allocated TTY.
- Created `~/.local/share/applications/nvim.desktop` (`dot_local/share/applications/nvim.desktop`) with `Exec=footclient nvim %F` and `Terminal=false`, ensuring `xdg-open` immediately routes file opening through a visible Foot client.
- Implemented `foot-url-launch` (`~/.local/bin/foot-url-launch` / `dot_local/bin/executable_foot-url-launch`) to handle URL schemes, query strings, `#L` line numbers, media formats, and code/text editing in `footclient`.
- Updated `dot_config/foot/foot.ini` and `~/.config/foot/foot.ini` to use `launch=foot-url-launch ${url}`.
- Documented in `docs/system/foot.md`. Verified live: clicking link hints immediately maps a Foot window running Neovim on the target file.

### Resolved GridCraft UI scaling and enabled native Wayland for ArtCraft Suite

- Diagnosed GridCraft bloated UI and blurry rendering: root cause was compounding scale factors from Xwayland fallback (`Xft.dpi: 120` = 1.25x), Sway fractional scaling (1.30x bilinear upscaling), and `~/.config/gridcraft/ui.json` `interfaceScale: 150` (1.50x), multiplying into an effective ~2.44x scale factor where ribbon chrome consumed 530px (leaving only 13 visible rows).
- Set GridCraft `interfaceScale` to `110` (1.1x scaling for comfortable readability while keeping ribbon compact).
- Configured native Wayland backend flags across the ArtCraft Suite (`GRIDCRAFT_WAYLAND=1`, `WORDCRAFT_WAYLAND=1`, `FILMCRAFT_WAYLAND=1`, `PHOTOCRAFT_NATIVE_WAYLAND=1`) in `~/.config/environment.d/40-craft-apps.conf` and `~/.local/bin/sway-run`.
- Added executable wrapper `~/.local/bin/gridcraft` to enforce `GRIDCRAFT_WAYLAND=1` under Wayland sessions.
- Enhanced `craft-scale` (`~/.local/bin/craft-scale`) to support `auto` keyword alongside integer percentages.
- Added comprehensive subsystem architecture and troubleshooting documentation in `docs/system/artcraft-suite.md`.
- Live verified: GridCraft maps as native Wayland `xdg_shell` (`window: null`), ribbon height reduced from 557px to 310px, visible rows expanded from 13 to 39, and rendering is crisp and pixel-perfect at 1920x1200@165Hz. `sway-check` passed with 0 errors/warnings.

## 2026-11-03

### Documented Nano11 known-good recovery procedure

- Added `docs/virtualization/nano11-recovery-runbook.md`, cross-linked from the Nano11 subsystem documentation and system index. It preserves the verified Intel VF/Looking Glass baseline, exact host/guest verification commands, 64 MiB KVMFR and indirect-copy requirements, failure lookup, safe restore sequence, guest session handling, evidence locations, rollback hazards, and outstanding acceptance limits. Documentation only; VM, drivers, Sway, and launchers were not modified.

### Repaired Nano11 Intel VF graphics and native Looking Glass

- Installed and verified signed Windows Intel 32.0.101.7092 on the SR-IOV VF; explicit D3D11 hardware creation identified Intel 8086:A78B. PF/i915 and NVIDIA/Sway bindings were retained.
- Resized KVMFR/QEMU from 32 to 64 MiB after IDD rejected the only native mode; live LGMP video/input/clipboard now work. Intel direct-copy corruption required indirect copy. Recorded real motion around 104-120 UPS, guest key/click acceptance, and Right Ctrl release; sustained 165 UPS and audible audio acceptance remain unverified.
- Added first-frame startup validation/RDP fallback, memlock-safe ACPI shutdown, exact PF DRM selection, workspace-10 launch/menu integration and reproducible guest setup with event-triggered RDP-to-console restoration. Removed only the obsolete driver-image attachment and optional installer extras; retained disks/recovery.
- Validated shell/Sway/desktop configuration, source/live parity, cold VM recreation, simulated failed-client RDP fallback and console return. No Linux reboot or commit/push. Intel Vulkan startup-probe hangs and unrelated broken chezmoi documentation discovery remain documented limitations.

### Nano11 Looking Glass capture and input correction (partial guest-side recovery)

- Verified running Intel SR-IOV VF 0000:00:02.1 attached through vfio-pci; Intel PF/VirtIO rendering and NVIDIA/Sway separation remain intact. Looking Glass B7-829 can connect to SPICE INPUTS/DISPLAY/CURSOR but not to its LGMP host video source; a high client FPS with missing guest UPS must not be treated as 165 Hz guest output.
- Corrected the managed client from invalid input:captureOnStart=yes to spice:captureOnStart=yes plus input:captureOnFocus=yes; restored automatic local redraw targeting instead of forced 165 FPS and disabled debug FPS overlay. Source/live parity and shell syntax passed; retest still found no LGMP producer. nano11 rdp reopened and focused a usable Windows RDP session for recovery. Guest Intel graphics driver and Looking Glass IDD capture remain pending verification. See docs/virtualization/dockur-windows.md.

### Corrected night-light session state and added Yazi shortcut

- `sway-session-save` / `sway-session-restore` now detect applied night-light state from `wl-gammarelay` D-Bus `Temperature` rather than the obsolete `wlsunset` process; 6500 K is off, lower values are on, with the persisted preference as a fallback if D-Bus is unavailable. Live 6500 K (off), simulated on/off/fallback, and source/live parity were verified.
- Added `Super+Shift+E` for on-demand tiled Yazi in a themed Foot client, while preserving `Super+E` as the Thunar scratchpad. Applied only the three affected chezmoi targets; `sway-check` reported zero failures/warnings and `sway-safe-reload` completed. MCP unchanged.

### Minimal Fuzzel process killer menu (`Caps + w`)

- Rebuilt `rofi-pkill` (invoked via `Caps + w` through xremap) from the legacy oversized boxed Rofi UI to a native Wayland layer-shell Fuzzel dmenu interface matching the minimalist aesthetic of the primary app launcher.
- Integrated dynamic Papirus icon resolution via desktop entry indexing and well-known fallback chains (`brave`, `thunar`, `foot`, `freerdp`, `craft-anything`, `windows`/qemu, `codex`, `btop`, `steam`, `vesktop`).
- Replaced noisy metrics (CPU%, RAM%, process count, `[APP]`/`[BG]`, section headers) with clean single-line labels prioritizing active windowed applications (`Application Name — Window Title`), followed by background workloads. Window titles are automatically stripped of redundant browser and brand suffixes.
- Added child process aggregation folding helper/renderer subprocesses into parent application groups. Configured `--override=key-bindings.custom-1=Shift+Delete` (exit code 10) for force `SIGKILL` while retaining standard `Enter` (exit code 0) for polite `SIGTERM`.
- Shielded critical infrastructure: compositor (`sway`), input (`xremap`, `xscroll`), audio DSP (`dusky`, `pipewire`, `wireplumber`), Bluetooth reconnect daemons (`bt-keyboard-reconnect`), clipboard (`cliphist`), package managers (`pacman`, `makepkg`, `paru`), and AI coding agents. Live verified with grim capture, SIGTERM/SIGKILL tests, and `sway-check`.

### Hardened Nano11 Windows menu, RDP resizing, and lifecycle

- Added the `Alt+W` context-aware `rofi-windows` control menu and changed the desktop/Fuzzel entry to `Windows (Nano11)` with the installed Windows distributor icon. The primary menu action tracks runtime state: Start, Open, or Show; Stop, Restart, Web Console, and Status remain available as appropriate.
- Replaced FreeRDP dynamic-resolution updates with a fixed 1920x1200 remote surface plus client-side smart sizing and AVC444. Live small-to-large Sway resize testing repainted the full Windows desktop/taskbar instead of leaving the prior black expansion region; SDL FreeRDP continues to use its OpenGL renderer. Looking Glass was deliberately not added because Nano11 uses VirtIO-GPU/Venus rather than a passed-through guest framebuffer.
- Hardened `nano11 launch` so an existing RDP surface is focused, a closed RDP window is reopened without rebooting Windows, and concurrent RDP starts are serialized. Added a non-inheritable VM lifecycle lock so overlapping Stop/Start operations serialize instead of racing Podman `stopping` state; verified the overlap ends in a healthy running VM with no leaked lock.

### Thunar scratchpad toggle integration and dynamic theme-accent folder icons

- Extended `scratch-toggle` with `files` mode using `thunar --name scratch-files $HOME` and canonical 1400x900 geometry. Bound `$mod+e` to `scratch-toggle files` so pressing the hotkey summons and focuses Thunar when hidden/unfocused and moves it to scratchpad when focused (cleanly yielding focus back to the underlying window). Polite window close (`$mod+q` or `Ctrl+q`) completely terminates the underlying process with zero lingering background daemons.
- Updated `20-thunar-folder-color.py` to recursively scan all icon sizes in `~/.local/share/icons/Gruvbox-Plus-Dark/places/` (`16`, `22`, `24`, `32`, `48`, `scalable`), rewriting hardcoded Gruvbox cream/yellow paths (`class="ColorScheme-Text"`) on folder SVGs to `class="ColorScheme-Highlight"` and synchronizing with `target_accent`. Verified 16px folder icons in compact details view immediately inherited the active theme accent (`#00ccff` in Azure Glow).


### Replaced Dockur Tiny10 with Nano11 native-RDP lab

- Replaced the old Tiny10 runtime with a custom Nano11 25H2 Windows lab under `/mnt/Games/VirtualMachines/dockur-nano11/`, using rootless Podman, KVM, 2 GiB RAM, 4 vCPUs, a 64 GiB QCOW2 disk, and retained custom install media for deterministic cold container recreation.
- Installed and verified the signed Red Hat/QEMU VirtIO GPU driver in Windows (`QEMU VIRTIO GPU`, `oem12.inf`, driver `100.103.104.30200`) while QEMU uses Intel `renderD128` through `egl-headless` + `virtio-vga-gl` with `venus=true`; the RTX 5050 remains host-bound to NVIDIA.
- Enabled loopback-only RDP and promoted `sdl-freerdp3` as the native Sway presentation path with dynamic resolution, clipboard, PulseAudio/PipeWire audio, and redirected `shared/` storage. Raw host VNC publication was removed from the final launcher, and the cold-boot RDP readiness window was expanded for the 2 GiB guest.
- Added the managed `nano11` launcher, desktop/Fuzzel entry, and Fish function; retired the `tiny10` launcher/desktop/runtime after confirming its shared directory was empty. The Nano11 VM remains on-demand with no persistent service.

### Reverted Elden Ring to the verified LSFG 2x baseline

- Reproduced the user-visible failure with the managed 4x profile: a real Sway launch could remain on a persistent fullscreen black surface despite `flow_scale=0.8`, Performance Mode, normal swapchain count, and successful LSFG layer initialization. The earlier 4x success is therefore historical evidence only, not a durable stable baseline.
- Re-tested the same Proton/ModEngine/randomizer stack with MangoHud disabled and the prior 2x profile (`flow_scale=1.0`, `performance_mode=false`, `preserve_swapchain_image_count=false`, vsync pacing). LSFG initialized at 2x; two captures were ~99.98% black during normal startup and the next capture rendered the game. Restored 2x in the managed LSFG template and updated launcher/menu labels accordingly.
- Rejected an NVIDIA-only `VK_DRIVER_FILES` workaround because hiding the Intel ICD prevented ModEngine from reaching `eldenring.exe`. The installed stable `lsfg-vk 2.0.0-1` binary also has no `LSFGVK_GPU` support and rejects the newer `gpu` profile key.

### Stabilized Elden Ring LSFG 4x on the 165Hz panel

- Reproduced the fullscreen black startup surface with the plain 4x Elden Ring LSFG profile, then verified a stable 4x profile using `flow_scale=0.8`, `performance_mode=true`, and `preserve_swapchain_image_count=false` while retaining vsync pacing. Five compositor captures progressed from black/white startup into distinct changing rendered game frames and lsfg-vk reported multiplier 4 with successful half-precision instance initialization.
- Kept MangoHud disabled and the non-Steam randomizer/QoL stack unchanged. The installed lsfg-vk 2.0.0 parser does not support the newer `gpu` profile key, so no unsupported GPU key is persisted.

### Switched Elden Ring LSFG to 4x for the 165 Hz panel

- Changed the managed Elden Ring LSFG-VK profile from multiplier 2 to 4 while keeping `pacing_mode = "vsync"`, `override_present_mode = true`, and the rest of the randomizer/ModEngine stack unchanged. The 60 FPS base can now provide up to 240 generated frame candidates while presentation remains bounded by the 165.004 Hz display. Updated Alt+g/launcher wording to reflect the 4x / 165 Hz target.

### Added randomizer-aware Elden Ring QoL DLL stack

- Added managed `config_randomizer_stack.toml` around the Randomizer v0.12.2 output. Map for Goblins v2.1.6 and Faster Revival v1.0.0 load once as ModEngine external DLLs; DelayedModLoader waits 7 seconds before loading CameraFix and PauseTheGame. The managed EldenModLoader config now has an empty `[loadorder]`, eliminating duplicate DLL injection.
- Map for Goblins uses its native in-game menu and spoiler-free `anonymous_loot=true` while retaining randomizer-aware live loot flags/labels/icons; live verification mapped 7,376 markers. Faster Revival was built from the author's public MSVC-target source and live verification registered its death hooks and observed about a 3.8-second respawn. A real shared-launcher boot retained LSFG 2x and a neutral MangoHud config with the native Steam process absent.
- Transmogrify and Adaptive Bar Scaling were not substituted from mirrors: the former's Windows-oriented dependency failed a conservative Linux clang-cl/MSVC cross-build, and the latter has no verified public source while Nexus binary delivery is authenticated. Glorious Merchant remains intentionally uninstalled.

### Kept Elden Ring launcher fully non-Steam

- Removed the temporary native-Steam auto-start/readiness gate from `eldenring-lsfg`. The non-Steam installation continues to use its dedicated Proton prefix and ModEngine 2 directly; `SteamAppId`/`SteamGameId` and `STEAM_COMPAT_*` are compatibility metadata only and do not cause the Steam desktop client to launch.

### Fixed Elden Ring randomizer startup freeze

- Bisected the non-Steam Elden Ring launcher through vanilla Proton, empty ModEngine 2, randomizer-only, CameraFix/EldenModLoader, MangoHud, and LSFG. MangoHud injection alone reproducibly froze the game on its startup presentation surface; the failing path logged unsupported `VK_PRESENT_MODE_FIFO_RELAXED_KHR`, while randomizer + CameraFix + LSFG 2x rendered normally without MangoHud.
- `eldenring-launch-inner` now writes a neutral Proton `user_settings.py` by default; MangoHud is diagnostic-only via `ELDENRING_MANGOHUD=1`. During diagnosis a temporary native-Steam readiness gate was tested, but it was subsequently removed because this is a non-Steam installation; the current launcher never starts or waits for the native Steam client. Alt+g and the Alt+Space desktop entry continue to converge on the same shared launcher. Final live verification showed changing rendered frames and active RTX 5050/LSFG workload.

### Thunar floating window rules, compact details view, and sidebar theme styling

- Added Sway window rules in `dot_config/sway/config.d/30-window-rules.conf` ensuring Thunar (`app_id="(?i)^thunar$"`) always opens as a centered floating window (`floating enable, resize set 1400 900, move position center, focus`), preventing instances from being swallowed into tabbed layout containers (such as Workspace 2 with Brave).
- Corrected `dot_config/theme/templates/gtk.css` sidebar styling so unselected shortcut items use standard foreground color (`{{white}}`) instead of forcing `color: {{accent}}` across the entire treeview. Configured distinct rounded pill highlights (`{{one_bg2}}`) for selected sidebar and file list rows, and added styling for breadcrumb path buttons.
- Declared managed Thunar configuration in `dot_config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml` and applied xfconf properties: set details view zoom level to `THUNAR_ZOOM_LEVEL_25_PERCENT` (16px compact icons matching GTK file choosers), visible columns to `Name, Size, Type, Date Modified`, location bar to `ThunarLocationButtons`, removed tab and split-view creation buttons from the toolbar, and disabled session tab restoration (`last-restore-tabs = false`).


### Added native Wayland RDP presentation for Dockur Tiny10

- Extended the managed `tiny10` launcher so `launch` prefers `wlfreerdp3` and opens Tiny10 as a normal Sway/Wayland window with dynamic resolution, clipboard, PipeWire-compatible audio, and the host `shared/` directory redirected into Windows; `tiny10 rdp` explicitly requests native RDP and `tiny10 open` remains the browser-console fallback.
- RDP credentials stay outside chezmoi in GNOME Keyring and are supplied to FreeRDP through `/args-from:stdin`, keeping the password out of argv/process listings. `freerdp` is now declared in `packages/development.txt`; the current remote command guard blocked the privileged package install in this session, so the live launcher safely retains the web fallback until normal package reconciliation installs it.

### Scoped wallpaper cycling for shared Omarchy monorepos

- Fixed `Win + Shift + W` / `Alt + Shift + W` cycling for official built-ins such as `omarchy-everforest`. Discovery version 2 treated the shared `omacom/omarchy` repository as one wallpaper source and had cached 98 backgrounds from many sibling themes under Everforest. Discovery version 3 derives canonical wallpaper roots from each theme's recorded candidates and applies that scope to both remote discovery and local cached cycling.
- Repaired the live Everforest cache to exactly its two declared backgrounds (`themes/everforest/backgrounds/1-tree-tops.webp` and `omarchy.webp`). Verified three consecutive `theme-wallpaper next` operations stayed inside that two-file set at roughly 99-107 ms per cycle; cached cycling is local and does not wait for repository repair.

### KeePassXC + Syncthing password-manager baseline

- Installed `keepassxc 2.8.0-3.1` and `syncthing 2.1.7-1.1` from the CachyOS x86-64-v3 repositories; package transaction snapshots were created by snap-pac and a separate pre-change root Snapper snapshot was taken first.
- Created `~/Sync/KeePass/` as Syncthing folder `keepass-vault` in send/receive mode with filesystem watching and simple versioning retaining 10 historical copies. Syncthing was then moved to the workstation's preferred on-demand model: `syncthing.service` is disabled from persistent startup and `keepassxc-sync` opens bounded pre/post sync windows around KeePassXC use.
- Enabled KeePassXC browser integration and installed the local Brave native-messaging host pointing to `/usr/bin/keepassxc-proxy`. The browser extension itself remains subject to Brave's normal installation confirmation, and no vault/master password or other secret was handled by automation.
- Added `keepassxc`/`syncthing` to the declarative package manifest, service reconciliation that keeps Syncthing disabled at boot, a managed `keepassxc-sync` wrapper plus user desktop entry, and `run_onchange_linux-30-setup-keepass-sync.sh.tmpl` to recreate the directory, browser integration/native host, and Syncthing folder/versioning on a fresh apply; documented the Linux/Android KeePassXC + KeePassDX + on-demand Syncthing architecture in `docs/system/password-manager.md`.

### Reduced theme-picker and theme-switch latency

- Made `rofi-theme` cache-first: `theme-sync` now writes `~/.cache/theme/picker-index.json`, normal picker startup reads that compact 327-row index, and existing cache is shown without source-tree freshness scans or synchronous `theme-sync`; Ctrl+R remains the explicit refresh. Measured script-mode startup dropped to about 25-42 ms typical with a 30 ms median in the verification sample.
- Removed the redundant `50-ui-chrome` theme hook because `theme-set` already preserves ui-sync-owned Mako/Swaybar/GTK geometry during rendering. Private `.next/` staging no longer fsyncs temporary files, direct named applies avoid enumerating the whole theme catalog, no-op applies skip `/proc` and GTK/Thunar work, and a missing live Neovim no longer triggers a headless Base46 compile because Neovim startup already repairs a stale marker. Same-theme applies measured about 58-70 ms.
- Mako/Dunst/Yazi reload-current-config commands now run as safe detached one-shots after atomic promotion, while explicit Sway/GTK/wallpaper values stay ordered. The expensive Gruvbox folder-icon recolor, previously measured at ~332 ms while scanning thousands of SVGs, now runs in a separately locked/stale-guarded one-shot worker and rewrites only changed SVGs. A rapid Blackgold -> Cobalt2 -> Blackgold verification completed the core theme transaction in about 84 ms each direction and the folder accent converged to the final active theme.

### Consolidated Waydroid technical documentation and integration

- Consolidated Waydroid documentation into `docs/virtualization/waydroid.md`, replacing `docs/virtualization/waydroid-google-photos-unlimited.md` with neutral, technical specifications and removing all promotional phrasing.
- Documented the five-layer Google Photos Pixel XL backup tier spoofing architecture (`Photos.apk` early boot bind-mount, `system.prop` Pixel XL identity injection, `pixel_2016_exclusive.xml` feature injection, and `gphotos-detach` package protection).
- Documented container storage permission fix (`setfacl` recursive POSIX ACLs on `/sdcard/` media mapping) and desktop integration (`waydroid-apk-install` double-click installer, MIME association, and Thunar custom action).
- Updated cross-references in `docs/system/SUBSYSTEM_MAP.md` and `docs/virtualization/waydroid-guide.md`.

### Ported authored Omarchy terminal palettes to Foot

- Made Foot the primary authored-terminal adapter for Omarchy themes that ship `alacritty.toml` and/or `kitty.conf`. `theme-set` now maps repository background/foreground, cursor, selection, URL color where available, and ANSI 0-15 into `foot-colors.ini` with precedence Alacritty -> Kitty missing-role fallback -> normalized generated palette; Foot fonts, sizing, padding, keybindings, and client/server behavior remain unchanged.
- Updated live Foot hot reload to send the same translated palette through targeted OSC 10/11/12/17/19 and OSC 4 updates, so already-open Foot windows and newly launched `footclient` windows agree. Verified Cobalt2 against its authored terminal palette and a synthetic Kitty-only profile, then restored the pre-test Blackgold theme and wallpaper.

### Added rootless Dockur Tiny10 with Intel VirtIO-GPU acceleration

- Installed rootless `podman` (Snapper package transaction snapshots 293/294) and added it to `packages/development.txt`; no Docker daemon or persistent container service was introduced.
- Added managed `tiny10` launcher plus desktop/Fuzzel entry. Persistent guest storage lives under `/mnt/Games/VirtualMachines/dockur-tiny10/`, ports 8006/3389 are localhost-only, and the container is started/stopped on demand.
- Configured Dockur `VERSION=tiny10` with KVM, 4 GiB RAM, 6 vCPUs, 64 GiB QCOW2, and `GPU=Y` on the dynamically discovered Intel DRM device. Verified live QEMU uses `egl-headless` + `virtio-vga-gl` with `blob=true,venus=true` and holds Intel render-node FDs while the RTX 5050 remains host-bound to NVIDIA.
- Hardened `tiny10 stop` for rootless Podman by signalling Dockur's `/run/entry.sh` Bash directly so its ACPI trap owns guest shutdown instead of relying on PID-1 forwarding through Tini. Fixed the managed PID lookup to consume the full `podman top` stream; the previous early `awk exit` combined with `pipefail` produced SIGPIPE and aborted the launcher before shutdown.
- Final cold-cycle validation passed: managed stop completed in 8 seconds with no forced fallback; the next start reached guest RDP in 9 seconds, preserved the same QCOW2 inode and `windows.boot`, did not recreate installation media, booted only from `data.qcow2`, restored the web console, and restored Intel Venus acceleration with 10 render-node FDs.

## 2026-11-02

### Dynamic Thunar sidebar theme reload and floating window rule

- Fixed Thunar sidebar staying stuck on old theme colors: updated `dot_local/bin/executable_theme-set` to perform an instantaneous (28 ms) GSettings `gtk-theme` toggle and background Thunar daemon refresh on every theme switch. This forces GTK3/GTK4 to reload style contexts and re-parse `~/.config/gtk-3.0/gtk.css` dynamically across all dark and light themes.
- Enforced floating window behavior for Thunar in `dot_config/sway/config.d/30-window-rules.conf` (`for_window [app_id="(?i)^thunar$"] floating enable, resize set 1400 900, move position center`). Prevents Thunar from being swallowed as a tab alongside Brave on Workspace 2, eliminating top tab bars and keeping single-window workspaces edge-to-edge.

### Preserved original Omarchy per-app theme intent

- Added author-app-profile precedence to the theme engine. Omarchy imports now preserve safe structured colors from app-specific repository files and use them ahead of synthesized fallback for Alacritty, Kitty, btop, Cava, and Mako; fonts, geometry, keybindings, commands, compositor configuration, arbitrary CSS behavior, and upstream Lua execution remain locally controlled/ignored. btop keeps the workstation `main_bg=""` invariant even when the author specifies a solid background.
- Added the daemonless `theme-upstream-apps` compatibility hydrator for older imports. Version-3 profiles use a blobless Git tree and only selected small text blobs, cache under `~/.local/share/theme/upstream-apps/`, and reapply through serialized `theme-set` only if the theme is still active. Live tests verified Cobalt2's original btop gradients/terminal colors, Aetheria's original 8-color Cava gradient and Mako colors, and a legacy All Hallows Eve switch at about 463 ms while profile hydration completed afterward.

### Enabled large Fuzzel selected-app icon preview

- Kept the compact `Alt + Space` launcher geometry and scale-derived row icons, but changed `image-size-ratio` from `0` to `0.58` so Fuzzel shows its native large selected-application preview when the result set narrows to a few entries.
- Verified the generated `GitHub Profile: kmanisk` desktop entry already resolves to the managed `github.svg`, allowing the GitHub logo to appear in both the row and large preview without adding another launcher path.

### Scaled Thunar and GTK dialog font size in ui-metrics

- Increased `GTK_FONT` from `13` to `20` in `dot_config/ui-metrics.conf` and `~/.config/ui-metrics.conf`.
- At the active Sway output scale of 1.30, `ui-sync` derives `font-size: 15.4pt` (up from `10.0pt`) for `.thunar, window.thunar, filechooser, window.dialog` in `~/.local/state/theme/gtk.css`.
- Reset Thunar details view zoom from `THUNAR_ZOOM_LEVEL_250_PERCENT` (which had bloated folder icons to compensate for tiny text) to `THUNAR_ZOOM_LEVEL_50_PERCENT` for clean, proportional file lists and sidebar navigation.

### Restored complete Omarchy repository wallpaper sets

- Added lazy repository re-discovery for legacy wallpaper caches created under the retired five-image cap. `theme-wallpaper hydrate` now uses a blobless Git tree scan to recover the complete conventional wallpaper set, stamps the cache manifest with discovery version 2, reuses already-cached matching files, and downloads only newly discovered images. `theme-set` queues this repair in the existing detached hydration worker even when an old cached wallpaper is already usable, so theme switching remains nonblocking.
- Fixed wallpaper discovery so miscellaneous fallback images are used only when a repository has no conventional wallpaper path. This prevents support assets such as Bellerophon's `unlock.png` from being mixed into its official wallpaper rotation; Bellerophon now exposes exactly its 16 `backgrounds/` images. Live repair also expanded legacy `blackgold` from 5 cached candidates to 14 repository wallpapers while leaving the active theme untouched by the repair itself.

### Replaced Katana reconnect Python daemon with native sd-bus helper

- Reimplemented `bt-keyboard-reconnect.service` as native C using `sd-bus`/`sd-event`, with managed source at `~/.local/bin/bt-keyboard-reconnect.c`. The lightweight `~/.local/bin/bt-keyboard-reconnect` launcher hashes the source, recompiles only when needed into `~/.cache/bt-keyboard-reconnect/`, and then `exec`s the native binary; the service no longer loads Python, PyGObject, or GLib. The service reconciliation hook now explicitly restores `bt-keyboard-reconnect.service` on rebuilds instead of carrying the retired `bt-autoconnect.service` entry.
- Preserved the BlueZ event contract and 2/5/10/30/60 s async reconnect backoff, adapter/resume handling, bounded logging, and xremap attachment verification. The native helper also subscribes to login1's real session `Unlock` signal and restarts a missing xremap attachment through user systemd D-Bus instead of spawning `systemctl`.
- Measured the old Python daemon at 29.2 MiB RSS / 16.2 MiB PSS and the settled native daemon at about 3.5 MiB RSS / 0.4 MiB PSS, dormant in `do_epoll_wait` at 0.0% CPU. A forced Katana disconnect was automatically reconnected through the daemon's 2 s timer, and a separate stopped-xremap test was recovered and reattached successfully.

### Trimmed gvfs-gphoto2 camera monitor

- Removed `gvfs-gphoto2` and its orphan dependency `libgphoto2` (9.55 MiB total disk savings) after service audit verified zero PTP/digital camera usage.
- Removed `gvfs-gphoto2` from declarative package manifest `packages/linux-core.txt`.
- Retained `gvfs-mtp` and `gvfs-udisks2-volume-monitor` to preserve full Android phone file transfer and external USB drive management in Thunar.

### Simplified wallpaper success notification

- Kept wallpaper application behavior unchanged, but simplified the normal `wset` success toast to `Wallpaper changed`; filenames, extensions such as `.webp`, and render mode such as `fill` are no longer shown during theme/wallpaper changes. Automatic first-use hydration no longer emits a fetch-progress toast; manual fetches and actionable failures remain diagnostic.


### Instant theme-picker dismissal and asynchronous wallpaper hydration

- Removed Rofi from the theme-application critical path: Enter now validates the selected compiled ID, closes the picker immediately, and runs the existing serialized/validated `theme-set` transaction in a detached one-shot worker. Apply failures are reported through desktop notification and `~/.local/state/theme/last-picker-apply.log`; a latest-request token drops stale not-yet-started workers so rapid menu selections are last-choice-wins, while the mutation lock, staged validation, transactional promotion, and ordered application reloads remain unchanged.
- Removed first-use network I/O from `theme-set`. Missing resolved Omarchy wallpaper bytes now use the theme solid background immediately while a deduplicated `theme-wallpaper hydrate <theme>` worker downloads only that donor repository outside the global theme lock; final wallpaper application takes the lock and re-checks active theme identity so stale downloads cannot overwrite newer selections. Live verification measured picker dispatch at about 43 ms, uncached theme transactions at roughly 0.5-0.6 s, successful background wallpaper application after the transaction, and a rapid-switch stale-fetch guard pass.


### Restored Katana S K2 Bluetooth keyboard auto-reconnect daemon

- Diagnosed Katana S K2 (`CC:04:2E:90:66:02`) blinking in pairing mode after sleep. BlueZ's native `ReconnectAttempts=7` expires after 127 seconds of device idle sleep, causing BlueZ to drop the peripheral from kernel LE connection attempts and leaving wake advertisements unhandled.
- Restored and hardened `bt-keyboard-reconnect.service` and `~/.local/bin/bt-keyboard-reconnect` (`dot_config/systemd/user/bt-keyboard-reconnect.service`, `dot_local/bin/executable_bt-keyboard-reconnect`). The event-driven Python D-Bus daemon monitors device properties and resumes/unlocks, re-arms connection backoff without busy-polling, and gracefully ignores in-progress connects. Verified live: Katana automatically reconnected upon wake and xremap layer bindings were verified intact.
- Removed the problematic `timeout 6` wrapper from `~/.local/bin/bt-katana` (`dot_local/bin/executable_bt-katana`) to prevent premature client termination leaving pending HCI connection requests in the kernel (`br-connection-busy`).

### Artistic semantic Omarchy donors for non-Omarchy palettes

- Added `~/.config/theme/wallpaper-preferences.json` plus semantic donor scoring in `theme_engine.wallpaper_policy`: exact/alias/identity resolution remains first, then unmatched palettes are classified into artistic oil/illustration, light artistic, natural art, terminal technical, blueprint technical, or synth technical and matched only to repository-backed Omarchy wallpaper sets. Ranking preserves theme polarity and scores accent/background/Base16 color compatibility; the selected palette itself is never replaced.
- The 327-theme fleet now resolves as 248 own Omarchy repositories, 11 exact/alias identity donors, and 68 semantic donors with zero solid fallbacks or invalid wallpaper sources. Representative mappings include `aquarium -> evergarden`, `obsidian-ember -> van-gogh`, `starlight -> the-odyssey`, `omarchy-osaka-jade -> forest-green`, and `github_dark -> circuit-horizon`.
- Live Sway verification applied `aquarium` from `upstream/evergarden/` and `github_dark` from `upstream/circuit-horizon/`, then restored the pre-test `windows-dark-mode` theme and its selected blueprint wallpaper. Generic Wallhaven mappings remain runtime-disabled.

### Prevented nested container titlebars and accidental split hazard on Workspace 2

- Removed the legacy `bindsym $mod+Shift+b split h` binding adjacent to `$mod+b` (browser launcher) in `dot_config/sway/config.d/40-keybindings.conf`. Fat-fingering Shift while launching or focusing Brave Origin previously created horizontal split containers inside tabbed workspaces, leaving persistent `H[T[brave-origin]]` titlebars that bypassed `hide_edge_borders --i3 smart`.
- Hardened `~/.local/bin/smart-layout-toggle` (`dot_local/bin/executable_smart-layout-toggle`) to directly toggle the shared parent container's layout between `splith` and `tabbed` without wrapping windows in inner split containers, using marks, or invoking `focus parent`. Added single-child container flattening so orphaned split wrappers are cleaned automatically, ensuring single-window workspaces stay edge-to-edge with 0 titlebars.
- Flattened the live Workspace 2 container tree back to a clean single tabbed container and verified `sway-check` passed with 0 failures and 0 warnings.

### Waydroid APK double-click association and host media ACLs

- Added `waydroid-apk-install` and `waydroid-apk-install.desktop`, binding `application/vnd.android.package-archive` to Waydroid across the desktop environment and registering an "Install in Waydroid" action in Thunar. Double-clicking any `.apk` file now installs it directly into Waydroid with desktop notifications instead of opening PeaZip.
- Granted host user POSIX ACLs (`setfacl -R -m u:onyx:rwx,d:u:onyx:rwx`) on `~/.local/share/waydroid/data/media`, resolving permission denied errors (`os error 13`) in Yazi and Thunar while preserving internal Android `1023:1023` `media_rw` ownership.
- Hardened Pixel XL spoofing in the `gphotos-unlimited` Magisk module: moved `Photos.apk` bind-mounting into early `post-fs-data`, injected `Pixel XL` / `marlin` identity into `system.prop`, declared `NEXUS_PRELOAD` in `pixel_2016_exclusive.xml`, and added an automatic service-completion force-stop. Verified persistent unlimited tier badge across cold restarts.

### Removed generic wallpapers from non-Omarchy runtime themes

- Replaced non-Omarchy Wallhaven/runtime matching with strict Omarchy wallpaper donors: exact normalized name/display matches resolve automatically, while `~/.config/theme/wallpaper-aliases.json` records known family-name differences. The active palette is never replaced; only the wallpaper source is borrowed. Base46 `gruvchad` and `gruvbox_light` now use the five official `omarchy-gruvbox` backgrounds.
- Unmatched palettes such as `aquarium` now fall back to their own Sway `solid_color` background instead of a generic image. The historical 63-asset/327-mapping shared library remains for explicit maintenance/audit only and is ignored by `theme-set`/`theme-wallpaper`. Also removed the stale eight-file fallback slice in `theme-set`, preserving uncapped repository wallpaper sets end to end.

### Repaired user-level rclone credential ownership

- Fixed `~/.config/rclone/rclone.conf` from `root:onyx` to `onyx:onyx` while preserving mode `0600`, restoring normal user-level rclone access without changing credential contents.
- Verified `rclone listremotes` sees `gdrive:` and a live `rclone lsd gdrive:` succeeds against the existing five-category Drive layout.

### Waydroid restart controls in launcher menu and Fish

- Added `waydroid-restart`, which reuses the existing `waydroid-stop` and `waydroid-launcher` lifecycle helpers so recovery performs a full clean container/session restart without duplicating NVIDIA-mode or on-demand service logic. Added a standalone `Restart Waydroid` desktop entry plus a Restart action on the main Waydroid entry, and Fish aliases `wd`, `wds`, and `wdr` for launch/stop/restart.
- Validated Bash/Fish syntax and desktop entries, applied the source through chezmoi, and live-tested `wdr`: Waydroid returned RUNNING and recreated a visible, focused Sway `app_id=Waydroid` surface with a new PID.

### Removed duplicate repository upgrade from `uall`

- Corrected `uall` so phase 1 remains the single official-repository `pacman -Syu` pass and phase 2 uses `paru -Sua` for AUR-only upgrades. This removes the previous duplicate repository synchronization/upgrade pass and repeated warning output.
- Synchronized `binutils` and `xz` to the higher-priority `cachyos-v3` repository with `pacman -Suu`: `binutils 2.47-4 -> 2.47-2` and `xz 5.8.4-1 -> 5.8.3-1`. Snapper created pre/post snapshots 254/255; a follow-up `pacman -Su` dry check and `paru -Sua --print` were clean.

### Waydroid overlay root with Kitsune/Magisk

- Installed Kitsune/Magisk root through WaydroidSU into Waydroid's existing system overlay only; the base `system.img`, NVIDIA `vendor.img`, `nvidia-prolapse` configuration, GAPPS image, and Houdini overlay were preserved. A pre-root rollback archive with overlay/config/image hashes is retained at `~/waydroid-backup-pre-magisk-20261102/`.
- Verified a clean cold boot after setup: five consecutive Waydroid app-bridge probes passed, `Kitsune Mask` (`io.github.huskydg.magisk`) is installed, host-visible `magiskd` is running, Android reports boot complete, Play Store remains installed, Houdini still exposes ARM64/ARM32 translation, network and `audio.primary.waydroid.so` are healthy, and SurfaceFlinger remains ANGLE on NVIDIA Vulkan/NVK. ADB-shell `su` is intentionally denied until explicitly granted by Kitsune superuser policy.

## 2026-11-01

### Repository-authoritative Omarchy wallpapers

- Changed theme wallpaper precedence so GitHub-backed Omarchy community themes and official built-ins use only images shipped by their own repository; legacy/global Wallhaven mappings can no longer override those themes. Non-Omarchy themes may still use explicit matched-library assets, and a theme with no valid image falls back to its own solid palette background instead of inheriting a stale wallpaper.
- Expanded repository discovery to prefer `backgrounds/` / `wallpapers/` / `bg/` and then non-UI images elsewhere, removed the numeric wallpaper-count cap for Omarchy repositories, and made import/update preserve every relevant discovered repository image under `~/.local/share/theme/wallpapers/upstream/<theme>/` before deleting the clone. Older imports hydrate only their exact recorded repository candidates on first use; refreshing an import expands that metadata with the uncapped discovery rule.
- Refreshed `windows-dark-mode` from `OldJobobo/omarchy-windows-dark-mode-theme`: all 6/6 backgrounds are local and live cycling stays inside `upstream/windows-dark-mode/`; an uncached Alberta import independently fetched exactly its four repository backgrounds. Added `Ctrl + Shift + M` as an alias for the existing `Alt + Shift + M` theme picker.

### Fixed NvChad light themes rendering over a dark transparent surface

- Diagnosed `venice-from-above` with the correct light Base46 palette (`#f5f2e9`) and active theme state, while live Neovim `Normal` had no background because Base46 transparency was unconditional; fresh Neovim startup also forced `vim.o.background = "dark"` after loading the light cache.
- Made NvChad presentation theme-polarity-aware: light themes are opaque, dark themes retain transparency, `theme-set` carries that setting through live RPC/headless cache refresh, and `lua/options.lua` no longer overrides Base46's theme-owned `background`. Live and fresh-start verification both resolve Venice to `Normal bg=#f5f2e9`.

### Restored Steam CEF hardware acceleration on NVIDIA/Wayland

- Diagnosed the Steam `Loading user data...` stall as software-rendered CEF rather than disk, memory, download, or network pressure: `GPUAccelWebViewsV3=0` plus the legacy launcher flags `-cef-disable-gpu -cef-disable-gpu-compositing` left two `steamwebhelper` processes near one full CPU core each.
- Set Steam's application-owned `GPUAccelWebViewsV3` preference to `1` and changed the managed wrapper so hardware CEF is the default; `STEAM_CEF_SOFTWARE=1` remains an explicit emergency fallback. A controlled restart reported NVIDIA ANGLE with GPU compositing, rasterization, video decode, and WebGL enabled; the busiest startup webhelper fell to roughly 16% CPU and settled to low single-digit CPU instead of the prior sustained full-core load. See `docs/gaming/steam-client.md`.

### Prevented Brave from drifting into floating mode on workspace 2

- Added explicit `tiling_drag disable` while keeping `floating_modifier $mod normal` for already-floating utility windows. Sway 1.12 enables tiled-container dragging by default; the live affected `brave-origin` window was confirmed as `floating: user_on`, which occurs after the one-shot browser `for_window ... floating disable` rule and therefore survives it.
- Retiled the current Brave window, reloaded through `sway-safe-reload`, and verified the browser is back in the ws2 tabbed tiled layer (`floating: auto_off`) with no ws2 floating nodes. `sway-check` passed with 0 failures and 0 warnings.

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

## 2026-11-06

### rofi-games menu and game uninstallation cleanup

- Removed uninstalled entries for Grand Theft Auto IV, DARK SOULS III, and DS3 Randomizer GUI from `~/.local/bin/rofi-games`.
- Uninstalled 20 Minutes Till Dawn: removed entry from `~/.config/rofi/epic-games.list`, deleted files at `/mnt/Games/EpicGames/MinutesTillDawnxgosd`, removed Wine prefix `~/.local/share/legendary/compatdata/4656facc740742a39e265b026e13d075`, and updated `~/.config/legendary/installed.json`.

### Call of Duty: Modern Warfare Windows dual-boot retention and Proton incompatibility audit

- Downloaded (74.26 GB) and extracted (76.37 GB) Call of Duty: Modern Warfare (r4v3n singleplayer offline release) to `/mnt/Games/NonSteamGames/Call of Duty - Modern Warfare 4 (2026)`.
- Verified architectural incompatibility with Linux Wine/Proton due to hard dependency on Activision's Ricochet kernel anti-cheat driver (`Randgrid.sys` via `sc.exe create type= kernel`).
- Cleaned up all Linux-side test Wine prefixes (`compatdata/cod-mw4`) and logs, preserving the game installation intact on the NTFS partition for dual-boot Windows play via `!start_sp26.bat`.
- Documented findings, root cause analysis, and Windows launch steps in `docs/doesntwork/call-of-duty-modern-warfare-kernel-anticheat.md`.

### Bloodborne bbport and generic Proton game runner integration

- Integrated Supermedo's Bloodborne Windows port (`bbport`) with `GE-Proton11-7-x86_64`, DLSS upscaling, and ntsync.
- Added MangoHud telemetry integration to `bloodborne-run` and configured `~/.config/MangoHud/bb-probe.exe.conf` with horizontal layout and hotkeys (`Alt+3` toggle, `Alt+4` font presets).
- Created `proton-add-game` fish function (`~/.config/fish/functions/proton-add-game.fish`) and engine (`~/.local/bin/proton-add-game`) to automatically scan folders, configure isolated Proton prefixes, generate dGPU-optimized runner scripts, and register games dynamically in `rofi-games` (`Alt+G`) via `~/.config/rofi/custom-games.list`.
- Documented architecture and setup protocol in `docs/gaming/bloodborne-bbport.md`.

### Windows 10 IDD 8-minute relapse and guest display-idle experiment

- The Windows 10 B7-829 Looking Glass source lost LGMP frames again at ~19:58:52 IST, ~8 minutes 16 seconds after the preceding confirmed frame. The QEMU VM stayed running; a single Win+Ctrl+Shift+B Windows display reset shortcut did not restore it. A guest-only QEMU hard reset at 20:03:04 restored disk I/O and live 1920x1200 LGMP video.
- Injected `powercfg /change monitor-timeout-ac 0` into the guest via on-demand QEMU HMP input to test a possible Windows display timeout. **Guest-side execution and its effective power value are unverified**; the detailed runbook contains exact commands to verify/adjust within Windows and records possible IDD/driver alternatives. Do not treat the timing correlation as proof or describe the VM as permanently stable.
- Preserved the Intel VF/PF host bindings, Nano11, existing RAM/vCPU allocation, and all on-demand service rules. No automatic reboot, host boot change, or new daemon. Windows Store installation health and unsaved guest work after the hard reset remain unresolved.

### Windows 10 recurring IDD stall and confirmed manual recovery control

- At 19:46 IST on 2026-11-06, the X-Lite client's persistent splash and LGMP session loss recurred while QEMU remained running and disk I/O was unchanged. A harmless wake-key request and ACPI shutdown did not restore it. One deliberately issued QEMU `system_reset` at 19:50:07 restored guest boot activity and actual 1920x1200 LGMP video after brief reconnections; this was a guest-only **hard reset** and could lose unsaved guest work.
- Updated the source-managed `win10lab` launcher to warn when the latest Looking Glass source event is `primaryLost` even if a splash window remains open. Added a separately confirmation-protected **Recover frozen Windows 10 (hard reset)** action to the Windows/Fuzzel menu. No automatic reset or persistent monitoring service was introduced; a healthy existing client is still simply focused.
- Bash, ShellCheck, source/live launcher parity, menu output, on-demand service state, and the recovered guest video source were checked. Guest IDD event logs, possible forced-indirect-copy bandwidth effects, Store install health and long-term stability remain unverified. Windows 11/Nano11 and Intel host GPU bindings were preserved.

### Windows 10 Looking Glass client no-DMA fallback trial

- A user photograph at ~20:09 showed a recurring purple Looking Glass splash even though the running VM's log had previously briefly received LGMP frames. Repeated IDD host restarts and LGMP invalid-session messages suggest a Windows capture-side stability issue; root cause remains unconfirmed.
- Added validated `WIN10LAB_ALLOW_DMA=no` default to the source-managed Linux client with explicit `yes` rollback. A client-only reconnect at 20:15 confirmed a new 1920x1200 BGRA frame plus LGMP input/clipboard and exactly one Sway window, with no QEMU restart, GPU rebinding, or permanent service.
- The guest's enabled `Force indirect copy` and `Force full direct frame copies` checkboxes were observed only; they were not modified. Physical desktop visibility and long-term IDD reliability remain open acceptance tests.

### Windows 10 Looking Glass guest display restored after unresponsive guest

- At 17:06–17:08 IST, verified Windows X-Lite QEMU stayed alive but its IDD produced no LGMP frames and guest disk I/O was idle. One paced in-guest restart request was ignored; one **QEMU guest-only `system_reset`** at 17:07:05 restored guest boot activity and Looking Glass 1920x1200 BGRA frames. The matching B7-829 client on Sway workspace 5 became fullscreen and focused again; Intel host PF/VF ownership and Windows 11 were preserved.
- Verified `win10lab workspace` idempotence with three simultaneous launch/focus requests: they reused one Looking Glass client and the pre-existing on-demand file lock. No new daemon, automatic reset, VM hardware reconfiguration, disk image replacement, system reboot, or GPU rebind was introduced.
- Physical capture shortcuts, Microsoft Store installation completion after the guest hard reset, the Windows-side IDD stall cause, and longer-term stability remain unverified.

### Windows 10 Looking Glass source unavailable after launcher repair

- Late 2026-11-06 follow-up showed a separate guest display blocker: running X-Lite QEMU PID 142061 and its QEMU monitor/SPICE sockets remained healthy, but the B7-829 Looking Glass client logged `The transport source is not available`, timed out without a verified guest frame, and exited. The newly bound `Alt+W` launch path and Fuzzel menu correctly start/focus a temporary client, but guest video does not currently appear.
- Added bounded video-failure desktop notification to the `win10lab` source launcher; Bash, ShellCheck and source/live parity passed. No force-reset, synthetic guest keystrokes, VFIO binding changes, VM disk changes or interruption of the potentially active Store installer. The exact guest IDD/host failure is unverified; a safe in-guest recovery route or controlled restart remains pending.

### Windows 10 default Alt+W and shared menu visibility repair

- Corrected the legacy `Alt+W` binding from Nano11 to the running X-Lite VM on workspace 5; made `Alt+W` and `Alt+Shift+W` usable with shortcut inhibition. Nano11 remains available by `Super+Alt+W` when the Intel VF is free.
- Reworked the shared Fuzzel/Rofi Windows menu to show both VM names in every state, label the inactive one unavailable while the other holds the Intel VF, and explain this without stopping either VM. Running Windows 10 retains its focus/stop/restart and FPS controls.
- Validated shell syntax, ShellCheck, Sway config/reload (0 issues), live menu content and a direct `win10lab workspace` focus/launch test on workspace 5 reusing QEMU PID 142061. Physical keypress acceptance is still pending; the Windows guest, Windows 11 disk, and GPU binding were preserved.

### Windows 10 workspace 5 and Microsoft Store recovery research

- Verified Windows 10 Looking Glass moved live to workspace 5 and launcher Sway bindings now use `Super+5` to switch and `Super+Ctrl+5` to start/focus. Preserved existing `Super+Alt+5` network-menu shortcut and Nano11 on workspace 10. Sway/launcher syntax validation passed; QEMU remained running with 12 vCPUs, 4 GiB RAM and no diagnostic USB media.
- Restored normal guest keyboard-grab behavior; because Right Ctrl still failed in the user test, added a reversible Windows 10-only `KEY_F12` capture-release default (via the existing xremap `CapsLock+=` F12 mapping). Client-only relaunch logged F12, captured a real 1920x1200 frame, and left QEMU untouched; physical F12 acceptance is **not yet verified**.
- Recorded user-supplied Microsoft Store `Microsoft-Store.msix` version 22308.1401.6.0 framework-install progress and WinGet `msstore` `0x8a15005e` certificate-pinning error; success and root cause remain unverified. Compared the source-documented Store-client alternatives Raven, Alt App Installer, MSStoreHelper, MSStoreDownloader and MSStoreNoAuth; only the last still depends on WinGet's broken Store source. No third-party installer was installed; no Store services or framework dependencies were removed.

### Bookmarks and web favorites launcher restoration

- Restored dedicated bookmarks launcher `rofi-favorites` (with `rofi-bookmarks` symlink) bound to `Alt+u`, `Alt+b`, and `Alt+Shift+b` in `dot_config/sway/config.d/40-keybindings.conf`.
- Sourced bookmarks from `~/.config/rofi/favorites.list`, adding Amazon and annotating ASUS TUF Hardware & Drivers (Dolby) inventory. Uses Fuzzel layer-shell dmenu on Wayland with SVG icon hints (falling back to Rofi floating theme), opens the selected target in the browser via `xdg-open`, and focuses Workspace 2.
- Synchronized Fuzzel `.desktop` entries via `sync-fuzzel-favorites` (15 entries synced) and validated Sway config via `sway-check` and `sway-safe-reload`.

### Foot terminal URL mode execution fix

- Fixed `Alt+o` URL jump mode failing to launch links when pressing hint keys (e.g. `s`, `a`). Root cause was `foot-server.service` running in a systemd user environment with `PATH=/usr/local/bin:/usr/bin`, failing to find `foot-url-launch` in `~/.local/bin` (`spawn: foot-url-launch: failed to spawn: No such file or directory`).
- Symlinked `/usr/local/bin/foot-url-launch` to `~/.local/bin/foot-url-launch` for immediate live resolution in `foot --server`, added `dot_config/environment.d/05-path.conf` to persist `~/.local/bin` in the systemd user manager environment, and updated `foot-url-launch` to auto-discover `SWAYSOCK` and switch to Workspace 2 when web URLs open.

### Neovim smart file navigation and pathfinder.nvim integration

- Installed and configured `HawkinsT/pathfinder.nvim` via `lazy.nvim` (`dot_config/nvim/lua/plugins/pathfinder.lua`) providing visual jump targets (`<leader>pf`, `<leader>pF`, `<leader>px`) and multi-line file/URL scanning (`]f`, `[f`, `]u`, `[u`).
- Implemented `configs.smart_gf` (`dot_config/nvim/lua/configs/smart_gf.lua`) mapped to `gf`, `gF`, `g f`, `gx`, and `g x` in `dot_config/nvim/lua/mappings.lua`.
- Added support for `${VAR}` and `$VAR` environment variable expansion, shell variable assignment prefixes (`PATH=...`), colon-separated path lists, `file:line:col` coordinates, markdown links (`#L123`), and directory opening via `oil.nvim`. Added curly braces to `isfname` in `dot_config/nvim/lua/options.lua`. Verified in headless Neovim against `PATH=${HOME}/.local/bin:...` opening `oil:///home/onyx/.local/bin/`.

### Looking Glass Windows 10 keyboard capture correction

- Restored `input:grabKeyboard=yes` in the source-managed `win10lab` launcher after the earlier `no` setting interfered with capture/Right Ctrl behavior; preserved `input:ignoreWindowsKeys=yes`, Right Ctrl escape, and Sway's per-window shortcuts-inhibitor exception.
- Reconnected only the Windows 10 Looking Glass B7-829 Linux client, preserving the QEMU guest, Intel VFIO ownership and Nano11. Verified new LGMP 1920x1200 frames and input/clipboard negotiation, clean shell lint and source/live parity. Physical capture/release and host Super workspace behavior still require acceptance testing.
- The newly installed system `/usr/bin/looking-glass-client` B7 is distinct from the matched `~/.local/bin/looking-glass-client-idd` B7-829 used by this Windows 10 guest; no client-protocol upgrade was attempted. Guest-side IDD direct/indirect frame-copy options were not changed.

### Windows 10 guest display/input and clean-device usability

- Changed normal X-Lite QEMU boot to attach only its existing system disk; installation ISO and `XLITEDRV`/`WIN10RPT` USB media are retained on disk and now attach only in explicit `win10lab diagnostics` mode. Verified a clean shutdown, offline QCOW2 check and new guest boot with `media=none` and only `win10disk` in the QEMU monitor.
- Routed Windows 10 host Super shortcuts through Sway during Looking Glass capture, suppressed its capture notification, and added on-demand FPS/UPS measurement and diagnostics boot actions to the existing Windows/Fuzzel management menu. A fullscreen 1920x1200 BGRA frame was verified after the media-free guest reboot. Moving-frame smoothness and real keyboard behavior need user confirmation.
- Added a bounded post-stop Looking Glass/KVMFR release wait after observing one transient immediate-restart refusal. Source validation passed; repeat lifecycle test still pending. Clock-seconds registry cleanup was not injected into an actively used guest; the user-facing Windows command is documented in the virtualization runbook.
- Preserved the separate Nano11 VM, VF isolation, host NVIDIA/Sway and on-demand service policy. No host boot modifications, persistent service changes, or guest security-policy changes were made.

### Windows 10 X-Lite workspace / launch integration

- Added a dedicated workspace 9 Sway rule, Super+Alt+9 direct launch/focus, a Fuzzel/Rofi Windows 10 entry and a desktop application alongside the existing Nano11 workspace 10.
- Verified after a clean guest stop/restart: X-Lite QEMU runs 12 vCPUs (6 cores x 2 threads) pinned to P-core threads 0-11, retaining 4 GiB RAM and isolated VFIO/QCOW2; offline QCOW2 check passed. Looking Glass received real 1920x1200 frames fullscreen on workspace 9 with host-auto pacing (sustained 165 guest updates not verified).
- Kept guest starts on demand, cross-VM VF ownership checks, and the previously verified graceful shutdown fallback. Actual sustained 165 UPS, physical input, audio/clipboard and another host cold boot remain independent acceptance gates.

### ChatGPT Local Coder monitor 12-hour AM/PM timestamp formatting

- Updated `dot_local/bin/executable_local-coder-monitor` and live `~/.local/bin/local-coder-monitor` jq stream parser to convert UTC ISO-8601 timestamps from `.mcp-audit.log` into local 12-hour AM/PM time format (`%I:%M:%S %p`) via `fromdateiso8601 | strflocaltime`.
- Verified live rendering in `ChatGPT Local Coder Monitor` (`dc-term`) floating scratchpad (`Win + Alt + D`). Fallback protection preserves raw timestamp strings if parsing fails.

### Local Coder Policy Gateway production deployment and version switch

- Deployed secured Local Coder Policy Gateway to `/opt/local-coder-policygate` running under isolated system user `localcoder` (UID 947, GID 947) via `chatgpt-local-coder-policygate.service` on ports 3000 (MCP) and 3001 (Admin UI), preserving the existing Tailscale Funnel.
- Implemented `local-coder-switch` CLI supporting `new`, `legacy`, and `status` actions with automated health checks, port collision prevention, and automatic rollback to the previous version on failure.
- Implemented `policygate-project` CLI for scoped mapping of host project directories to `/srv/local-coder/projects/` under UID 947 and `ProtectHome=yes` using POSIX ACLs.
- Cleaned exposed tool manifest: permanently retired unsafe capabilities (`node_repl`, `ponytail_turn`) from the slim profile (33 tools active); verified `system_context`, `system_inspect`, `system_job`, and `chezmoi_inspect` are callable without deadlock.
- Dynamic security mode reporting: `agent_status` and permission metadata dynamically reflect active mode (`STANDARD`, `STRICT`, `YOLO`); verified `full_machine_access: false` unless an authorized YOLO lease is active.
- Verified cryptographic append-only audit ledger (`audit.jsonl`), Ed25519-signed operator approval workflow, YOLO lease activation/expiry, and 1.8-second version switching.
