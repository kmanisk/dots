"""
theme_engine.schema: Schema 1 definitions, semantic token derivation, and WCAG contrast validation.
"""
import re
import math
import colorsys

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

def rgb_to_hex(r, g, b):
    return f"#{int(round(max(0, min(255, r)))):02x}{int(round(max(0, min(255, g)))):02x}{int(round(max(0, min(255, b)))):02x}"

def blend_colors(c1, c2, alpha):
    r1, g1, b1 = hex_to_rgb(c1)
    r2, g2, b2 = hex_to_rgb(c2)
    return rgb_to_hex(r1 + (r2 - r1) * alpha, g1 + (g2 - g1) * alpha, b1 + (b2 - b1) * alpha)

def hex_to_hls(h):
    r, g, b = hex_to_rgb(h)
    return colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)

def hls_to_hex(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h % 1.0, max(0.0, min(1.0, l)), max(0.0, min(1.0, s)))
    return rgb_to_hex(r * 255, g * 255, b * 255)

def hue_distance(h1, h2):
    diff = abs(h1 - h2) % 360.0
    return min(diff, 360.0 - diff)

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


def disambiguate_syntax(b16, is_dark=True):
    """
    Intelligently disambiguates collapsed or monochromatic syntax colors.
    Preserves the author's authentic saturation and luminance profile, ensuring
    roles (keywords, functions, strings, classes, constants) are distinct and readable
    without picking garish or clashing opposites.
    """
    syntax_roles = {
        "BASE08": ("red", 0),
        "BASE09": ("orange", 28),
        "BASE0A": ("yellow", 48),
        "BASE0B": ("green", 145),
        "BASE0C": ("cyan", 192),
        "BASE0D": ("blue", 222),
        "BASE0E": ("purple", 265),
        "BASE0F": ("pink", 320),
    }

    hues = {}
    lums = []
    sats = []
    for k in syntax_roles:
        val = b16.get(k)
        if val:
            h, l, s = hex_to_hls(val)
            hues[k] = h * 360.0
            if s > 0.12:
                lums.append(l)
                sats.append(s)

    avg_l = sum(lums) / len(lums) if lums else (0.75 if is_dark else 0.40)
    avg_s = sum(sats) / len(sats) if sats else 0.70

    target_l = max(0.65, min(0.85, avg_l)) if is_dark else max(0.30, min(0.50, avg_l))
    target_s = max(0.50, min(0.85, avg_s))

    new_b16 = dict(b16)

    # 1. Orange (BASE09) vs Red (BASE08):
    if hue_distance(hues.get("BASE08", 0), hues.get("BASE09", 28)) < 18:
        new_b16["BASE09"] = hls_to_hex(28 / 360.0, target_l, target_s)

    # 2. Yellow/Classes (BASE0A):
    h_0a = hues.get("BASE0A", 48)
    if (180 <= h_0a <= 300) or hue_distance(h_0a, hues.get("BASE08", 0)) < 18:
        new_b16["BASE0A"] = hls_to_hex(48 / 360.0, target_l, target_s)

    # 3. Green/Strings (BASE0B):
    h_0b = hues.get("BASE0B", 145)
    if (200 <= h_0b <= 300) or hue_distance(h_0b, hues.get("BASE0A", 48)) < 18:
        new_b16["BASE0B"] = hls_to_hex(145 / 360.0, target_l, target_s * 0.85)

    # 4. Cyan/Regex (BASE0C) vs Blue (BASE0D):
    if hue_distance(hues.get("BASE0C", 192), hues.get("BASE0D", 222)) < 18:
        new_b16["BASE0C"] = hls_to_hex(192 / 360.0, target_l, target_s)

    # 5. Blue/Functions (BASE0D) vs Purple/Keywords (BASE0E):
    if hue_distance(hues.get("BASE0D", 222), hues.get("BASE0E", 265)) < 18:
        new_b16["BASE0D"] = hls_to_hex(222 / 360.0, target_l, target_s)

    # 6. Pink/Brown (BASE0F) vs Purple (BASE0E):
    if hue_distance(hues.get("BASE0F", 320), hues.get("BASE0E", 265)) < 18:
        new_b16["BASE0F"] = hls_to_hex(320 / 360.0, target_l, target_s * 0.85)

    return new_b16


def sanitize_surface_palette(b16, accent, is_dark=True):
    """
    Guards UI background, surface, and selection tokens against polarity inversion.
    Ensures dark themes never have bright white/light surfaces, and light themes
    never have pitch black/dark surfaces.
    """
    clean_b16 = dict(b16)
    bg = clean_hex(clean_b16.get("BASE00", "#181818" if is_dark else "#fafafa"))
    accent = clean_hex(accent)

    # Sanitize BASE01 (elevated / darker background)
    b01 = clean_hex(clean_b16.get("BASE01", bg))
    l_01 = relative_luminance(b01)
    if is_dark:
        if l_01 > 0.22 or contrast_ratio(b01, bg) > 2.8:
            clean_b16["BASE01"] = blend_colors(bg, accent, 0.07)
    else:
        if l_01 < 0.40:
            clean_b16["BASE01"] = blend_colors(bg, "#000000", 0.04)

    # Sanitize BASE02 (selection background)
    b02 = clean_hex(clean_b16.get("BASE02", bg))
    l_02 = relative_luminance(b02)
    if is_dark:
        if l_02 > 0.22 or contrast_ratio(b02, bg) > 3.0:
            clean_b16["BASE02"] = blend_colors(bg, accent, 0.14)
    else:
        if l_02 < 0.40:
            clean_b16["BASE02"] = blend_colors(bg, "#000000", 0.10)

    # Sanitize BASE03 (muted / borders)
    b03 = clean_hex(clean_b16.get("BASE03", bg))
    l_03 = relative_luminance(b03)
    if is_dark:
        if l_03 > 0.35:
            clean_b16["BASE03"] = blend_colors(bg, accent, 0.25)
    else:
        if l_03 < 0.30:
            clean_b16["BASE03"] = blend_colors(bg, "#000000", 0.20)

    return clean_b16


def synthesize_derived(palette, theme_type="dark"):
    """
    Synthesize extended Base30 and Semantic tokens from pure Base16 + accent.
    Guards surfaces against polarity inversion and ensures clean, readable UI hierarchy.
    """
    b16 = palette.get("base_16", {})
    accent = palette.get("accent") or b16.get("BASE0D") or b16.get("BASE0A") or "#58a6ff"
    accent = clean_hex(accent)

    bg = clean_hex(b16.get("BASE00", "#181818"))
    l_bg = relative_luminance(bg)
    is_dark = (theme_type == "dark") and (l_bg < 0.40)

    darker_bg = clean_hex(b16.get("BASE01", bg))
    selection = clean_hex(b16.get("BASE02", bg))
    muted = clean_hex(b16.get("BASE03", bg))
    dark_fg = clean_hex(b16.get("BASE04", "#787878" if is_dark else "#888888"))
    fg = clean_hex(b16.get("BASE05", "#d8d8d8" if is_dark else "#333333"))
    light_fg = clean_hex(b16.get("BASE06", "#e8e8e8" if is_dark else "#222222"))
    bright_fg = clean_hex(b16.get("BASE07", "#f8f8f8" if is_dark else "#111111"))

    # Polarity check on selection and surfaces
    l_sel = relative_luminance(selection)
    if is_dark:
        if l_sel > 0.22 or contrast_ratio(selection, bg) > 3.0:
            selection = blend_colors(bg, accent, 0.14)
        if relative_luminance(darker_bg) > 0.22:
            darker_bg = blend_colors(bg, accent, 0.07)
    else:
        if l_sel < 0.40:
            selection = blend_colors(bg, "#000000", 0.10)
        if relative_luminance(darker_bg) < 0.40:
            darker_bg = blend_colors(bg, "#000000", 0.04)

    # Derived distinct surfaces for Base30:
    if is_dark:
        black2_val = blend_colors(bg, accent, 0.09)     # Tabfill, inactive tab background
        one_bg_val = darker_bg                          # Card background
        one_bg2_val = selection                         # Elevated surface, hover
        one_bg3_val = blend_colors(bg, accent, 0.20)    # Active hover, tertiary
        line_val = blend_colors(bg, accent, 0.15)       # Tab separators, split lines
        lightbg_val = blend_colors(bg, accent, 0.14)    # Line highlight, statusline ends
        pmenu_bg_val = blend_colors(bg, accent, 0.12)   # Popup menu background
        light_grey_val = blend_colors(dark_fg, fg, 0.3)  # Inactive tab text
    else:
        black2_val = blend_colors(bg, "#000000", 0.06)
        one_bg_val = darker_bg
        one_bg2_val = selection
        one_bg3_val = blend_colors(bg, "#000000", 0.15)
        line_val = blend_colors(bg, "#000000", 0.10)
        lightbg_val = blend_colors(bg, "#000000", 0.12)
        pmenu_bg_val = blend_colors(bg, "#000000", 0.08)
        light_grey_val = blend_colors(fg, bg, 0.4)

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
        "black2": black2_val,
        "one_bg": one_bg_val,
        "one_bg2": one_bg2_val,
        "one_bg3": one_bg3_val,
        "grey": muted,
        "grey_fg": dark_fg,
        "grey_fg2": dark_fg,
        "light_grey": light_grey_val,
        "red": c_red,
        "baby_pink": c_magenta,
        "pink": c_magenta,
        "line": line_val,
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
        "lightbg": lightbg_val,
        "pmenu_bg": pmenu_bg_val,
        "folder_bg": accent,
    }

    # Synthesize first-class semantic tokens
    semantic = {
        "background": bg,
        "surface": darker_bg,
        "surface_alt": selection,
        "foreground": fg,
        "muted": muted,
        "border": line_val,
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

    # Determine dark vs light polarity early from theme_type or bg luminance
    bg_candidate = clean_hex(str(b16_in.get("BASE00") or b16_in.get("base00") or "#181818"))
    is_dark = (theme_type == "dark")
    if relative_luminance(bg_candidate) < 0.35:
        is_dark = True
    elif relative_luminance(bg_candidate) >= 0.45:
        is_dark = False

    # Fill any missing Base16 slots with polarity-aware sensible defaults
    if len(b16) < 16:
        defaults = {
            "BASE00": "#181818" if is_dark else "#fafafa",
            "BASE01": "#282828" if is_dark else "#f0f0f0",
            "BASE02": "#383838" if is_dark else "#e5e5e6",
            "BASE03": "#585858" if is_dark else "#d0d0d0",
            "BASE04": "#b8b8b8" if is_dark else "#888888",
            "BASE05": "#d8d8d8" if is_dark else "#333333",
            "BASE06": "#e8e8e8" if is_dark else "#222222",
            "BASE07": "#f8f8f8" if is_dark else "#111111",
            "BASE08": "#ab4642", "BASE09": "#dc9656", "BASE0A": "#f7ca88", "BASE0B": "#a1b56c",
            "BASE0C": "#86c1b9", "BASE0D": "#7cafc2", "BASE0E": "#ba8baf", "BASE0F": "#a16946"
        }
        for k, v in defaults.items():
            if k not in b16:
                b16[k] = v

    raw_b30 = raw.get("base_30", {}) if isinstance(raw.get("base_30"), dict) else {}
    if not raw_b30 and "derived" in raw and isinstance(raw["derived"], dict):
        raw_b30 = raw["derived"].get("base_30", {})

    # Priority for signature UI accent:
    # 1. folder_bg (brand UI color explicitly chosen by theme author)
    # 2. explicit accent if custom provider
    # 3. blue / nord_blue
    # 4. BASE0D / BASE0A
    if raw_b30.get("folder_bg"):
        if default_provider == "base46" or not accent:
            accent = raw_b30["folder_bg"]
    if not accent:
        accent = raw_b30.get("blue") or raw_b30.get("nord_blue") or b16.get("BASE0D", b16.get("BASE0A", "#58a6ff"))
    accent = clean_hex(accent)

    # If the author provided authentic named colors in base_30, harmonize Base16 syntax slots
    if raw_b30:
        if raw_b30.get("red"): b16["BASE08"] = clean_hex(raw_b30["red"])
        if raw_b30.get("orange"): b16["BASE09"] = clean_hex(raw_b30["orange"])
        if raw_b30.get("yellow"): b16["BASE0A"] = clean_hex(raw_b30["yellow"])
        if raw_b30.get("green"): b16["BASE0B"] = clean_hex(raw_b30["green"])
        if raw_b30.get("cyan"): b16["BASE0C"] = clean_hex(raw_b30["cyan"])
        elif raw_b30.get("teal"): b16["BASE0C"] = clean_hex(raw_b30["teal"])
        if raw_b30.get("blue"): b16["BASE0D"] = clean_hex(raw_b30["blue"])
        if raw_b30.get("purple"): b16["BASE0E"] = clean_hex(raw_b30["purple"])
        if raw_b30.get("pink"): b16["BASE0F"] = clean_hex(raw_b30["pink"])
        elif raw_b30.get("baby_pink"): b16["BASE0F"] = clean_hex(raw_b30["baby_pink"])
        if raw_b30.get("white"): b16["BASE07"] = clean_hex(raw_b30["white"])

    # Disambiguate collapsed monochromatic syntax and guard surfaces against polarity inversion
    b16 = disambiguate_syntax(b16, is_dark=is_dark)
    b16 = sanitize_surface_palette(b16, accent, is_dark=is_dark)

    palette = {
        "accent": accent,
        "base_16": b16,
    }

    # 2. Derive synthesized Base30 and Semantic tokens
    derived = synthesize_derived(palette, theme_type=theme_type)

    # If the author provided custom semantic overrides (e.g. from rich colors.toml), merge them with polarity protection
    if default_provider != "base46" and "semantic" in raw and isinstance(raw["semantic"], dict):
        for k, v in raw["semantic"].items():
            if HEX_RE.match(str(v)):
                val = clean_hex(str(v))
                if k in ("surface", "surface_alt", "selection"):
                    l_val = relative_luminance(val)
                    if is_dark and l_val > 0.25:
                        continue  # Skip inverted surface override
                    elif not is_dark and l_val < 0.35:
                        continue  # Skip inverted surface override
                derived["semantic"][k] = val

    # If the author provided custom base_30 overrides, merge them without erasing fallbacks, with polarity protection
    if "base_30" in raw and isinstance(raw["base_30"], dict):
        surface_keys = {"black2", "one_bg", "one_bg2", "one_bg3", "line", "lightbg", "pmenu_bg", "statusline_bg", "darker_black"}
        for k, v in raw["base_30"].items():
            if HEX_RE.match(str(v)):
                val = clean_hex(str(v))
                if k in surface_keys:
                    l_val = relative_luminance(val)
                    if is_dark and l_val > 0.25:
                        continue  # Skip inverted surface override
                    elif not is_dark and l_val < 0.35:
                        continue  # Skip inverted surface override
                derived["base_30"][k] = val

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
