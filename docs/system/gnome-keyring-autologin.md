# GNOME Keyring and Passwordless TTY1 Autologin

## Context and Root Cause

The workstation uses passwordless autologin at TTY1 via systemd unit override:
`/etc/systemd/system/getty@tty1.service.d/override.conf`:

```ini
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin onyx --noclear %I $TERM
```

When `agetty --autologin` authenticates the user, PAM (`/etc/pam.d/login`) executes without requesting a password (`PAM_AUTHTOK` is null).

The PAM module `pam_gnome_keyring.so`:
1. Requires the typed user password during the `auth` phase to decrypt `~/.local/share/keyrings/login.keyring`.
2. Under autologin, PAM logs: `gkr-pam: couldn't unlock the login keyring.`.
3. Consequently, `gnome-keyring-daemon` starts with the `login` collection in a locked state (`org.freedesktop.Secret.Collection.Locked: true`).

Whenever an application queried Secret Service over D-Bus (`org.freedesktop.secrets`):
- A graphical or background prompt was requested.
- In headless, CLI, subagent, or non-interactive terminal workflows (such as `git push` invoking `/usr/bin/gh auth git-credential`), no interactive PIN prompt could complete, causing the command to hang indefinitely on D-Bus `poll()` calls.

## Permanent Resolution

Two complementary layers permanently eliminate lockouts, hangs, and prompts:

### 1. GNOME Keyring Blank Master Password (Auto-Unlock at Boot)

Under passwordless autologin, GNOME Keyring supports automatic unlocking when the keyring password is set to empty/blank (`""`), as documented in official Arch Linux guidance:
- When `login.keyring` has a blank master password, `gnome-keyring-daemon` decrypts it immediately on startup at boot.
- The `Login` collection reports `Locked: 0` (`false`) from session start.
- Any desktop or CLI application requesting Secret Service receives credentials immediately without prompts or hangs.
- Threat model alignment: On a single-user workstation configured for passwordless autologin directly into a graphical desktop, files owned by `onyx` (mode `0600`) are accessible to processes running as that user. Sensitive master secrets remain in KeePassXC (`~/Sync/KeePass/vault.kdbx`).

Utility: `~/.local/bin/keyring-set-blank-password` (source: `dot_local/bin/executable_keyring-set-blank-password`):
- Uses D-Bus Secret Service `org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface` (`ChangeWithMasterPassword`) to change the keyring password to blank without deleting existing keys or exposing passwords to logs.

### 2. Direct GitHub CLI Credential Storage (Zero-D-Bus Immunity)

To guarantee that Git operations (`git push`, `git pull`, `git fetch`) never depend on or hang on desktop daemons or D-Bus:
- `~/.config/gh/hosts.yml` stores the GitHub OAuth token directly with permissions `0600`:
  ```yaml
  github.com:
      oauth_token: gho_...
      user: kmanisk
      git_protocol: https
  ```
- GitHub CLI (`gh` and `gh auth git-credential`) reads the token directly from `hosts.yml`.
- Secret Service queries are completely bypassed during git operations, executing credential resolution in under 10 ms.

## Verification

- `login.keyring` unlocked status: `python3 -c "import dbus; bus=dbus.SessionBus(); col=bus.get_object('org.freedesktop.secrets', '/org/freedesktop/secrets/collection/login'); print(col.Get('org.freedesktop.Secret.Collection', 'Locked', dbus_interface='org.freedesktop.DBus.Properties'))"` returns `0`.
- Manual lock/unlock roundtrip: locked with `Lock()`, then unlocked cleanly with empty password struct via `UnlockWithMasterPassword`.
- GitHub CLI status: `gh auth status` returns `✓ Logged in to github.com account kmanisk (/home/onyx/.config/gh/hosts.yml)`.
- Git credential resolution: `printf "protocol=https\nhost=github.com\n\n" | /usr/bin/gh auth git-credential get` returned username and token instantly.
- Live Git push: `git push origin master` in `~/.local/share/chezmoi` completed without delays or prompts.
