#!/usr/bin/env python3
"""
Hook: 20-thunar-folder-color.py
Dynamically recolors Gruvbox-Plus-Dark folder icons to match the active system theme accent.
Execution time: ~30-50ms. Zero resident processes / daemons.
"""
import os
import sys
import re

THEME_STATE_DIR = os.path.expanduser("~/.local/state/theme")
COLORS_SH = os.path.join(THEME_STATE_DIR, "colors.sh")
STATE_ACCENT_FILE = os.path.join(THEME_STATE_DIR, "folder_accent")
ICON_THEME_DIR = os.path.expanduser("~/.local/share/icons/Gruvbox-Plus-Dark")

def get_target_accent():
    # If passed as command line argument or found in colors.sh
    if os.path.exists(COLORS_SH):
        try:
            with open(COLORS_SH, "r", encoding="utf-8") as f:
                for line in f:
                    m = re.match(r'export THEME_ACCENT="([^"]+)"', line.strip())
                    if m:
                        return m.group(1).strip()
        except Exception:
            pass
    return None

def main():
    target_accent = get_target_accent()
    if not target_accent or not target_accent.startswith("#"):
        return 0

    # Avoid redundant I/O if the accent is already applied
    if os.path.exists(STATE_ACCENT_FILE):
        try:
            with open(STATE_ACCENT_FILE, "r", encoding="utf-8") as f:
                current_accent = f.read().strip()
                if current_accent.lower() == target_accent.lower():
                    return 0
        except Exception:
            pass

    pattern = re.compile(r'(\.ColorScheme-Highlight\s*\{\s*color:\s*)[^;]+(;)')
    updated = False

    target_dirs = [
        os.path.join(ICON_THEME_DIR, "places/scalable"),
        os.path.join(ICON_THEME_DIR, "places/16")
    ]

    for d in target_dirs:
        if not os.path.isdir(d):
            continue
        for fname in os.listdir(d):
            if fname.endswith(".svg"):
                fpath = os.path.join(d, fname)
                if os.path.islink(fpath):
                    continue
                try:
                    with open(fpath, "r", encoding="utf-8", errors="ignore") as fp:
                        content = fp.read()
                    if ".ColorScheme-Highlight" in content:
                        new_content = pattern.sub(r'\g<1>' + target_accent + r'\2', content)
                        if new_content != content:
                            with open(fpath, "w", encoding="utf-8") as fp:
                                fp.write(new_content)
                            updated = True
                except Exception:
                    pass

    # Save state
    try:
        with open(STATE_ACCENT_FILE, "w", encoding="utf-8") as f:
            f.write(target_accent + "\n")
    except Exception:
        pass

    # Touch icon directory to notify GTK file managers
    if updated and os.path.exists(ICON_THEME_DIR):
        try:
            os.utime(ICON_THEME_DIR, None)
            cache_file = os.path.join(ICON_THEME_DIR, "icon-theme.cache")
            if os.path.exists(cache_file):
                os.utime(cache_file, None)
        except Exception:
            pass

    return 0

if __name__ == "__main__":
    sys.exit(main())
