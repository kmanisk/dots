# Workstation audit, 2026-10-23

## Overall status

Executed `~/MASTER_SYSTEM_AUDIT.md` after reading its complete contents and
starting documentation discovery with `~/docs/README.md`. This report records
implemented work and observed limits, not a claim that every hardware workflow
has passed. Diagnostic artifacts are private under
`~/.local/state/workstation-audit/20261023/`.

No failed system or user units were present at baseline or the regression pass.
Confirmed audio, launcher, editor, and hardware-tool defects were corrected.
No packages, kernels, GPU modes, boot settings, swap policy, or firewall rules
were changed. No resident process, service, timer, or polling daemon was added.
The existing speaker unit gained a dependency link; MicStudio restoration runs
once from the existing PipeWire startup configuration.

## Critical findings

- P1: positive gain after the microphone limiter could exceed full scale.
  An installed-plugin probe measured +3.00 dBFS with +5 dB output gain. Fixed.
- P2: MicStudio had no selectable persistent physical input. Implemented and
  tested through selection, disappearance, reconnect, and manager restart.
- P2: speaker DSP could stop with PipeWire without being started again by its
  dependency graph. Corrected and verified through server restart.
- P2: saved microphone settings were not automatically applied after server
  restart. Corrected with a one-shot `micstudio restore` action.
- P2: CS2 could run GameMode alongside ananicy when stopping ananicy failed.
  Corrected and tested with command stubs.
- P2/P3: dashboard hosting could replace a floating tool; ROGTUI reported an
  active asusd as missing; ROGTUI tests raced through global `HOME` and could
  overwrite live RGB preferences. Corrected.
- Storage finding: four Btrfs read errors are recorded. The count did not rise
  during this audit. A fresh read-only scrub completed with no errors; NVMe
  SMART reported no media errors. No repair or counter reset was performed.

No active P0 failure was established. A prior NVIDIA allocation failure and
Bluetooth transport failure exist in this boot's logs; neither reproduced in
the audit. Their presence is not proof of a current failure or a resolved bug.

## Fixes applied

| Component | Change | Verification |
| --- | --- | --- |
| MicStudio | `src/input.rs`, TUI `i` picker, `input` CLI, WirePlumber policy | Device filtering, synthetic source switch/reconnect/restart, scripted terminal |
| MicStudio limiter | User/model gain before limiter; output gain unity | Installed LADSPA probe, payload tests, live parameters |
| MicStudio settings | Missing denoise field defaults to 45 dB; `restore` startup action | Isolated tests and repeated PipeWire restarts restoring saved +5 dB |
| Speaker service | `PartOf=pipewire.service`, wanted by PipeWire | systemd verification and live restart |
| CS2 launcher | Safe GameMode fallback, prior-profile restoration, shell fixes | Four stubbed scenarios, Bash syntax, ShellCheck |
| Neovim | Exclude floating windows from dashboard hosting | Before/after reproducer, NvimTree and Oil lifecycle checks |
| ROGTUI | Correct D-Bus name; isolate simulated persistence and theme fixtures | 57 tests, installed release `--check` |
| Tele candidate | Harden marker parsing, stacked placement keys, pixel-cache invalidation | Full Go tests and vet against current upstream; candidate remains local |

Important configuration sources are under the discovered chezmoi source
`~/.local/share/chezmoi`. Only explicit targets were applied. The large existing
dirty dotfiles tree and ROGTUI documentation change were preserved; no broad
apply, reset, cleanup, or staging operation was used.

## System performance

| Measurement | Before | After | Method and result |
| --- | --- | --- | --- |
| Fish startup | 48.4 / 54.0 / 63.0 ms | Unchanged | Three `fish -i -c exit` launches; median 54.0 ms |
| Active Neovim startup | 41.0 / 37.8 / 40.5 ms | No improvement claimed | Three headless launches; median 40.5 ms |
| Packaged Neovim startup | 57.4 / 37.3 / 38.2 ms | Unchanged | Three headless launches; median 38.2 ms |
| MicStudio idle CPU | 0.00% | 0.00% | Two-second PTY sample, percentage of one logical CPU |
| MicStudio RSS | 5776 KiB | 5712 KiB | Same PTY sample; difference is not significant evidence of improvement |
| Limiter peak | +3.00 dBFS | -2.00 dBFS | Installed LADSPA, 48 kHz sine, same +5 dB moved before limiting |

Build work was running during some startup samples; these are warm baselines,
not controlled cold-cache benchmarks. End-to-end audio latency, gaming FPS,
frame pacing, speech quality scores, and Tele encoding speed were not measured.

## Resource usage

Initial memory availability was approximately 11 GiB of 15 GiB, with about
525 MiB used in the existing 15.2 GiB zram swap. Initial memory PSI averages
were zero. About 59 GiB was available on the 150 GiB Btrfs filesystem.

A separate two-second sample measured PipeWire at 0.5% of one CPU, speaker DSP
at 0%, WirePlumber at 0%, Foot at 0.5%, and nvidia-powerd at 3.5%. These are short
workload-dependent samples. Foot's own RSS was about 47 MiB; its systemd cgroup
also contains terminal-launched applications and builds, so multi-GiB cgroup
memory is not Foot's process footprint. Browser CPU observed at baseline was
left alone because its foreground workload was not established as waste.

No duplicate microphone manager or confirmed abandoned service was removed.
Existing optional RGB effects, keyboard reconnect, and hardware power services
were retained. A 50 ms ROGTUI ticker remains; no performance gain is claimed.

## Sway / Wayland / NVIDIA

- CachyOS, kernel `7.3.0-2-cachyos`; Sway `1.12`.
- `AsusMuxDgpu`, NVIDIA RTX 5050 Laptop GPU, driver `615.78.08`, modesetting on.
- Active output `eDP-2`, 1920x1200 at 165.004 Hz, scale 1, adaptive sync disabled,
  tearing allowed. NVIDIA is card1/renderD128; Intel is card2/renderD129 in this
  boot. Historical device enumeration in older docs is not a stable identifier.
- `sway -C` returned success with Sway's NVIDIA warning banner; `swaymsg reload`
  returned success. All 206 explicit bindings were inspected for duplicates
  within their modes and flags: zero exact-scope duplicates. Normal/inhibited
  pairs and equivalent shifted-symbol aliases are intentional.
- No MUX, compositor, driver, display-mode, environment, vibrance, or GPU
  architecture change was made. No session restart was performed.

## Foot / TUI environment

Foot `1.28.0` configuration validation and transient terminal launches passed.
The existing server was preserved. Its old compose warning did not reproduce
in a fresh launch, so no locale change was made. MicStudio's real PTY picker
and clean exit were checked. Yazi `26.9.1`, btop `1.4.7`, ytui, legendary-tui,
and bluetui were located. Their authenticated/network workflows and visual
behavior were not exhaustively tested. No replacement application was installed.

## Neovim

The active local Neovim `0.12.5` and packaged `0.12.6` both started without
stderr errors in the measured launches. Existing executable precedence remains.
Mason-provided language servers and formatters are present, and `lua_ls`
attached successfully. Headless checks verified startup dashboard, tree-focused
final-buffer closure, one dashboard, tree reopening, Oil preservation, and
floating-tool preservation. Neo-tree is not configured. Interactive visual and
all-language IDE workflows were not claimed as tested.

## Audio

### PipeWire / WirePlumber

PipeWire `1.6.9`, WirePlumber `0.5.18`; default source `ghelper-audio`, physical
default sink the analog hardware output. One microphone capture and one virtual
source remain. Runtime node/link inspection, `audio doctor`, and silent routing
tests passed. Quantum 512 at 48 kHz is a 10.67 ms period; this is not end-to-end
latency. A short idle `pw-top` sample showed zero ERR counters. Stress XRUN,
suspend/resume, and real Bluetooth reconnect tests were not performed.

### ASUS speaker DSP

The active music runner and speaker filter endpoints were observed. Its IR is
stereo, 48 kHz, 85.333 ms long. The existing FIR, EQ, dynamics, and gain values
were preserved. Speaker DSP returned after repeated PipeWire restarts. Silent
desktop playback reached the speaker input and the output reached hardware.
No listening comparison or full-chain limiter quality measurement was made.

### Gaming audio

A silent stream tagged as `cs2` reached only `sink.peace_gaming`; a desktop
stream reached speaker DSP. Gaming playback linked directly to hardware.
The existing Peace EQ and LoudMax settings were preserved. No real game stream
or Bluetooth game-output transition was tested.

### MicStudio

Input preference is stored in WirePlumber's `micstudio.input` setting. Virtual
and Bluetooth handsfree sources are excluded. Synthetic selection, manager
restart, disappearance/fallback, and reconnect passed. The selected physical
device remains the laptop microphone. The installed release restores saved
Clean gain +5 dB before the limiter, 45 dB denoise, +4 dB quiet boost, and unity
limiter output. Repeated server restarts restored those values automatically.
The restore action uses PipeWire's explicit argument-array configuration.

The known Clean controls and DSP topology were retained. Subjective speech
quality, inter-sample peaks, every creative voice, and real USB microphone
hotplug were not evaluated.

### Bluetooth

A2DP-only roles and disabled headset autoswitch were verified in config/runtime
settings. No headset was connected during final tests. A stale config comment
that claimed HFP switching was enabled was corrected; behavior was unchanged.
Audio reconnection and RF interference remain hardware-dependent follow-ups.

## ASUS hardware TUI

Installed ROGTUI correctly detects the active `xyz.ljones.Asusd` service after
the fix. Hardware checks passed; MUX, fans, brightness, firmware RGB, power
profile, and 60% charge limit were preserved. No new daemon was added.

## Gaming

Only the CS2 launcher changed. Four stubbed scenarios verified GameMode/ananicy
mutual exclusion, cleanup, previous-profile restoration, quoting, direct-MUX
environment, and game exit status. Existing other-game Steam launch options
include game-specific wrappers and were left unchanged without per-game tests.
MangoHud configuration remains immutable and unmodified.

Waydroid remains disabled/inactive as intended for on-demand operation. Android
networking, Vulkan, Play services, and container startup were not exercised.

## Tele / Sixel

See [source and contribution status](tele-sixel.md). The installed binary,
original tarball, original patch, and original source remain preserved.
The new branch is rebased onto current upstream and includes the additional
parser, stacked-image, and font-size cache fixes. Full Go tests, vet, gofmt,
Git whitespace checks, and upstream-required lint passed. Fresh headless
Sway/Foot screenshot checks passed for placement, clipping, repaint behavior,
resize, and live font zoom. A candidate executable built and passed `--help`;
the installed binary remains unchanged. Authenticated application workflows
and long-session memory measurements remain unverified. No PR, issue, or push
was published; the candidate stays local pending application validation and
upstream discussion.

## Development environment

Fish `4.9.3` syntax/startup passed; existing aliases, prompt, and editor behavior
were retained. Inherited PATH duplicates were observed without a demonstrated
execution defect and were not globally rewritten. GitHub CLI authentication
and repository API access worked. Default Git branch is `main`.

Installed toolchains observed: Rust/Cargo `1.99.1`, Go `1.27.1`, Python `3.14.8`,
Node `26.11.1`, npm `12.2.1`. Native Rust projects built and tested. Python
`pip check` reported no broken requirements; npm's user global list contained
Prettier. No toolchain, dependency, or lockfile update was performed.

Software, portfolio, and internship development have working native build,
test, GitHub, and editor foundations. Deployment credentials, application-specific
dependencies, remote SSH targets, and production deployment were not tested.

## Tests

- Unit/TUI: `bash ~/micstudio/scripts/test-isolated.sh` passed 39 tests with
  temporary preferences and blocked live audio-server access.
- Hardware integration: `cargo test --locked --offline -j 2 --test monitor_check`
  passed two microphone capture/monitor tests. No speech recordings were kept.
- ROGTUI: isolated-home `cargo test --locked --offline -j 2` passed 57 tests;
  both native projects passed release builds. Installed binary hashes matched
  their tested release outputs.
- Tele: `GOMAXPROCS=2 go test -p 2 ./...`, `go vet -p 2 ./...`, changed-file
  gofmt, and `git diff --check` passed after current-upstream integration.
  `golangci-lint` v2.15.0 reported zero issues. The official temporary release
  archive matched its published SHA-256; no system package was installed.
  A separate candidate build and `--help` passed. `test_sixel_visual.py` passed
  screenshot comparisons in private headless Sway/Foot, including 10x23 to
  14x34 pixel cell-size changes, cropping, erasure/restoration, and resize.
- Headless: `dashboard-test.lua`, `dashboard-oil-test.lua`,
  `dashboard-float-test.lua`, and Lua LSP attachment passed.
- Scripted/live: `test_input.py`, `test_gaming_route.py`, `test_cs2.py`, real
  PTY picker/exit, repeated PipeWire restarts, `audio doctor`, and service status.
- Config: Sway validation/reload, Foot validation, Fish syntax, systemd unit
  verification, Bash syntax, ShellCheck, PipeWire merged config, Lua compilation.
- Storage: `sudo -n btrfs scrub start -r -B /` completed on October 23, checking
  88.11 GiB in 27 seconds with no errors. This was a read-only scrub, with no
  repairs. The four recorded device read errors remained unchanged.

The scripts, scoped logs, limiter probe source, and measurements are retained
under `~/.local/state/workstation-audit/20261023/`. Interactive visual, listening,
reboot, suspend/resume, and real-game tests are explicitly separate and unperformed.

## Documentation

Updated `~/docs/README.md`, `audio/AUDIO_ARCHITECTURE.md`, `system/neovim.md`,
`system/rogtui-hardware-control.md`, and `gaming/cs2/wayland-43-stretched.md`.
Added this report and `system/tele-sixel.md`. MicStudio's repository README and
Tele's README, media/configuration docs, and changelog were updated as part of
their source commits. Older measurements remain historical.

## Git / GitHub

All audit project changes were committed using explicit paths on local branches.
Exact commit IDs are listed in the final verification addendum below. MicStudio
already had six unpushed commits before this work. ROGTUI's existing unrelated
documentation edit remains unstaged. The large pre-existing chezmoi working
tree was not committed wholesale. No changes were pushed, and no private audit
material was published.

## Not changed

Kernel/boot/initramfs, GPU architecture, drivers, power policy, fan curves, swap,
filesystem layout, snapshots, package selection, display timing, terminal fonts,
theme, microphone EQ/denoise baseline, speaker voicing, gaming EQ, Bluetooth
quality policy, Codex Full Access/no-approval settings, and existing editor setup.

## Known limitations and audit side effects

- The first pre-isolation MicStudio tests wrote settings and reset factory
  preset parameters; ROGTUI tests wrote mock RGB preferences. Observed Clean
  settings, including +5 dB gain, were restored. No earlier complete preset/RGB
  preference snapshot exists in this audit, so preservation of prior factory
  preset tweaks and saved RGB choices cannot be proven. Custom presets are
  retained by MicStudio's reset implementation. Hardware lighting remained off.
  The saved RGB brightness was subsequently aligned with the observed firmware
  Off state, after checking the saved file still matched the known test output.
  This restores consistency with active hardware, not proof of the prior preference.
  Future MicStudio tests use the isolated runner; ROGTUI mocks no longer persist.
- Four recorded Btrfs read errors remain. NVMe SMART passed with zero media/data
  integrity errors; the fresh October 23 read-only scrub found no errors.
  No storage repair, destructive test, or counter clearing was attempted.
- `pacman -Dk` reports the regular UUID sidecar
  `/var/lib/pacman/local/CACHY_UPDATE_NOTICE` as a package with missing metadata.
  It was not deleted or treated as proof of package-database corruption.
- Earlier NVIDIA allocation and Bluetooth transport errors were not reproduced
  or conclusively diagnosed. Missing optional libcamera SPA support is logged;
  V4L2 camera nodes exist, but camera behavior was not tested.
- No reboot is required by these changes. Reboot, suspend/resume, headset RF,
  perceptual audio, every TUI workflow, and deployment remain unverified.

## Rollback

Backups are under `~/.local/state/workstation-audit/20261023/backups/`, preserving
the same relative paths as the home directory. Config backups include pre-audit
CS2, speaker unit, dashboard, and the Bluetooth comment. Binary backups retain
the previous MicStudio and ROGTUI releases. The microphone settings backup was
taken after initial tests and has +4.5 dB, not the initially observed +5 dB.

Restore the modified managed files, then apply only those targets:

```sh
audit_backup="$HOME/.local/state/workstation-audit/20261023/backups"
cp "$audit_backup/.local/share/chezmoi/dot_local/bin/executable_cs2-launch" "$HOME/.local/share/chezmoi/dot_local/bin/executable_cs2-launch"
cp "$audit_backup/.local/share/chezmoi/dot_config/systemd/user/asus-speaker-dsp.service" "$HOME/.local/share/chezmoi/dot_config/systemd/user/asus-speaker-dsp.service"
cp "$audit_backup/.local/share/chezmoi/dot_config/nvim/lua/configs/dashboard.lua" "$HOME/.local/share/chezmoi/dot_config/nvim/lua/configs/dashboard.lua"
chezmoi apply ~/.local/bin/cs2-launch ~/.config/systemd/user/asus-speaker-dsp.service ~/.config/nvim/lua/configs/dashboard.lua
```

To remove the new integrations, remove only the files introduced by this audit:

```sh
rm ~/.local/share/chezmoi/dot_config/wireplumber/wireplumber.conf.d/51-micstudio-input.conf ~/.config/wireplumber/wireplumber.conf.d/51-micstudio-input.conf
rm ~/.local/share/chezmoi/dot_local/share/wireplumber/scripts/micstudio-input.lua ~/.local/share/wireplumber/scripts/micstudio-input.lua
rm ~/.local/share/chezmoi/dot_config/pipewire/pipewire.conf.d/51-micstudio-restore.conf ~/.config/pipewire/pipewire.conf.d/51-micstudio-restore.conf
rm ~/.local/share/chezmoi/dot_config/systemd/user/pipewire.service.wants/symlink_asus-speaker-dsp.service ~/.config/systemd/user/pipewire.service.wants/asus-speaker-dsp.service
systemctl --user daemon-reload
systemctl --user restart pipewire.service
```

To restore old binaries after removing the new restore integration:

```sh
install -m755 "$audit_backup/.local/bin/micstudio" ~/.local/bin/micstudio
install -m755 "$audit_backup/.local/bin/rogtui" ~/.local/bin/rogtui
```

The old MicStudio binary reintroduces the post-limiter gain defect. Project
source changes can be reverted by their explicit commits on the audit branches;
no history rewrite is required. Original documentation copies are also retained
under the backup directory. Tele requires no runtime rollback because its
installed binary was never replaced.

## Final verification addendum

Local source commits:

| Repository | Branch | Commits |
| --- | --- | --- |
| `~/micstudio` | `audit/microphone-input-safety-20261023` | `ea9a0b8`, `8259195` |
| `~/Projects/rogtui` | `audit/state-and-diagnostics-20261023` | `8ea021a` |
| `~/Projects/tele-sixel` | `feat/sixel-images` | `64ebafc`, `f1ae5cd` |

MicStudio and Tele working trees are clean. ROGTUI retains only the original
unstaged documentation edit. Chezmoi still has its original unrelated changes;
audit configuration changes are saved in its managed source, match their live
targets, and have scoped backups. Nothing was pushed.

After the final audio startup change, repeated PipeWire restart tests restored
saved +5 dB input gain, unity output gain, one capture/source pair, and active
speaker DSP. Final silent game/desktop route checks and the four launcher
scenarios passed. Audio doctor again reported zero errors and warnings. Both
service managers reported zero failed units, no recent audio error-priority
journal entries were found, and the display remained `eDP-2` at 165.004 Hz.
Memory PSI remained zero; the Btrfs read-error counter remained four.
The final read-only scrub completed with no errors over 88.11 GiB.

## Continuation verification

Completed the remaining Tele lint and renderer checks. Evidence is retained in
`~/.local/state/workstation-audit/20261023/tele-lint-current-upstream.log`,
`sixel-visual-results.json`, `sixel-visual-run.log`, the `sixel-*.png` screenshots,
and `test_sixel_visual.py`. The candidate executable remains in that private
artifact directory. The temporary linter archive and executable were removed
after recording release version and checksum verification. Both the feature
branch and installed Tele binary were preserved; no account data or credentials
were used in these checks. No additional persistent system configuration was
changed during this continuation.

## Tele screenshot follow-up and publication

The user's later screenshots prompted a full TUI reproduction. Side-by-side
images are normal album layout. Badge cropping had shifted the first-row
marker without narrowing its image, producing detached strips outside tiles.
This was corrected along with stale encode/write guards, exact partial-band
height, and serialized cleanup. A renderer optimization required changing the
view identity after ClearScreen to ensure a pending erase was flushed.

[Upstream PR #318](https://github.com/sorokin-vladimir/tele/pull/318) is open from
`kmanisk:feat/sixel-images`, head `c8b87e0`. The user's explicit later instruction
authorized publication; no private audit artifacts were published. No GitHub
checks were reported at the final query.

The installed binary is now `1.11.13+sixel.7800516`, built from a separate local
backport at `~/Projects/tele-sixel-stable`, commit `7800516`. All 715 files outside
the original Sixel change matched the saved original source baseline; current
upstream main was not deployed. Both branches passed full tests, vet, lint,
formatting/whitespace checks, and actual Bubble Tea/Foot screenshot comparisons
with Go's race detector. A private test-fixture close action was corrected to
match the real close action before recording the successful results.

The previous binary is backed up at
`~/.local/state/workstation-audit/20261023/backups/.local/bin/tele-before-polish`.
An application restart is needed to load the new executable; existing processes
were not stopped. The final installed hash and source provenance are recorded
in `tele-install.json`. No authenticated Telegram workflow or long-session
memory test was performed. See [current Tele status](tele-sixel.md) for details
and the exact rollback command. Earlier report statements about the original
binary remaining installed describe the audit before this follow-up.
