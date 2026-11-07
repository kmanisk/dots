"""Resolve Omarchy wallpaper ownership with artistic semantic fallbacks.

Runtime wallpaper bytes always come from an Omarchy theme repository. The selected
palette is never replaced. Resolution order is:

1. the theme's own Omarchy repository;
2. an explicit alias;
3. an exact normalized Omarchy identity match;
4. an artistic/technical semantic donor selected from user-curated Omarchy pools;
5. no donor, allowing theme-set to use the palette's solid background.
"""
from __future__ import annotations

import colorsys
import json
import math
import os
import re
from functools import lru_cache
from pathlib import Path

THEME_CACHE = Path(os.path.expanduser("~/.cache/theme/themes"))
ALIASES_FILE = Path(os.path.expanduser("~/.config/theme/wallpaper-aliases.json"))
PREFERENCES_FILE = Path(os.path.expanduser("~/.config/theme/wallpaper-preferences.json"))


def normalized_slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", str(value).lower()).strip("-")


def compact_name(value: str, *, donor: bool = False) -> str:
    value = str(value).lower().replace("_", "-")
    if donor:
        value = re.sub(r"^omarchy[- ]?", "", value)
    return re.sub(r"[^a-z0-9]+", "", value)


def repository_wallpapers_are_authoritative(theme: dict) -> bool:
    source = theme.get("source") or {}
    repository = str(source.get("repository") or "")
    provider = str(source.get("provider") or "").casefold()
    return (
        repository.startswith(("https://github.com/", "https://www.github.com/"))
        and (provider == "omarchy" or bool(source.get("official_builtin")))
    )


def _wallpaper_candidates(theme: dict) -> list[str]:
    values = (theme.get("assets") or {}).get("wallpapers") or []
    if isinstance(values, str):
        values = [values]
    return [str(value) for value in values if str(value).strip()]


def _has_wallpapers(theme: dict) -> bool:
    return bool(_wallpaper_candidates(theme))


def wallpaper_candidate_scopes(theme: dict) -> tuple[str, ...]:
    """Return canonical repository wallpaper roots declared by a theme.

    Standalone repositories usually yield ``backgrounds/``. Official Omarchy
    built-ins live inside the shared omacom/omarchy repository and yield roots
    such as ``themes/everforest/backgrounds/``. These roots are authoritative
    for repository discovery/cycling so sibling themes can never leak in.
    """
    conventional = {"background", "backgrounds", "wallpaper", "wallpapers", "bg"}
    scopes: set[str] = set()
    for value in _wallpaper_candidates(theme):
        normalized = str(value).replace("\\", "/").lstrip("./")
        parts = [part for part in normalized.split("/") if part]
        for index, part in enumerate(parts[:-1]):
            if part.casefold() in conventional:
                scopes.add("/".join(parts[: index + 1]) + "/")
                break
    return tuple(sorted(scopes))


def wallpaper_path_allowed(theme: dict, path: str) -> bool:
    """Whether a repository path belongs to this theme's canonical wallpaper roots."""
    scopes = wallpaper_candidate_scopes(theme)
    if not scopes:
        return True
    normalized = str(path).replace("\\", "/").lstrip("./")
    return any(normalized.startswith(scope) for scope in scopes)


def load_theme(theme_name: str, cache_dir: Path = THEME_CACHE) -> dict | None:
    path = cache_dir / f"{theme_name}.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError, TypeError):
        return None
    return data if isinstance(data, dict) else None


def _identity_keys(theme_name: str, theme: dict, *, donor: bool = False) -> set[str]:
    values = (theme_name, theme.get("name") or "", theme.get("display_name") or "")
    return {key for value in values if (key := compact_name(str(value), donor=donor))}


def _read_json_dict(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError, TypeError):
        return {}
    return data if isinstance(data, dict) else {}


def _load_aliases(path: Path = ALIASES_FILE) -> dict[str, str]:
    data = _read_json_dict(path)
    return {
        normalized_slug(str(source)): str(target)
        for source, target in data.items()
        if str(source).strip() and str(target).strip()
    }


def _load_preferences(path: Path = PREFERENCES_FILE) -> dict:
    data = _read_json_dict(path)
    if data.get("version") != 1:
        return {}
    return data


@lru_cache(maxsize=8)
def _available_donors(cache_dir_value: str) -> tuple[tuple[str, dict], ...]:
    cache_dir = Path(cache_dir_value)
    donors: list[tuple[str, dict]] = []
    for path in sorted(cache_dir.glob("*.json")):
        donor = load_theme(path.stem, cache_dir)
        if not donor or not repository_wallpapers_are_authoritative(donor) or not _has_wallpapers(donor):
            continue
        donors.append((path.stem, donor))
    return tuple(donors)


def _base16(theme: dict) -> dict:
    direct = theme.get("base_16")
    if isinstance(direct, dict):
        return direct
    palette = theme.get("palette") or {}
    nested = palette.get("base_16") if isinstance(palette, dict) else None
    return nested if isinstance(nested, dict) else {}


def _base_color(theme: dict, key: str) -> str | None:
    colors = _base16(theme)
    return colors.get(key) or colors.get(key.upper()) or colors.get(key.lower())


def _accent(theme: dict) -> str | None:
    direct = theme.get("accent")
    if isinstance(direct, str):
        return direct
    palette = theme.get("palette") or {}
    value = palette.get("accent") if isinstance(palette, dict) else None
    return value if isinstance(value, str) else _base_color(theme, "BASE0D")


def _rgb(value: str | None) -> tuple[int, int, int] | None:
    if not isinstance(value, str):
        return None
    match = re.fullmatch(r"#?([0-9a-fA-F]{6})", value.strip())
    if not match:
        return None
    raw = match.group(1)
    return tuple(int(raw[index:index + 2], 16) for index in (0, 2, 4))


def _relative_luminance(value: str | None) -> float | None:
    rgb = _rgb(value)
    if rgb is None:
        return None
    channels = []
    for channel in rgb:
        c = channel / 255.0
        channels.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def _mode(theme: dict) -> str:
    explicit = str(theme.get("type") or "").casefold()
    if explicit in {"light", "dark"}:
        return explicit
    luminance = _relative_luminance(_base_color(theme, "BASE00"))
    return "light" if luminance is not None and luminance >= 0.45 else "dark"


def _rgb_distance(left: str | None, right: str | None) -> float:
    a = _rgb(left)
    b = _rgb(right)
    if a is None or b is None:
        return 50.0
    distance = math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))
    return (distance / math.sqrt(3 * 255 * 255)) * 100.0


def _palette_distance(target: dict, donor: dict) -> float:
    pairs = [
        (_accent(target), _accent(donor), 0.50),
        (_base_color(target, "BASE00"), _base_color(donor, "BASE00"), 0.12),
        (_base_color(target, "BASE0A"), _base_color(donor, "BASE0A"), 0.08),
        (_base_color(target, "BASE0B"), _base_color(donor, "BASE0B"), 0.10),
        (_base_color(target, "BASE0D"), _base_color(donor, "BASE0D"), 0.12),
        (_base_color(target, "BASE0E"), _base_color(donor, "BASE0E"), 0.08),
    ]
    return sum(_rgb_distance(left, right) * weight for left, right, weight in pairs)


def _theme_text(theme_name: str, theme: dict) -> str:
    values = [theme_name, str(theme.get("name") or ""), str(theme.get("display_name") or "")]
    return " ".join(normalized_slug(value).replace("-", " ") for value in values if value)


def classify_semantic_style(theme_name: str, theme: dict, preferences: dict | None = None) -> str:
    """Classify an unmatched palette into the user's preferred Omarchy art style."""
    preferences = preferences or _load_preferences()
    text = _theme_text(theme_name, theme)
    words = set(text.split())
    keywords = preferences.get("keywords") or {}

    # Light palettes stay with light artwork unless an exact/alias donor already handled them.
    if _mode(theme) == "light":
        return "light_artistic"

    for bucket in preferences.get("keyword_priority") or []:
        values = keywords.get(bucket) or []
        for value in values:
            phrase = normalized_slug(value).replace("-", " ")
            if not phrase:
                continue
            # Single-word keywords match whole normalized tokens only. This avoids
            # false positives such as `arch` inside the provider word `omarchy`.
            if (" " in phrase and phrase in text) or (" " not in phrase and phrase in words):
                return str(bucket)

    accent = _rgb(_accent(theme))
    background_luminance = _relative_luminance(_base_color(theme, "BASE00"))
    if accent is not None:
        hue, saturation, _ = colorsys.rgb_to_hsv(*(channel / 255.0 for channel in accent))
        degrees = hue * 360.0
        dark_background = background_luminance is None or background_luminance < 0.22
        if dark_background and saturation >= 0.58:
            # Green/cyan on black is strongly terminal-like; electric blue is blueprint-like;
            # hot magenta/red is synthwave-like. Everything else stays artistic-first.
            if 80.0 <= degrees < 170.0:
                return "terminal_technical"
            if 170.0 <= degrees < 245.0:
                return "technical_blueprint"
            if degrees >= 275.0 or degrees < 25.0:
                return "synth_technical"

    return "artistic_oil"


def _semantic_donor(
    theme_name: str,
    theme: dict,
    cache_dir: Path,
    preferences: dict,
) -> tuple[str, dict, str, float] | None:
    if not preferences.get("semantic_fallback"):
        return None

    bucket = classify_semantic_style(theme_name, theme, preferences)
    pools = preferences.get("donor_pools") or {}
    requested = [str(name) for name in pools.get(bucket) or []]
    if not requested:
        return None

    donors_by_name = dict(_available_donors(str(cache_dir)))
    ranked: list[tuple[int, str, dict]] = []
    for rank, donor_name in enumerate(requested):
        donor = donors_by_name.get(donor_name)
        if donor is not None:
            ranked.append((rank, donor_name, donor))
    if not ranked:
        return None

    target_mode = _mode(theme)
    same_mode = [item for item in ranked if _mode(item[2]) == target_mode]
    candidates = same_mode or ranked
    rank_weight = float(preferences.get("rank_weight") or 2.5)

    scored: list[tuple[float, str, dict]] = []
    for rank, donor_name, donor in candidates:
        score = _palette_distance(theme, donor) + rank * rank_weight
        scored.append((score, donor_name, donor))
    scored.sort(key=lambda item: (item[0], item[1]))
    score, donor_name, donor = scored[0]
    return donor_name, donor, bucket, score


def resolve_omarchy_wallpaper_source_info(
    theme_name: str,
    theme: dict,
    cache_dir: Path = THEME_CACHE,
) -> dict:
    """Return donor metadata while preserving the selected palette/theme identity."""
    # Locally curated palette-only themes opt out of wallpaper matching and
    # lazy downloads. The runtime applies their own BASE00 as a solid Sway bg.
    # Preserve existing themes' own/alias/identity/semantic donor policies.
    if (theme.get("assets") or {}).get("background_mode") == "solid":
        return {
            "kind": "none", "source_name": None, "source_theme": None,
            "style": None, "score": None,
        }
    if repository_wallpapers_are_authoritative(theme) and _has_wallpapers(theme):
        return {
            "kind": "own",
            "source_name": theme_name,
            "source_theme": theme,
            "style": None,
            "score": 0.0,
        }

    aliases = _load_aliases()
    donor_name = aliases.get(normalized_slug(theme_name))
    if donor_name:
        donor = load_theme(donor_name, cache_dir)
        if donor and repository_wallpapers_are_authoritative(donor) and _has_wallpapers(donor):
            return {
                "kind": "alias",
                "source_name": donor_name,
                "source_theme": donor,
                "style": None,
                "score": 0.0,
            }

    target_keys = _identity_keys(theme_name, theme)
    matches: list[tuple[int, str, dict]] = []
    for donor_name, donor in _available_donors(str(cache_dir)):
        if target_keys & _identity_keys(donor_name, donor, donor=True):
            source = donor.get("source") or {}
            priority = 0 if bool(source.get("official_builtin")) else 1
            matches.append((priority, donor_name, donor))
    if matches:
        matches.sort(key=lambda item: (item[0], item[1]))
        _, donor_name, donor = matches[0]
        return {
            "kind": "identity",
            "source_name": donor_name,
            "source_theme": donor,
            "style": None,
            "score": 0.0,
        }

    preferences = _load_preferences()
    semantic = _semantic_donor(theme_name, theme, cache_dir, preferences)
    if semantic:
        donor_name, donor, bucket, score = semantic
        return {
            "kind": "semantic",
            "source_name": donor_name,
            "source_theme": donor,
            "style": bucket,
            "score": round(score, 2),
        }

    return {
        "kind": "none",
        "source_name": None,
        "source_theme": None,
        "style": None,
        "score": None,
    }


def resolve_omarchy_wallpaper_source(
    theme_name: str,
    theme: dict,
    cache_dir: Path = THEME_CACHE,
) -> tuple[str, dict] | None:
    info = resolve_omarchy_wallpaper_source_info(theme_name, theme, cache_dir)
    source_name = info.get("source_name")
    source_theme = info.get("source_theme")
    if not source_name or not isinstance(source_theme, dict):
        return None
    return str(source_name), source_theme
