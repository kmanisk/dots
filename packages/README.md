# Package Manifests (tufdots / CachyOS)

Declarative package sets, auto-installed by
`run_onchange_linux-00-reconcile-packages.sh.tmpl` based on the machine profile
in `.chezmoidata.toml`.

| File | Purpose | Source / Condition |
|---|---|---|
| `common.txt` | Baseline CLI tools (git, ripgrep, btop, yazi, neovim, uv, age, …) | Official / Always |
| `linux-core.txt` | System tools (base-devel, btrfs-progs, snapper, NetworkManager, thunar, …) | Official / Linux |
| `gaming.txt` | Steam, Gamescope, Gamemode, Mangohud, Goverlay | Official / `features.gaming = true` |
| `nvidia.txt` | NVIDIA dGPU drivers, 32-bit Vulkan/OpenCL | Official / `gpu_strategy = "hybrid-optimus-d3cold"` |
| `asus.txt` | asusctl, supergfxctl | Official / `features.asus_ctl = true` |
| `sway.txt` | Sway desktop stack (mako, fuzzel, grim, slurp, brave-origin-bin, ImageMagick for curated wallpaper normalization) | Official / `features.sway = true` |
| `audio.txt` | PipeWire, WirePlumber, audio firmware, rnnoise | Official / audio provider starts with `pipewire` |
| `development.txt` | Compilers, runtimes, and native on-demand QEMU/KVM Windows virtualization (Node.js, Python, ccache, mold, QEMU, swtpm, FreeRDP) | Official / `features.development = true` |
| `aur-explicit.txt` | AUR packages (antigravity-cli, xremap, vkbasalt, lib32-vkbasalt) | AUR via paru / helper present |

`wallpapers/` and `systemd/enabled-units-reference.txt` are references only,
never installed automatically.
