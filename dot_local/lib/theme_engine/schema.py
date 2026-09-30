"""
theme_engine.schema: Schema 1 definitions, semantic token derivation, and WCAG contrast validation.
"""
import re
import math

HEX_RE = re.compile(r"^#?[0-9a-fA-F]{6}$")

BASE16_KEYS = [
    "BASE00", "BASE01", "BASE02", "BASE03",
    "BASE04", "BASE05", "BASE06", "BASE07",
    "BASE08", "BASE09", "BASE0A", "BASE0B",
    "BASE0C", "BASE0D", "BASE0E", "BASE0F",
]

def clean_hex(h, default="#ffffff"):
    if not h or not isinstance(h, str):
        return default
    h = h.strip()
    if not h.startswith("#"):
        h = "#" + h
    if HEX_RE.match(h):
        return h.lower()
    return default

def hex_to_rgb(h):
    h = clean_hex(h).lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)

def srgb_channel_to_linear(c):
    c_norm = c / 255.0
    if c_norm <= 0.04045:
        return c_norm / 12.92
    return math.pow((c_norm + 0.055) / 1.055, 2.4)

def relative_luminance(h):
    r, g, b = hex_to_rgb(h)
    r_lin = srgb_channel_to_linear(r)
    g_lin = srgb_channel_to_linear(g)
    b_lin = srgb_channel_to_linear(b)
    return 0.2126 * r_lin + 0.7152 * g_lin + 0.0722 * b_lin

def contrast_ratio(h1, h2):
    """Calculate WCAG 2.1 contrast ratio between two hex colors."""
    l1 = relative_luminance(h1)
    l2 = relative_luminance(h2)
    lighter = max(l1, l2)
    darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)

def synthesize_derived(palette, theme_type="dark"):
    """
    Synthesize extended Base30 and Semantic tokens from pure Base16 + accent.
    Never alters the author's Base16 palette.
    """
    b16 = palette.get("base_16", {})
    accent = palette.get("accent") or b16.get("BASE0D") or b16.get("BASE0A") or "#58a6ff"
    accent = clean_hex(accent)

    bg = clean_hex(b16.get("BASE00", "#181818"))
    darker_bg = clean_hex(b16.get("BASE01", "#121212"))
    selection = clean_hex(b16.get("BASE02", "#282828"))
    muted = clean_hex(b16.get("BASE03", "#585858"))
    dark_fg = clean_hex(b16.get("BASE04", "#787878"))
    fg = clean_hex(b16.get("BASE05", "#d8d8d8"))
    light_fg = clean_hex(b16.get("BASE06", "#e8e8e8"))
    bright_fg = clean_hex(b16.get("BASE07", "#f8f8f8"))

    c_red = clean_hex(b16.get("BASE08", "#e06c75"))
    c_orange = clean_hex(b16.get("BASE09", "#e78a4e"))
    c_yellow = clean_hex(b16.get("BASE0A", "#d6b676"))
    c_green = clean_hex(b16.get("BASE0B", "#89b482"))
    c_cyan = clean_hex(b16.get("BASE0C", "#82b3a8"))
    c_blue = clean_hex(b16.get("BASE0D", "#6d8dad"))
    c_magenta = clean_hex(b16.get("BASE0E", "#9385b4"))
    c_brown = clean_hex(b16.get("BASE0F", "#70432e"))

    # Synthesize Base30 UI dictionary
    base_30 = {
        "white": bright_fg,
        "darker_black": darker_bg,
        "black": bg,
        "black2": selection,
        "one_bg": darker_bg,
        "one_bg2": selection,
        "one_bg3": muted,
        "grey": muted,
        "grey_fg": dark_fg,
        "grey_fg2": dark_fg,
        "light_grey": selection,
        "red": c_red,
        "baby_pink": c_magenta,
        "pink": c_magenta,
        "line": selection,
        "green": c_green,
        "vibrant_green": c_green,
        "nord_blue": c_blue,
        "blue": c_blue,
        "yellow": c_yellow,
        "sun": c_yellow,
        "purple": c_magenta,
        "dark_purple": c_magenta,
        "teal": c_cyan,
        "orange": c_orange,
        "cyan": c_cyan,
        "statusline_bg": darker_bg,
        "lightbg": selection,
        "pmenu_bg": selection,
        "folder_bg": accent,
    }

    # Synthesize first-class semantic tokens
    semantic = {
        "background": bg,
        "surface": darker_bg,
        "surface_alt": selection,
        "foreground": fg,
        "muted": muted,
        "border": accent,
        "accent": accent,
        "selection": selection,
        "error": c_red,
        "warning": c_yellow,
        "success": c_green,
        "info": c_cyan,
        "link": c_blue,
    }

    # Contrast evaluation (Non-destructive)
    cr = contrast_ratio(bg, fg)
    contrast_info = {
        "ratio": round(cr, 2),
        "wcag_aa": cr >= 4.5,
        "wcag_aaa": cr >= 7.0,
        "warning": None if cr >= 4.5 else f"Low text contrast: {cr:.2f}:1 (< 4.5:1 WCAG AA standard)",
    }

    return {
        "base_30": base_30,
        "semantic": semantic,
        "contrast": contrast_info,
    }

def synthesize_cava(palette, semantic, raw_cava=None):
    """
    Builds canonical Cava visualizer theme settings.
    Uses the most prominent theme accent color across the whole visualizer (gradient = 0)
    for a clean, unified aesthetic matching Omarchy theme standards.
    """
    b16 = palette.get("base_16", {})
    accent = palette.get("accent") or b16.get("BASE0D") or b16.get("BASE0A") or "#58a6ff"
    accent = clean_hex(accent)

    return {
        "source": "accent",
        "gradient": 0,
        "gradient_count": 0,
        "colors": [accent],
        "background": "default",
        "foreground": accent,
    }


def normalize_theme(raw, default_name=None, default_provider="custom"):
    """
    Normalizes any theme input (legacy flat Schema 0 or Schema 1) into canonical Schema 1.
    Preserves original author colors while synthesizing semantic and Base30 views.
    Maintains top-level aliases for zero-breakage backward compatibility.
    """
    schema_version = raw.get("schema", 1)
    name = raw.get("name") or default_name or "unnamed-theme"
    display_name = raw.get("display_name") or raw.get("id") or name
    theme_type = raw.get("type", "dark")
    if theme_type not in ("dark", "light"):
        theme_type = "dark"

    # 1. Resolve source palette
    if "palette" in raw and isinstance(raw["palette"], dict):
        palette_dict = raw["palette"]
        b16_in = palette_dict.get("base_16", {})
        accent = palette_dict.get("accent") or raw.get("accent")
    else:
        b16_in = raw.get("base_16", {})
        accent = raw.get("accent")

    b16 = {}
    for k, v in b16_in.items():
        k_upper = k.upper()
        if k_upper in BASE16_KEYS:
            b16[k_upper] = clean_hex(str(v))

    # Fill any missing Base16 slots with sensible defaults
    if len(b16) < 16:
        defaults = {
            "BASE00": "#181818", "BASE01": "#282828", "BASE02": "#383838", "BASE03": "#585858",
            "BASE04": "#b8b8b8", "BASE05": "#d8d8d8", "BASE06": "#e8e8e8", "BASE07": "#f8f8f8",
            "BASE08": "#ab4642", "BASE09": "#dc9656", "BASE0A": "#f7ca88", "BASE0B": "#a1b56c",
            "BASE0C": "#86c1b9", "BASE0D": "#7cafc2", "BASE0E": "#ba8baf", "BASE0F": "#a16946"
        }
        for k, v in defaults.items():
            if k not in b16:
                b16[k] = v

    if not accent:
        accent = b16.get("BASE0D", b16.get("BASE0A", "#58a6ff"))
    accent = clean_hex(accent)

    palette = {
        "accent": accent,
        "base_16": b16,
    }

    # 2. Derive synthesized Base30 and Semantic tokens
    derived = synthesize_derived(palette, theme_type=theme_type)

    # If the author provided custom semantic overrides (e.g. from rich colors.toml), merge them
    if "semantic" in raw and isinstance(raw["semantic"], dict):
        for k, v in raw["semantic"].items():
            if HEX_RE.match(str(v)):
                derived["semantic"][k] = clean_hex(str(v))

    # If the author provided custom base_30 overrides, merge them without erasing fallbacks
    if "base_30" in raw and isinstance(raw["base_30"], dict):
        for k, v in raw["base_30"].items():
            if HEX_RE.match(str(v)):
                derived["base_30"][k] = clean_hex(str(v))

    # 3. Resolve provenance / source
    source_meta = raw.get("source")
    if not isinstance(source_meta, dict):
        source_meta = {
            "provider": str(source_meta or default_provider),
            "registry": raw.get("registry"),
            "repository": raw.get("repo") or raw.get("repository"),
            "commit": raw.get("commit"),
            "author": raw.get("author") or "Unknown",
            "license": raw.get("license"),
            "added_at": raw.get("added_at"),
            "tags": raw.get("tags", []),
        }

    # 4. Resolve apps (including Cava)
    apps = raw.get("apps")
    if not isinstance(apps, dict):
        apps = {}

    raw_cava = apps.get("cava") or raw.get("cava")
    cava_data = synthesize_cava(palette, derived["semantic"], raw_cava)
    apps["cava"] = cava_data

    # 5. Resolve capabilities
    caps = raw.get("capabilities")
    if not isinstance(caps, dict):
        caps = {
            "palette": True,
            "wallpaper": bool(raw.get("wallpaper") or raw.get("assets", {}).get("wallpaper")),
            "icons": bool(raw.get("icons")),
            "terminal": True,
            "browser": bool(raw.get("browser")),
        }
    caps["cava"] = True

    # 6. Resolve assets
    assets = raw.get("assets")
    if not isinstance(assets, dict):
        assets = {
            "wallpaper": raw.get("wallpaper"),
            "preview": raw.get("preview"),
        }

    # Construct canonical Schema 1
    normalized = {
        "schema": 1,
        "name": name,
        "display_name": display_name,
        "type": theme_type,
        "accent": accent,
        "source": source_meta,
        "capabilities": caps,
        "palette": palette,
        "derived": derived,
        "apps": apps,
        "assets": assets,
        # Backward-compatibility aliases for existing templates/tools:
        "base_16": b16,
        "base_30": derived["base_30"],
        "semantic": derived["semantic"],
        "cava": cava_data,
    }

    return normalized
