# Password Manager and Credential Sync

## Current baseline

The workstation uses KeePassXC on Linux with Syncthing for private cross-device database replication.

- Linux password manager: `keepassxc`.
- Sync engine: `syncthing.service`, deliberately disabled at boot and started only for short sync windows.
- Synced directory: `~/Sync/KeePass/`.
- Intended database path: `~/Sync/KeePass/vault.kdbx`.
- Syncthing folder ID: `keepass-vault`.
- Folder type: send/receive.
- Filesystem watcher: enabled with a 1-second delay while the short sync window is active.
- Versioning: simple versioning, keep 10 historical versions, cleanup interval 3600 seconds.
- Syncthing GUI: localhost only at `127.0.0.1:8384` unless the user explicitly changes it.

The database itself, its master password, recovery material, and any optional keyfile are user secrets and must never be committed to this repository.

## On-demand sync policy

Syncthing is not a persistent workstation daemon. `~/.local/bin/keepassxc-sync` performs a bounded sync before KeePassXC starts, stops Syncthing, runs KeePassXC, then performs another bounded sync after KeePassXC exits and stops Syncthing again. The user desktop entry shadows the packaged KeePassXC launcher so normal launcher use follows this path. `keepassxc-sync --sync-only` performs only one short synchronization window.

This means phone changes made while KeePassXC is already open are not continuously delivered to Linux. They arrive on the next sync window. This tradeoff is intentional to preserve the workstation's daemonless/on-demand design.

## Linux browser integration

KeePassXC browser integration is enabled in `~/.config/keepassxc/keepassxc.ini`.

Brave uses the native-messaging host:

`~/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts/org.keepassxc.keepassxc_browser.json`

The host launches `/usr/bin/keepassxc-proxy` and allows the official Chromium KeePassXC-Browser extension ID `oboonakemofpalcgghocfoadofidjkkk`. The extension itself still requires the browser's normal install/confirmation flow. After a database exists and is unlocked, connect the extension to that database from the extension popup.

Native Wayland Auto-Type is not the primary browser path. Use KeePassXC-Browser for Brave autofill.

## Android pairing

Use KeePassDX as the Android KDBX client and the maintained Syncthing Android fork as the sync layer. Pair the Android Syncthing device with this workstation and share only the `keepass-vault` folder. Open the synchronized `vault.kdbx` in KeePassDX rather than creating a separate database.

Retrieve the current workstation Syncthing device ID when needed with:

```sh
syncthing cli show system
```

Do not hardcode a runtime device ID into portable chezmoi configuration.

## Safety rules

- Keep a strong unique KeePass master passphrase outside the database.
- Do not sync an optional keyfile in the same Syncthing folder as `vault.kdbx`.
- Leave KeePassXC atomic saves enabled.
- Let Syncthing finish after edits before intentionally editing the same database on another device when practical.
- If Syncthing creates a conflict copy, preserve both files and merge with KeePassXC rather than deleting one blindly.
- Syncthing simple versioning is a recovery layer, not the only backup. Keep a periodic offline copy of the encrypted KDBX file.

## Rebuild contract

`packages/linux-core.txt` declares `keepassxc` and `syncthing`. `run_onchange_linux-20-reconcile-services.sh.tmpl` explicitly keeps `syncthing.service` disabled from persistent user startup. `run_onchange_linux-30-setup-keepass-sync.sh.tmpl` briefly starts Syncthing only when configuration repair is needed, creates `~/Sync/KeePass/`, preserves KeePassXC's dynamic INI while forcing `Browser/Enabled=true`, writes the Brave native-messaging host, repairs the `keepass-vault` folder with 10-version history, then stops the service again. `dot_local/bin/executable_keepassxc-sync` and the user KeePassXC desktop entry implement normal pre/post on-demand sync. The KDBX database itself is never created or managed by chezmoi.
