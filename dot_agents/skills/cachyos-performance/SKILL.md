---
name: cachyos-performance
description: System-level performance guidelines, package management, dual-GPU offloading, Btrfs tuning, gaming reliability, and resource-minimal architecture for CachyOS.
version: 1.1.0
---

# CachyOS & Performance Architecture Guidelines

## Core Objective

The system is optimized for:

* Maximum gaming performance and frame-time consistency.
* Low idle CPU usage and minimal background wakeups.
* Low resident RAM consumption.
* Minimal unnecessary disk usage.
* Low subprocess creation and IPC overhead.
* Fast terminal-first workflows.
* Reliable operation over feature count.
* No unnecessary Electron/web-app wrappers, animations, transparency, blur, or persistent GUI helpers.

Performance claims must distinguish between:

* CPU utilization
* RAM usage
* wakeups/context switches
* disk/storage consumption
* latency/frame-time effects

Never describe a process as having "zero overhead" without measuring it on the actual machine.

---

## Hardware & Architecture Rules

* **CPU Architecture:** x86-64-v3.
* Prefer packages from CachyOS optimized repositories when an equivalent package is available.
* Do not assume every package has a v3 build; verify repository availability before choosing an alternative package source.
* **Kernel:** Prefer Linux-CachyOS with its configured scheduler and CachyOS optimizations. Do not replace it with generic `linux` unless debugging a specific regression.
* **Desktop:** Sway + Wayland.
* **Primary GPU:** Intel integrated GPU for the desktop/session where practical.
* **Discrete GPU:** NVIDIA RTX 5050 Mobile for GPU-heavy applications and games through PRIME render offload.
* Prefer:

  ```bash
  prime-run <application>
  ```

  or the equivalent NVIDIA PRIME offload environment when required.
* Do not force the NVIDIA GPU to remain active for the whole desktop session when offload is sufficient.

---

## Package Management & Safety Guardrails

* **Forbidden:** Never run:

  ```bash
  pacman -Sy
  ```
* Prefer a complete system upgrade:

  ```bash
  sudo pacman -Syu
  ```
* Use CachyOS package/repository tooling where appropriate.
* Prefer repository packages over AUR when an equivalent optimized package is already available.
* Use `paru` for AUR packages when necessary.
* Avoid unnecessary `-git` packages when a stable repository package satisfies the requirement.
* Minimize duplicate implementations of the same functionality.
* **Mandatory Pre-Completion Verification & Collision Audit:**
  - Before declaring any task complete or configuration modification finished, ALWAYS run live configuration syntax validation (e.g., `sway -C`, `systemd-analyze verify`, `shellcheck`, `python3 -m py_compile`).
  - Actively audit for duplicate or shadowed keybindings (e.g., `grep bindsym` across root and modal scopes in Sway/i3).
  - Check service health with `systemctl --user status <service>` and inspect journal logs for recent errors.
  - Test live reload (`swaymsg reload`) and confirm no warnings or regressions. Fix all issues before finishing.

---

## Modular Configuration & Token Efficiency

To minimize context window token usage and latency for AI agents and human maintainers:
* **Modular Configuration Layout:** Avoid monolithic multi-hundred-line configs. Break configurations into discrete, single-responsibility files inside `<app>.d/` or `conf.d/` subdirectories:
  * **Sway Window Manager:** `~/.config/sway/config.d/` (`00-variables.conf`, `10-display.conf`, `20-input.conf`, `30-window-rules.conf`, `40-keybindings.conf`, `50-gaming-mode.conf`, `60-autostart.conf`, `70-bar.conf`).
  * **Fish Shell:** `~/.config/fish/conf.d/` (`00-env.fish`, `10-prompt.fish`, `20-aliases.fish`, `30-bindings.fish`, `40-login.fish`) and lazy-loaded standalone functions in `~/.config/fish/functions/*.fish`.
* **Targeted Agent Inspection:** Agents MUST only inspect the specific modular file relevant to their task rather than reading the entire root configuration, drastically accelerating reasoning and reducing prompt token overhead.

---

## Gaming Runtime Policy

### GPU Offload

For NVIDIA offload:

```bash
prime-run <game>
```

Do not add extra wrappers unless they provide a measurable benefit or are required for compatibility.

### GameMode vs ananicy-cpp

Do **not** automatically combine:

```bash
gamemoderun
```

with:

```text
ananicy-cpp
```

Current CachyOS gaming guidance explicitly warns against combining them because both can modify process niceness and may conflict.

Default policy:

* If `ananicy-cpp` is active, do not automatically add `gamemoderun`.
* If GameMode is required and verified beneficial, stop/disable `ananicy-cpp` for that gaming session or configuration.
* Do not claim either approach is universally faster; benchmark frame-time consistency and CPU behavior on the actual system.

Use the smallest working launch command.

Example with PRIME only:

```bash
prime-run %command%
```

Do not stack wrappers purely because they are commonly recommended.

---

## Proton Policy

* Prefer `proton-cachyos` when it provides the required compatibility.
* Verify compatibility before switching Proton versions for a game that is already stable.
* Avoid unnecessary Proton environment variables.
* Keep launch options minimal.
* Add debugging variables only while diagnosing a specific problem.

---

## Filesystem & Btrfs Rules

### General CoW Policy

Do not blanket-disable Btrfs Copy-on-Write for the entire Steam library.

Btrfs NOCOW has trade-offs:

* disables data checksumming for those files
* disables compression
* changes writes to in-place updates
* can benefit workloads with frequent overwrites

These properties make NOCOW useful for selected high-write workloads, but not universally beneficial for ordinary game binaries.

### Appropriate NOCOW Targets

Consider NOCOW for workloads such as:

* VM disk images
* frequently rewritten large files
* specific database/workspace workloads
* other workloads where repeated overwrites are demonstrated to benefit from in-place updates

Benchmark before making broad filesystem changes.

### Steam Libraries

Do not automatically apply:

```bash
chattr +C
```

to an entire Steam library.

If a specific workload benefits from NOCOW, apply it to a dedicated directory **before files are created**.

Important: setting `+C` on a directory affects newly created files beneath that directory; it does not retroactively convert existing file data.

---

## Btrfs Swapfile Policy

Btrfs swapfiles have stricter requirements than ordinary files.

A supported Btrfs swapfile must:

* be preallocated
* use NODATACOW
* have no compression
* reside on a suitable single-device/single-data-profile filesystem
* not be inside a snapshot-able subvolume while active

These restrictions are documented by both Btrfs and Arch Linux.

Prefer the native helper when available:

```bash
btrfs filesystem mkswapfile
```

rather than relying on an arbitrary generic file-creation procedure.

For larger systems, a dedicated swap subvolume that is excluded from snapshots is preferable because an active swapfile prevents snapshotting of the containing subvolume.

---

## Service & Background Process Policy

### Core Principle

Prefer:

1. Application-native functionality.
2. Existing compositor/session functionality.
3. One-shot CLI commands.
4. Event-driven native helpers.
5. Small compiled resident processes when runtime monitoring is genuinely required.
6. Interpreted polling only as a last resort.

Do not add a daemon when a native event-driven or on-demand implementation already solves the problem.

### Essential Services

A service is justified when it provides functionality required continuously by the desktop or hardware.

For this system, PipeWire/WirePlumber are core audio infrastructure.

`udiskie` is conditional rather than universally required; keep it only when automatic removable-device handling is actually needed.

`ananicy-cpp` is optional performance infrastructure, not a fundamental requirement of Linux or Sway.

### Resident Process Discipline

No nonessential resident process should be kept running merely for convenience.

Minimize:

* periodic wakeups
* subprocess creation
* D-Bus traffic
* IPC
* JSON parsing
* filesystem polling
* timers
* background GUI processes
* tray utilities
* web runtimes
* Electron applications

A small binary is preferred over a large interpreted process when a resident component is unavoidable.

RAM and CPU usage must be measured rather than assumed from executable size.

---

## Persistent Process & Polling Discipline

* Prefer no additional resident process when an existing application, compositor, or system component can provide the required functionality.
* Prefer one-shot commands for static operations.
* Prefer event-driven APIs for runtime behavior.
* When runtime monitoring is unavoidable, prefer native event mechanisms such as:

  * Wayland protocol events
  * PipeWire events
  * D-Bus signal subscriptions
  * epoll
  * eventfd
  * native filesystem notifications
* Never use periodic shell/Python polling when an event-driven alternative exists.
* Avoid recurring commands such as:

  ```text
  pw-dump
  swaymsg -t get_*
  playerctl
  pactl
  ps
  ```

  inside timer loops unless no practical event-driven alternative exists.
* Never run full JSON dumps every few seconds merely to determine whether something changed.
* Prefer `playerctl --follow` over repeated `playerctl` invocations when MPRIS monitoring is needed.
* Prefer Wayland idle-inhibit mechanisms over custom polling.
* If a resident compiled helper is introduced, measure:

  * idle CPU
  * resident RAM
  * wakeups
  * context switches
* Do not call a resident service "zero overhead" unless measurements justify that wording.

---

## Sway Idle Management

Prefer the following hierarchy:

```text
Application-native Wayland idle inhibit
        ↓
Sway-native idle inhibition / compositor mechanisms
        ↓
Small compiled event-driven helper
        ↓
D-Bus signal subscription
        ↓
Polling
```

Do not implement media detection using a loop such as:

```bash
while true; do
    pw-dump
    sleep 5
done
```

That approach unnecessarily causes:

* process launches
* PipeWire queries
* JSON generation
* JSON parsing
* periodic CPU wakeups

An event-driven implementation is preferred.

Sway exposes native idle-inhibit support and can represent whether a window is currently inhibiting idle.

---

## Audio Pipeline

* Prefer stock PipeWire + WirePlumber.
* Do not add audio DSP daemons unless a measurable requirement exists.
* Avoid duplicate audio routing layers.
* Remove unnecessary audio processing services that consume CPU continuously.
* Prefer hardware acceleration or native PipeWire functionality where appropriate.

---

## Visual Performance Policy

For maximum gaming performance and minimal compositor overhead:

* Disable unnecessary animations.
* Disable blur.
* Disable transparency when it provides no functional benefit.
* Avoid compositor shaders that run continuously.
* Avoid animated wallpapers.
* Avoid persistent visualizers unless actively being used.
* Prefer static rendering.
* Keep Sway configuration simple.
* Do not add visual effects merely for aesthetics when they introduce measurable GPU or CPU activity.

Performance-sensitive visual features should be benchmarked rather than judged purely by appearance.

---

## Display & Dual-GPU Policy

* Keep the Intel GPU responsible for the normal Sway desktop when the hardware topology permits.
* Keep the NVIDIA GPU power-gated/offloaded when idle.
* Launch GPU-heavy programs explicitly with PRIME offload.
* Do not force the NVIDIA GPU into the compositor unless required for a specific application or hardware configuration.
* Avoid unnecessary Xwayland or GPU copies when native Wayland support is available and stable.

---

## Autologin / Session Architecture

Prefer lightweight session startup over a large graphical display manager when operationally practical.

A getty-based login/session setup is generally lighter than a full desktop-oriented display manager, but it is not literally zero-memory overhead.

Do not describe any persistent login process as "0 MB" unless measured.

---

## Memory Management

* Prefer the existing CachyOS/systemd memory-management configuration.
* Do not manually tune OOM thresholds without a reproducible reason.
* Avoid unnecessary RAM-resident helpers.
* Prefer zram/system mechanisms already provided by the distribution before installing duplicate swap/cache managers.
* Diagnose memory pressure with actual measurements before changing policy.

---

## Btrfs Snapshot Hygiene

* Keep only stable, useful snapshots.
* Avoid accumulating large numbers of transient snapshots.
* Prefer Snapper for snapshot management.
* Do not manually delete snapshot subvolumes unless the operation is understood and verified.
* Measure filesystem usage with Btrfs-aware tools rather than relying only on `df`.
* Use:

  ```bash
  btrfs filesystem usage /
  ```

  and, when appropriate:

  ```bash
  btrfs filesystem du -s /.snapshots/*/snapshot
  ```

Remember that shared CoW extents can make logical snapshot size very different from immediately reclaimable exclusive space.

---

## Benchmarking & Validation

Never assume a performance optimization works merely because it is theoretically lightweight.

When evaluating a persistent process or system change, measure before and after:

```bash
ps
pidstat
systemd-cgtop
cat /proc/<pid>/status
```

For graphical/game workloads also examine:

* frame-time consistency
* average FPS
* 1% low FPS where appropriate
* CPU utilization
* GPU utilization
* power draw
* temperature
* process wakeups

Prefer changes that improve measurable behavior without introducing instability.

---

## Research & Verification Protocol

For technical topics that can change with software releases:

* Verify current upstream documentation.
* Prefer primary sources:

  * official project documentation
  * upstream repositories
  * ArchWiki
  * CachyOS documentation
  * kernel/Btrfs documentation
* Check current package availability before recommending installation.
* Distinguish documented behavior from benchmark results.
* Do not extrapolate a result from one machine to another without qualification.
* When a behavior is version-dependent, record the relevant version.
* Persist verified architectural decisions and important edge cases in this skill file or the relevant project rules.

---

## Decision Rule

When choosing between two implementations with equivalent functionality:

```text
native > compiled > event-driven > on-demand > interpreted polling
```

and:

```text
existing process > additional process
```

and:

```text
measured benefit > theoretical benefit
```

The preferred solution is the one that provides the required functionality with the fewest resident processes, lowest wakeup rate, lowest RAM usage, lowest CPU usage, and least complexity while preserving reliability.
