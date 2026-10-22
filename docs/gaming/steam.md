# Steam Portable Launch Options and Runtime Architecture

This document defines the architecture and invariant patterns for configuring Steam game launch options on CachyOS, eliminating hardcoded user paths and ensuring portability across username migrations.

---

## 1. The Steam Runtime PATH Problem

When launching Linux native games or Proton Windows titles, Steam executes games inside a containerized runtime environment (Pressure-Vessel / Steam Linux Runtime).

During this process:
1. Steam sanitizes and overrides the process environment, resetting `$PATH` to standard system directories (`/usr/bin:/bin`).
2. User-level directories such as `~/.local/bin` and `~/.cargo/bin` are omitted from `$PATH` in the game's execution context.
3. Specifying bare command names like `cs2-launch %command%` fails immediately because the container cannot locate the binary.
4. Hardcoding absolute paths like `/home/<user>/.local/bin/cs2-launch %command%` works temporarily, but breaks completely upon username rename, home migration, or multi-user setup.

---

## 2. Universal Solution: The Shell Exec Wrapper

To resolve `$HOME` dynamically in the active user context before delegating execution to the target binary, launch options must invoke `/bin/sh` using `exec`:

```text
sh -c 'exec "$HOME/.local/bin/<script-name>" "$@"' -- %command%
```

### Breakdown of Mechanics:
* `sh -c '...'`: Spawns a standard POSIX shell inside the user session, guaranteeing dynamic evaluation of `$HOME` (e.g. `/home/onyx` or any other user home).
* `exec`: Replaces the shell process with the target executable, avoiding lingering parent shell processes or signal translation overhead.
* `"$@"`: Forwards all command-line arguments exactly as passed by Steam without word-splitting.
* `--`: Denotes the end of shell options, ensuring subsequent arguments are treated as positional parameters `$1`, `$2`, etc.
* `%command%`: Steam's macro that expands into the full game executable and its default engine flags.

---

## 3. Standard Patterns by Use Case

### A. Dedicated Launcher Script (e.g. CS2, Elden Ring, Dark Souls III)

```text
sh -c 'exec "$HOME/.local/bin/cs2-launch" "$@"' -- %command%
```

### B. Inline Environment Variables with Custom Script

When injecting runtime variables (such as MangoHud, vkBasalt, or PRIME offload) without hardcoding paths:

```text
sh -c 'exec env MANGOHUD=1 VKBASALT_CONFIG_FILE="$HOME/.local/share/goverlay/gameconfig/GameName/vkBasalt.conf" "$HOME/.local/bin/my-game-launch" "$@"' -- %command%
```

### C. Direct Game Execution with Mod/Shader Overrides

If launching directly through Proton with Wine DLL overrides:

```text
sh -c 'exec env WINEDLLOVERRIDES="dinput8=n,b;dxgi=n,b" gamemoderun prime-run "$@"' -- %command%
```

---

## 4. Game Configuration Registry

| Game | Launch Option Configuration | Target Executable |
| :--- | :--- | :--- |
| **Counter-Strike 2** | `sh -c 'exec "$HOME/.local/bin/cs2-launch" "$@"' -- %command%` | Native Linux Vulkan (`cs2-launch`) |
| **Sleeping Dogs: Definitive Edition** | `sh -c 'exec env MANGOHUD=1 ENABLE_VKBASALT=1 VKBASALT_CONFIG_FILE="$HOME/.local/share/goverlay/gameconfig/Sleeping Dogs_Definitive Edition/vkBasalt.conf" prime-run gamemoderun "$@"' -- %command%` | Proton DXVK |
| **Dark Souls III** | `sh -c 'exec "$HOME/.local/bin/darksouls3-run" "$@"' -- %command%` | Mod Engine 3 / ReShade Wrapper |
| **Elden Ring** | `sh -c 'exec "$HOME/.local/bin/eldenring-run" "$@"' -- %command%` | LSFG-VK / ModEngine2 Wrapper |

---

## 5. Verification Checklist

When configuring new titles in Steam:
1. Ensure the custom script lives in `~/.local/bin/` with executable permissions (`chmod 0755`).
2. Test script standalone in a terminal before assigning in Steam.
3. Apply the `sh -c 'exec "$HOME/.local/bin/<script>" "$@"' -- %command%` pattern in Steam Game Properties -> General -> Launch Options.
4. Launch the game from Steam and verify that `pgrep -a <script-name>` executes cleanly without hardcoded user dependencies.
