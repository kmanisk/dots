# Bootloader Documentation (`docs/bootloader/`)

This directory documents the visual boot stack configurations (GRUB menu themes, Plymouth splash screens, and mkinitcpio initramfs hooks) on the ASUS TUF Gaming F16 running CachyOS.

---

## Boot Stacks

| Boot Stack | Status | GRUB Theme | Plymouth Theme | Doc Link |
| :--- | :--- | :--- | :--- | :--- |
| **Dark Souls III** | **Active** | `grubsouls` (GrubSouls III menu) | `ds3` (FOT-Matisse-Pro font) | [`dark-souls-boot.md`](./dark-souls-boot.md) |
| **Minecraft** | **Preserved Baseline** | `minegrub-world-selection` | `mc` (Minecraft.otf pixel UI) | [`minecraft.md`](./minecraft.md) |

---

## Quick Toggle Between Themes

### Switch to Minecraft:
```bash
sudo cp ~/.backup/minecraft-boot-20261003/grub /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo rm -f /etc/mkinitcpio.conf.d/99-ds3-plymouth.conf
sudo cp ~/.backup/minecraft-boot-20261003/minecraft-plymouth.conf /etc/mkinitcpio.conf.d/
sudo plymouth-set-default-theme -R mc
```

### Switch to Dark Souls III:
```bash
sudo sed -i 's|GRUB_THEME=.*|GRUB_THEME=/boot/grub/themes/grubsouls/theme.txt|' /etc/default/grub
sudo sed -i '/GRUB_BACKGROUND=/d' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo rm -f /etc/mkinitcpio.conf.d/minecraft-plymouth.conf
sudo cp /etc/mkinitcpio.conf.d/99-ds3-plymouth.conf.bak /etc/mkinitcpio.conf.d/99-ds3-plymouth.conf 2>/dev/null || true
sudo plymouth-set-default-theme -R ds3
```
