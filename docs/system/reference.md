# tufdots Reference & Machine Details

Detailed machine specifications, architecture, and keybindings for the ASUS TUF Gaming F16 (CachyOS + Sway).

---

## Machine Contract

* **Display:** `eDP-1` (1920×1200 @ 165Hz native 1:1)
* **GPU Offload:** Intel Raptor Lake iGPU (desktop session) + RTX 5050 Mobile (`prime-run` / `gamemoderun`)
* **Storage:** NVMe Btrfs root + `/mnt/Games` dedicated game filesystem
* **Audio:** ALC256 Dolby Atmos filter chain (`swh-plugins`) + Dusky Audio Studio (RNNoise DSP)
* **Boot:** UEFI → MineGRUB → Minecraft Plymouth → TTY1 autologin → Sway

---

## Keybindings (Essentials)

| Key | Action |
|---|---|
| `Win + Return` | Terminal (Alacritty) |
| `Ctrl + Space` / `Alt + \`` | Scratchpad terminal dropdown |
| `Win + n` | Scratchpad notes dropdown (`nvim ~/notes.md`) |
| `Win + m` | Spotify scratchpad dropdown |
| `Win + d` / `Alt + Space` | App launcher (Fuzzel) |
| `Win + b` | Web browser (Brave) |
| `Alt + Shift + S` / `Win + g` | Steam workspace (Workspace 3) |
| `Win + 4` | Games workspace (CS2 / Steam, tiled) |
| `Win + Shift + u / i / o / p` | Move window to ws 1–4 and follow |
| `Alt + Shift + n` | Night light toggle |
| `Ctrl + Alt + Del` | Emergency game kill switch |
