# Sway Automatic Session Save/Restore

On-demand session persistence. Zero daemon, zero idle overhead, stdlib-only.

## How it works

```
Sway starts → normal init → one-shot restore (bounded IPC wait, then exits)
user works normally (no background process)
logout/reboot/shutdown begins → one-shot save → Sway exits
```

- Save: `sway-session-save` reads `swaymsg get_tree` + `/proc` cmdlines,
  writes `~/.config/sway/session/session.json` atomically (tmp + fsync +
  rename), copies the previous valid snapshot atomically to `session.json.prev`,
  and keeps the last 8 valid snapshots under `session/backups/`.
- Restore: `sway-session-restore` launches missing apps onto their saved
  workspaces via Sway IPC, then exits. Already-running apps are never
  duplicated. Foot terminals receive their saved cwd explicitly with
  `footclient -D`, so the shared Foot server cwd is never inherited.

## Why no daemon

A daemon would cost idle RAM and add shutdown races for no benefit: saving
takes <1s and is only needed at exit; restoring is only needed at startup.
Both are one-shot `exec` / `ExecStop` hooks that terminate immediately
(`pgrep -af sway-session` shows nothing after they complete).

## Why apps/workspaces, not layout trees

This Sway config forces fixed workspaces with tabbed layouts, so every
window on a workspace is a tab. Reconstructing nested split geometry
(`append_layout` trees) adds failure modes for zero visible benefit —
placing the right apps on the right workspaces reproduces the layout.

## Manual keybindings (unchanged)

| Keys           | Action                    |
|----------------|---------------------------|
| Alt+Shift+7    | Save all workspaces       |
| Alt+Shift+8    | Restore all workspaces    |
| Alt+Ctrl+7     | Save focused workspace    |
| Alt+Ctrl+8     | Restore focused workspace |

Status lines (`[session] saved/skipped/invalid/no running Sway session`)
go to stdout (journal for service runs) plus a desktop notification.

## Automatic hooks

- Startup: `exec sway-session-restore --all --quiet --wait-ready` in
  `~/.config/sway/config` — waits up to 5s for Sway IPC (no blind sleep),
  restores once, exits. No session → does nothing, startup never blocked.
- Graphical exit: `powermenu` saves first (Sway path on Wayland, i3 path
  on X11) before logout/reboot/shutdown. A manually typed `swaymsg exit`
  bypasses this and is NOT intercepted.
- systemd: `sway-session-save.service` (`--user`, oneshot,
  `RemainAfterExit`, `Before=shutdown/reboot/halt/exit.target`,
  `TimeoutStopSec=15`) runs the save during user-manager shutdown.
  Enabled via `run_onchange_linux-20-reconcile-services.sh`, same as the
  existing i3 unit. It self-discovers `SWAYSOCK` (no hardcoded UID/PID).

## Foot terminal cwd handling

With Foot client/server mode, every terminal surface reports the shared Foot
server PID to Sway. `/proc/<pid>/cwd` is therefore the server cwd, not the cwd of
the shell shown in that specific window. The saver recovers per-window cwd from
the Fish/Pure title (`<cwd> - fish` or `<cwd>: <command> - <current-command>`)
and falls back to `$HOME` when it cannot prove a terminal cwd. A plain ws1 shell
saved as `/` by the old server-PID implementation is migrated to `$HOME`; other
terminal directories and workspaces keep their exact cwd. Multiple Foot windows
are treated as valid multi-instance session entries.

## Failure behavior

- Empty/malformed tree, no Sway socket, or write error → save aborts,
  `session.json` untouched (exit 1).
- The current `session.json` is never moved away before a new snapshot is ready.
  Only a validated current snapshot is copied into `session.json.prev` and the
  bounded backup history; an invalid current file is never promoted to backup.
- Malformed/missing session on restore → reported, startup continues
  (exit 0).
- Crash: last good `session.json` is never overwritten by a bad snapshot.
- Restore prunes ghost containers (app identity but no window — e.g.
  unswallowed placeholders) before duplicate checks, so dead entries
  never suppress a real launch and never block the cold-boot fallback.

## Ported i3 behaviors (from git history)

The three lifecycle paths are a direct translation of the proven i3
architecture (original commit `f885a71`, refined through `693c3e0`,
`778261f`, `481aa6e`):

- Cold-boot fallback: `--all` restore guarantees a terminal on ws1 and
  a browser on ws2 when no session covered them (global presence check,
  never duplicates).
- Steam lifecycle: `--all` save maintains a `steam_was_killed` sidecar;
  restore never resurrects a deliberately killed Steam.
- Suspend intentionally does NOT save (matches i3 since `693c3e0` —
  suspend resumes the same session).
- A manually typed `swaymsg exit` bypasses the save wrappers, exactly
  like a manual `i3-msg exit` did on i3.

Deliberately not ported: `append_layout` tree reconstruction and the
placeholder watcher (unneeded under forced-tabbed workspaces),
`i3-session-menu` (i3-resurrect-based), X11-only `DISPLAY=:0`.

## Disabling

- Auto-restore: comment out the `sway-session-restore ... --wait-ready`
  `exec` line in `~/.config/sway/config`.
- Shutdown save: `systemctl --user disable --now sway-session-save.service`.

## Recovery

Immediate rollback still uses the previous valid snapshot:

```
cp ~/.config/sway/session/session.json.prev ~/.config/sway/session/session.json
sway-session-restore --all
```

For an older known-good state, inspect the bounded history and copy the desired
file into place before restoring:

```
ls -lt ~/.config/sway/session/backups/
cp ~/.config/sway/session/backups/session-YYYYMMDD-HHMMSS-ffffff.json \
  ~/.config/sway/session/session.json
sway-session-restore --all
```

Session state is runtime data and is NOT tracked by chezmoi
(`.chezmoiignore` excludes `.config/sway/session/**`); only the scripts,
unit, and config are versioned.
