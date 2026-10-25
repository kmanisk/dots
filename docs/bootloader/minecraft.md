# Bootloader — Minecraft Boot Stack (MineGRUB + Minecraft Plymouth)

**Theme:** Minecraft end-to-end — MineGRUB World Selection menu through Minecraft Plymouth (`mc`) splash.  
**Status:** Preserved baseline boot stack. Full assets and configuration backed up at `~/.backup/minecraft-boot-20261003/`.

---

## 1. Architecture & Boot Sequence

```text
UEFI Firmware
  ↓
GRUB 2.12 (MineGRUB World Selection theme @ 1920x1200)
  ↓
Linux Kernel + initramfs (mkinitcpio 42.1)
  ↓
Plymouth Boot Splash (Theme: `mc` — "Loading world...", dirt background, pixel progress)
  ↓
Clean graphical handoff
  ↓
Getty TTY1 autologin → Sway (Wayland)
```

The boot sequence creates a unified visual experience of selecting a Minecraft world in GRUB and seeing the world loading screen during early userspace before Sway starts.

---

## 2. GRUB Configuration (`minegrub-world-selection`)

| Setting | Value | Source |
| :--- | :--- | :--- |
| **Theme** | `minegrub-world-selection` | `GRUB_THEME` in `/etc/default/grub` |
| **Background** | `dirt.png` | `GRUB_BACKGROUND='/boot/grub/themes/minegrub-world-selection/dirt.png'` |
| **Resolution** | `1920x1200,auto` | `GRUB_GFXMODE` (native panel, unscaled pixel-perfect text) |
| **Timeout / Style**| `3` / `menu` | `GRUB_TIMEOUT=3`, `GRUB_TIMEOUT_STYLE=menu` |
| **Theme Files** | `/boot/grub/themes/minegrub-world-selection/` | Upstream: [Lxtharia/minegrub-theme](https://github.com/Lxtharia/minegrub-theme) |
| **Fonts** | `Minecraft Regular 30`, `Monocraft Regular 22` | Embedded in theme directory |

### Key `/etc/default/grub` Settings for Minecraft:
```bash
GRUB_DEFAULT=0
GRUB_TIMEOUT=3
GRUB_TIMEOUT_STYLE=menu
GRUB_DISTRIBUTOR='CachyOS'
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nowatchdog nvme_load=YES loglevel=3 vt.global_cursor_default=0 i915.enable_psr=0 acpi_backlight=native nvidia.NVreg_RegistryDwords=EnableBrightnessControl=1"
GRUB_GFXMODE=1920x1200,auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_THEME='/boot/grub/themes/minegrub-world-selection/theme.txt'
GRUB_BACKGROUND='/boot/grub/themes/minegrub-world-selection/dirt.png'
GRUB_DISABLE_SUBMENU='true'
```

---

## 3. Plymouth Splash (`mc`)

| Component | Specification |
| :--- | :--- |
| **Active Theme** | `mc` (`plymouth-set-default-theme mc`) |
| **Upstream** | [nikp123/minecraft-plymouth-theme](https://github.com/nikp123/minecraft-plymouth-theme) |
| **Location** | `/usr/share/plymouth/themes/mc/` |
| **Initramfs Tool** | **`mkinitcpio`** (`mkinitcpio 42.1`) — dracut is absent |
| **Hook File** | `/etc/mkinitcpio.conf.d/minecraft-plymouth.conf` |
| **Font Config** | `/usr/share/fonts/OTF/Minecraft.otf`, `/etc/fonts/conf.d/00-minecraft.conf` |

### `minecraft-plymouth.conf` Dependencies:
The Minecraft Plymouth theme uses pango/cairo text rendering for authentic pixel typography, requiring explicit library hooks in the initramfs:
```bash
FILES+=(
  /usr/lib/plymouth/script.so
  /usr/lib/plymouth/text.so
  /usr/share/fonts/OTF/Minecraft.otf
  /etc/fonts/fonts.conf
  /etc/fonts/conf.d/00-minecraft.conf
  /usr/lib/plymouth/label-pango.so
  /usr/lib/libcairo.so.2
  /usr/lib/libfontconfig.so.1
  /usr/lib/libfreetype.so.6
  /usr/lib/libharfbuzz.so.0
  /usr/lib/libpango-1.0.so.0
  /usr/lib/libpangocairo-1.0.so.0
  /usr/lib/libpangoft2-1.0.so.0
  /usr/lib/libpng16.so.16
  /usr/lib/libply-splash-core.so.5
  /usr/lib/libply.so.5
)
```

---

## 4. Activation Procedure (Switch from Dark Souls to Minecraft)

To activate the Minecraft boot stack at any time:

```bash
# 1. Restore GRUB configuration and theme
sudo cp ~/.backup/minecraft-boot-20261003/grub /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

# 2. Swap Plymouth initramfs hooks
sudo rm -f /etc/mkinitcpio.conf.d/99-ds3-plymouth.conf
sudo cp ~/.backup/minecraft-boot-20261003/minecraft-plymouth.conf /etc/mkinitcpio.conf.d/

# 3. Set Plymouth theme to 'mc' and rebuild all initramfs presets
sudo plymouth-set-default-theme -R mc

# 4. Verify Plymouth active theme
plymouth-set-default-theme
```

---

## 5. Reverting to Dark Souls III Boot Stack

To return to the Dark Souls boot stack:

```bash
# 1. Update GRUB theme to grubsouls
sudo sed -i 's|GRUB_THEME=.*|GRUB_THEME=/boot/grub/themes/grubsouls/theme.txt|' /etc/default/grub
sudo sed -i '/GRUB_BACKGROUND=/d' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

# 2. Swap Plymouth initramfs hooks
sudo rm -f /etc/mkinitcpio.conf.d/minecraft-plymouth.conf
sudo cp ~/.backup/minecraft-boot-20261003/../... /etc/mkinitcpio.conf.d/99-ds3-plymouth.conf

# 3. Set Plymouth theme to 'ds3' and rebuild initramfs
sudo plymouth-set-default-theme -R ds3
```

---

## 6. Backup Inventory

All original Minecraft boot stack files are preserved intact at:
`~/.backup/minecraft-boot-20261003/`

- `grub`: Full working `/etc/default/grub` for MineGRUB
- `minegrub-world-selection/`: Complete GRUB theme directory (background, icons, fonts)
- `minecraft-plymouth.conf`: Working mkinitcpio configuration for font/pango assets
- `99-minecraft-plymouth.conf`: Secondary override hook
- `plymouth-theme.txt`: Theme identifier (`mc`)
- `mkinitcpio.conf`: Reference mkinitcpio configuration
