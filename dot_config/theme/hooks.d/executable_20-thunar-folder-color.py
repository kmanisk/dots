#!/usr/bin/env python3
"""
Hook: 20-thunar-folder-color.py
Dynamically recolors Gruvbox-Plus-Dark folder icons to match the active system theme accent,
and enforces sharp, straight geometric edges (zero rounded corners).
Execution time: ~30-50ms on change, <1ms when cached. Zero resident processes / daemons.
"""
import os
import sys
import re

THEME_STATE_DIR = os.path.expanduser("~/.local/state/theme")
COLORS_SH = os.path.join(THEME_STATE_DIR, "colors.sh")
STATE_ACCENT_FILE = os.path.join(THEME_STATE_DIR, "folder_accent")
ICON_THEME_DIR = os.path.expanduser("~/.local/share/icons/Gruvbox-Plus-Dark")

STRAIGHT_FOLDER_BODY = """  <!-- Back flap -->
  <path class="ColorScheme-Highlight" d="M14 22H96L112 38H242V234H14Z" fill="currentColor"/>
  <!-- Back flap shadow -->
  <path d="M14 22H96L112 38H242V234H14Z" fill="#000000" opacity=".28"/>
  <!-- Top tab highlight -->
  <path d="M14 22H96L112 38H242V40H111L95 24H14Z" fill="#ffffff" opacity=".2"/>
  <!-- Front flap -->
  <path class="ColorScheme-Highlight" d="M14 72H104L120 56H242V234H14Z" fill="currentColor"/>
  <!-- Front flap top edge highlight -->
  <path d="M14 72H104L120 56H242V59H119L103 75H14Z" fill="#ffffff" opacity=".25"/>
  <!-- Bottom shadow -->
  <path d="M14 231H242V235H14Z" fill="#000000" opacity=".3"/>"""

STRAIGHT_OPEN_FOLDER_BODY = """  <!-- Back flap -->
  <path class="ColorScheme-Highlight" d="M14 22H96L112 38H242V234H14Z" fill="currentColor"/>
  <!-- Back flap shadow -->
  <path d="M14 22H96L112 38H242V234H14Z" fill="#000000" opacity=".28"/>
  <!-- Top tab highlight -->
  <path d="M14 22H96L112 38H242V40H111L95 24H14Z" fill="#ffffff" opacity=".2"/>
  <!-- Interior paper sheet (sharp edges) -->
  <path d="M30 46H226V180H30Z" fill="#ebdbb2"/>
  <path d="M30 46H226V50H30Z" fill="#ffffff" opacity=".4"/>
  <!-- Front open flap -->
  <path class="ColorScheme-Highlight" d="M14 99H104L120 83H242V234H14Z" fill="currentColor"/>
  <!-- Front flap top edge highlight -->
  <path d="M14 99H104L120 83H242V86H119L103 102H14Z" fill="#ffffff" opacity=".25"/>
  <!-- Bottom shadow -->
  <path d="M14 231H242V235H14Z" fill="#000000" opacity=".3"/>"""

STRAIGHT_DESKTOP_BODY = """  <!-- Window frame (sharp straight edges) -->
  <path class="ColorScheme-Highlight" d="M14 38H242V218H14Z" fill="currentColor"/>
  <!-- Titlebar -->
  <path d="M14 38H242V60H14Z" fill="#000000" opacity=".28"/>
  <!-- Titlebar top highlight -->
  <path d="M14 38H242V40H14Z" fill="#ffffff" opacity=".2"/>
  <!-- Bottom shadow -->
  <path d="M14 215H242V218H14Z" fill="#000000" opacity=".3"/>
  <!-- Sharp titlebar dots -->
  <rect x="24" y="44" width="8" height="8" fill="#ffffff" opacity=".3"/>
  <rect x="38" y="44" width="8" height="8" fill="#ffffff" opacity=".3"/>
  <rect x="52" y="44" width="8" height="8" fill="#ffffff" opacity=".3"/>
  <!-- Bottom dock blocks (sharp straight edges) -->
  <rect x="58" y="194" width="16" height="12" fill="#000000" opacity=".25"/>
  <rect x="88" y="194" width="16" height="12" fill="#000000" opacity=".25"/>
  <rect x="118" y="194" width="16" height="12" fill="#000000" opacity=".25"/>
  <rect x="148" y="194" width="16" height="12" fill="#000000" opacity=".25"/>
  <rect x="178" y="194" width="16" height="12" fill="#000000" opacity=".25"/>"""

def get_target_accent():
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

    scalable_dir = os.path.join(ICON_THEME_DIR, "places/scalable")
    if os.path.isdir(scalable_dir):
        for fname in os.listdir(scalable_dir):
            if not fname.endswith(".svg"):
                continue
            fpath = os.path.join(scalable_dir, fname)
            if os.path.islink(fpath):
                continue

            try:
                with open(fpath, "r", encoding="utf-8", errors="ignore") as fp:
                    content = fp.read()

                # Enforce straight geometric edges if file still has rounded curves
                if "m53 71c-36.338" in content:
                    defs_m = re.search(r'(<defs>.*?</defs>)', content, re.DOTALL)
                    defs = defs_m.group(1) if defs_m else f'<defs><style id="current-color-scheme" type="text/css">.ColorScheme-Text {{ color:#282828; }} .ColorScheme-Highlight {{ color:{target_accent}; }}</style></defs>'
                    is_open = fname.endswith("-open.svg") or "-drag-accept" in fname or "-visiting" in fname
                    body = STRAIGHT_OPEN_FOLDER_BODY if is_open else STRAIGHT_FOLDER_BODY
                    parts = content.split('<path ')
                    emblem_start = 7 if is_open else 6
                    emblem_paths = ['<path ' + part for part in parts[emblem_start:]]
                    emblem_content = ''.join(emblem_paths).replace('</svg>', '').strip()
                    if emblem_content:
                        content = f'<svg width="256" height="256" version="1.1" xmlns="http://www.w3.org/2000/svg">\n  {defs}\n{body}\n  {emblem_content}\n</svg>\n'
                    else:
                        content = f'<svg width="256" height="256" version="1.1" xmlns="http://www.w3.org/2000/svg">\n  {defs}\n{body}\n</svg>\n'
                    updated = True

                elif fname == "user-desktop.svg" and "m16.833 39.881" in content:
                    defs_m = re.search(r'(<defs>.*?</defs>)', content, re.DOTALL)
                    defs = defs_m.group(1) if defs_m else f'<defs><style id="current-color-scheme" type="text/css">.ColorScheme-Text {{ color:#282828; }} .ColorScheme-Highlight {{ color:{target_accent}; }}</style></defs>'
                    content = f'<svg width="256" height="256" version="1.1" xmlns="http://www.w3.org/2000/svg">\n  {defs}\n{STRAIGHT_DESKTOP_BODY}\n</svg>\n'
                    updated = True

                # Update accent color
                if ".ColorScheme-Highlight" in content:
                    new_content = pattern.sub(r'\g<1>' + target_accent + r'\2', content)
                    if new_content != content:
                        content = new_content
                        updated = True

                with open(fpath, "w", encoding="utf-8") as fp:
                    fp.write(content)
            except Exception:
                pass

    # 16px places
    places16_dir = os.path.join(ICON_THEME_DIR, "places/16")
    if os.path.isdir(places16_dir):
        for fname in os.listdir(places16_dir):
            if fname.endswith(".svg"):
                fpath = os.path.join(places16_dir, fname)
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
