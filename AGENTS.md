# AI System Rules — CachyOS + i3wm/X11 Gaming Laptop

**Target machine:** CachyOS rolling (BORE/EEVDF, x86-64-v3) · i3wm (X11) @ 1920x1200 165Hz
**Hardware:** Intel i5-13450HX + GeForce RTX 5050 Mobile (Optimus hybrid) · Btrfs on NVMe · fish + zsh + alacritty

Save this file as **`AGENTS.md`** in your project root for per-project rules, or
**`~/.gemini/AGENTS.md`** for it to apply globally across every project — Antigravity CLI
reads both automatically, no flag or registration step needed. (If you also use Claude Code
or Cursor, both of those now read `AGENTS.md` too, so this one file covers all three.)

---

## 1. Global Behavior Rules

- **Token discipline:** never print full config files or command dumps unless asked. Use
  unified diffs or targeted line replacements for dotfile edits.
- **No unverified "verified" claims.** Before reporting a package, MCP server, or tool as
  installed/working, actually check (`pip show`, `npm ls -g`, `which`, or the real repo page).
  Don't report specific version numbers you haven't confirmed.
- **Accurate performance language.** Say tearing/`immediate` window rules *reduce* input
  latency — never claim they bring it to "zero."
- **Snapshot before system changes.** Before `pacman -Syu`, `yay`, `paru`, or any package
  install/removal, confirm a Snapper pre-update snapshot exists or trigger one first.
- **Never run `pacman -Sy`** (partial upgrade risk) — always `pacman -Syu`.
- **Never put a raw secret/token in this file or in any command it runs.**
- **Mandatory Pre-Completion Verification & Collision Audit:** Never report a task complete without actively validating configs, services, and scripts. For Sway/i3, always run `sway -C`, audit for duplicate or shadowed keybindings across modes/scopes, and test live reload (`swaymsg reload`). For systemd units, check `systemctl --user status` and journal logs. For scripts, run syntax checks. Fix all regressions and collisions before marking the task done.

---

## 2. Dynamic GPU Architecture (Intel iGPU + RTX 5050 Mobile MUX)

The machine supports dynamic switching via `supergfxctl` across three distinct architectures:

1. **Integrated (`Integrated`)**:
   - Desktop and apps run on Intel UHD Graphics (`LIBVA_DRIVER_NAME=iHD`).
   - Hardware vibrance via Intel CRTC CTM (`ctm-test`).
   - No NVIDIA offload variables; dGPU remains powered down.

2. **Hybrid (`Hybrid`)**:
   - Desktop and 2D apps run on Intel UHD Graphics for idle power/thermals (`LIBVA_DRIVER_NAME=iHD`).
   - Hardware vibrance via Intel CRTC CTM (`ctm-test`).
   - Games/3D/CUDA offload explicitly via `prime-run` (`__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia`).
   - dGPU suspended (D3cold) until an offloaded workload requests it.

3. **Direct dGPU MUX (`AsusMuxDgpu`)**:
   - RTX 5050 Mobile connects directly to eDP-1 internal panel (hardware MUX bypasses iGPU).
   - Desktop compositor (Sway) and video decode run on NVIDIA (`LIBVA_DRIVER_NAME=nvidia`).
   - Hardware vibrance via NVIDIA NVKMS direct ioctl (`nvibrant`).
   - No Intel VA-API forcing (`iHD`), no Intel CTM attempts, and no redundant PRIME offload variables in game launchers (`cs2-launch`).

*(Note: Do not combine `gamemoderun` with `ananicy-cpp` unless ananicy-cpp is stopped/disabled for that session).*

---

## 3. i3 Window Rules (Gaming)

```ini
for_window [class="^steam_app_.*$"] fullscreen enable
```

---

## 4. Btrfs / Snapper Safety

- `chattr +C` (no-CoW) only affects files written **after** it's set. For an existing Steam
  library: move the data out, `chattr +C` the empty directory, move the data back in.
- If granting an agent sudo access to `snapper`/`btrfs`: **scope the sudoers rule to specific
  snapper subcommands** (e.g. `create`, `list`, `rollback`), not a blanket passwordless `btrfs`
  binary. Raw `btrfs` can delete subvolumes and snapshots outright — don't hand that out
  passwordless.

---

## 5. MCP Server Configuration

Prefer official, narrow servers over large custom ones — lower token overhead, easier to audit.

```json
{
  "mcpServers": {
    "official-filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem",
                "~/.local/share/chezmoi", "~/.config"]
    },
    "official-git": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-git"]
    },
    "official-fetch": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"]
    },
    "official-github": {
      "command": "~/.local/bin/github-mcp-wrapper",
      "args": []
    }
  }
}
```

Before adding any third-party MCP server (btrfs-snapper, systemd, gpu-tuning, steam, etc.),
confirm it's real: check the actual PyPI/npm/GitHub page, not just a name someone mentioned.

---

## 6. Secret Handling (chezmoi + age)

**Never commit a plaintext token** — not even as a placeholder — as an unencrypted source file.
Since you're using chezmoi's `age` encryption, fill in the real token locally, then add the
*whole file* as encrypted, rather than templating a password-manager call:

```bash
chezmoi add --encrypt ~/.config/mcp/mcp_config.json
```

This stores it in your source repo as an `encrypted_` file (ASCII-armored age ciphertext) and
`chezmoi apply` decrypts it automatically using the identity/recipient set in
`~/.config/chezmoi/chezmoi.toml` (`encryption = "age"`, plus your `[age] identity` /
`recipient`). To edit it later, use `chezmoi edit` — it decrypts, opens your editor, and
re-encrypts on save. Never run a plain `chezmoi add` on this file once it contains the real
token.

---

## 7. Community Tools — Verify Before Trusting

Any third-party MCP server or "community-vetted" server list should be checked against
its real package/GitHub page (commit activity, real usage) before wiring it in — not taken on
the strength of a description alone.

---

## 8. Efficiency, Anti-Bloat & Research Philosophy

- **Resource discipline:** Save disk space, RAM, and CPU cycles above all else. Retain what matters (responsiveness, latency, stability) rather than flashy animations, bloated eye-candy, or heavy background daemons.
- **Headless services:** System features (such as autologin, clipboard) must run headless in the background; never require manual GUI interaction to activate essential system functions.
- **Btrfs snapshot pruning:** Keep only verified stable baselines. Do not allow dozens of transient package snapshots to consume exclusive disk space.
- **Fact-checked research via headless browser:** When researching technical solutions, driver quirks, or configurations, perform live web searches and headless browser fetches. Record verified outcomes in markdown skill files (`SKILL.md`) for persistent cross-session knowledge.
- **Modular configuration & token efficiency:** Configurations must be structured modularly in subdirectories (e.g. `~/.config/sway/config.d/`, `~/.config/fish/conf.d/`). Agents must inspect only the relevant submodule file rather than dumping or reading full multi-hundred-line monolithic files.

---

## 9. MangoHud Protection

- **Never modify `~/.config/MangoHud/MangoHud.conf`**. The configuration is managed by chezmoi (`pci_dev=0000:01:00.0`, custom colors, font, and scaling).
- Keep `~/.config/MangoHud/MangoHud.conf` protected (immutable) so GUI tools like Goverlay cannot overwrite it.
