#!/usr/bin/env python3
"""
thunar-folder-color.sh: Hook for theme-set to dynamically map theme colors
to the nearest Papirus folder color preset and update Thunar icon cache.
Runs strictly on-demand (zero daemon, zero background RAM/CPU).
"""
import os
import sys
import math
import subprocess

# Papirus canonical folder color definitions (RGB)
PAPIRUS_COLORS = {
    "blue": (0x42, 0xa5, 0xf5),
    "cyan": (0x00, 0xbc, 0xd4),
    "darkcyan": (0x00, 0x97, 0xa7),
    "teal": (0x00, 0x96, 0x88),
    "green": (0x4c, 0xaf, 0x50),
    "magenta": (0xe9, 0x1e, 0x63),
    "violet": (0x9c, 0x27, 0xb0),
    "indigo": (0x3f, 0x51, 0xb5),
    "red": (0xf4, 0x43, 0x36),
    "carmine": (0xd3, 0x2f, 0x2f),
    "orange": (0xff, 0x98, 0x00),
    "deeporange": (0xff, 0x57, 0x22),
    "yellow": (0xff, 0xeb, 0x3b),
    "grey": (0x9e, 0x9e, 0x9e),
    "bluegrey": (0x60, 0x7d, 0x8b),
    "nordic": (0x5e, 0x81, 0xac),
    "black": (0x37, 0x47, 0x4f),
    "white": (0xec, 0xef, 0xf1),
    "yaru": (0xe9, 0x54, 0x20),
}

def hex_to_rgb(hex_str):
    hex_str = hex_str.lstrip("#")
    if len(hex_str) == 3:
        hex_str = "".join([c * 2 for c in hex_str])
    return (int(hex_str[0:2], 16), int(hex_str[2:4], 16), int(hex_str[4:6], 16))

def color_distance(c1, c2):
    # Weighted Euclidean distance to align with human color perception
    r_mean = (c1[0] + c2[0]) / 2.0
    dr = c1[0] - c2[0]
    dg = c1[1] - c2[1]
    db = c1[2] - c2[2]
    return math.sqrt((2 + r_mean / 256.0) * (dr ** 2) + 4.0 * (dg ** 2) + (2 + (255 - r_mean) / 256.0) * (db ** 2))

def find_nearest_papirus(target_hex):
    target_rgb = hex_to_rgb(target_hex)
    best_color = "blue"
    min_dist = float("inf")
    for name, rgb in PAPIRUS_COLORS.items():
        dist = color_distance(target_rgb, rgb)
        if dist < min_dist:
            min_dist = dist
            best_color = name
    return best_color

def main():
    # Read active theme colors from ~/.local/state/theme/colors.sh
    colors_sh = os.path.expanduser("~/.local/state/theme/colors.sh")
    if not os.path.exists(colors_sh):
        sys.exit(0)

    color_vars = {}
    with open(colors_sh, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("export THEME_"):
                parts = line.split("=", 1)
                if len(parts) == 2:
                    k = parts[0].replace("export ", "").strip()
                    v = parts[1].strip("\"' ")
                    color_vars[k] = v

    # Pick dominant accent color
    target_hex = color_vars.get("THEME_ACCENT") or color_vars.get("THEME_SEL") or "#0080ff"
    
    # Specific overrides if desired
    theme_name = (color_vars.get("THEME_NAME") or "").lower()
    if "synthwave" in theme_name or "void" in theme_name:
        chosen = "violet"
    elif "nord" in theme_name:
        chosen = "nordic"
    elif "gruvbox" in theme_name:
        chosen = "green"
    elif "dracula" in theme_name:
        chosen = "magenta"
    elif "catppuccin" in theme_name:
        chosen = "violet"
    else:
        chosen = find_nearest_papirus(target_hex)

    # Apply to user-local Papirus theme without root
    try:
        res = subprocess.run(
            ["papirus-folders", "-C", chosen, "--theme", "Papirus"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        if res.returncode == 0:
            # Refresh Thunar if running so icons update immediately
            subprocess.run(["thunar", "-q"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

if __name__ == "__main__":
    main()
