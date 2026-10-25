# Bootloader (Dark Souls Boot Stack)

**Theme:** Dark Souls, end to end — GrubSouls III menu through DS3 Plymouth splash.
**Backup:** `~/.backup/minecraft-boot-20261003/` (752K, pre-Dark-Souls Minecraft stack, 2026-10-03).

---

## 1. GRUB

| Setting | Value | Source |
|---------|-------|--------|
| Theme | `grubsouls` | `GRUB_THEME` in `/etc/default/grub` |
| Resolution | `1920x1200,auto` | `GRUB_GFXMODE` (native panel, no scaling blur) |
| Timeout / style | `3` / `menu` | Always show menu, 3s to interrupt |
| Theme files | `/boot/grub/themes/grubsouls/` | Cloned from `PedroMMarinho/grubsouls-theme`, static default background (no update service) |

After editing `/etc/default/grub`: `sudo grub-mkconfig -o /boot/grub/grub.cfg`.
Pre-minecraft original preserved as `/etc/default/grub.backup-before-minecraft-boot`
(copied into the backup dir).

Other installed themes (inactive): `minegrub`, `starfield`,
`cachyos-grub-theme` (packaged). Switch with the `grub-themes` script —
never GRUB Customizer.

## 2. Plymouth (initramfs splash)

| Setting | Value |
|---------|-------|
| Active theme | `ds3` (`plymouth-set-default-theme`) |
| Package | Unpackaged — cloned from `PedroMMarinho/plymouth-ds3` (font `FOT-Matisse-Pro.otf` + `00-matisse.conf` + theme dir) |
| Initramfs tool | **mkinitcpio** (`mkinitcpio 42.1`) — dracut is NOT installed |
| Hook-in | `/etc/mkinitcpio.conf.d/99-ds3-plymouth.conf` (adds pango/cairo/font + lib stack + `FOT-Matisse-Pro.otf`); `minecraft-plymouth.conf` retained untouched |

After theme/hook changes: `sudo mkinitcpio -P` to rebuild all presets.

> Note: `/etc/dracut.conf.d/99-minecraft-plymouth.conf` exists but is **inert**
> (dracut absent). Kept in backup for reference only.

## 3. Restore procedure

```bash
B=~/.backup/minecraft-boot-20261003
sudo cp "$B/grub" /etc/default/grub
sudo cp -r "$B/minegrub-world-selection" /boot/grub/themes/
sudo cp "$B/minecraft-plymouth.conf" /etc/mkinitcpio.conf.d/
sudo plymouth-set-default-theme -R mc   # rebuilds initramfs with theme
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

To revert to pre-minecraft boot entirely, use the
`*.backup-before-minecraft-boot` files (also in the backup dir).
