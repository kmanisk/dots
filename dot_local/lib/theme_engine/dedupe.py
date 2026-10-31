"""Conservative exact/near duplicate detection for the generated theme catalog."""
from __future__ import annotations

import json
import math
import os
import re
from collections import defaultdict

BASE16_KEYS = [f"BASE0{x}" for x in "0123456789ABCDEF"]


def _rgb(value):
    value = str(value or "#000000").lstrip("#")
    try:
        return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))
    except Exception:
        return (0, 0, 0)


def color_distance(a, b):
    ra, ga, ba = _rgb(a)
    rb, gb, bb = _rgb(b)
    return math.sqrt((ra - rb) ** 2 + (ga - gb) ** 2 + (ba - bb) ** 2)


def palette_values(theme):
    b16 = theme.get("base_16") or theme.get("palette", {}).get("base_16", {})
    return tuple(str(b16.get(k, "")).lower() for k in BASE16_KEYS)


def palette_distance(a, b):
    pa, pb = palette_values(a), palette_values(b)
    if not all(pa) or not all(pb):
        return float("inf")
    return sum(color_distance(x, y) for x, y in zip(pa, pb)) / len(BASE16_KEYS)


def _compact_alias(name):
    compact = re.sub(r"[^a-z0-9]", "", name.lower())
    aliases = {
        "tokyonight": "tokyo-night",
        "tokyodark": "tokyo-night",
        "tokyoled": "tokyo-night",
        "tokyonightoled": "tokyo-night",
        "rosepine": "rose-pine",
        "onedark": "one-dark",
        "onedarkpro": "one-dark",
        "onenord": "nord",
    }
    return aliases.get(compact)


def family_key(name):
    name = str(name or "").lower().replace("_", "-")
    name = re.sub(r"^omarchy-", "", name)
    alias = _compact_alias(name)
    if alias:
        return alias
    tokens = [t for t in re.split(r"[^a-z0-9]+", name) if t]
    modifiers = {"theme", "dark", "light", "pro", "moon", "oled", "mocha"}
    while tokens and tokens[-1] in modifiers:
        tokens.pop()
    return "-".join(tokens)


def _provider(theme):
    return str((theme.get("source") or {}).get("provider") or "other").lower()


def _survivor_score(name, theme):
    provider = _provider(theme)
    # User/custom and Omarchy built-ins are authoritative over imported community
    # copies; community themes are authoritative over Base46 compatibility copies.
    if provider == "custom":
        provider_rank = 0
    elif provider == "omarchy":
        provider_rank = 1
    elif provider == "base46":
        provider_rank = 2
    else:
        provider_rank = 3
    family = family_key(name)
    stripped = re.sub(r"^omarchy-", "", name.lower().replace("_", "-"))
    canonical_penalty = 0 if stripped == family else 1
    return (provider_rank, canonical_penalty, len(stripped), stripped)


def find_duplicate_groups(themes):
    names = sorted(themes)
    parent = {n: n for n in names}
    reasons = {}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b, reason, distance):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra
        reasons[tuple(sorted((a, b)))] = {"reason": reason, "distance": round(distance, 2)}

    # Exact palette duplicates are duplicates regardless of naming.
    exact = defaultdict(list)
    for name, theme in themes.items():
        key = (theme.get("type", "dark"), palette_values(theme))
        if all(key[1]):
            exact[key].append(name)
    for group in exact.values():
        if len(group) > 1:
            for other in group[1:]:
                union(group[0], other, "exact-palette", 0.0)

    # Near duplicates must share a normalized family and actually be close in
    # the full 16-color palette. This collapses provider copies and cosmetic
    # suffixes such as -pro/-moon/-oled, while retaining genuinely different
    # variants even when their names share a family (e.g. a radically different
    # light palette).
    families = defaultdict(list)
    for name in names:
        families[(themes[name].get("type", "dark"), family_key(name))].append(name)
    for (_, family), group in families.items():
        if not family or len(group) < 2:
            continue
        for i, a in enumerate(group):
            for b in group[i + 1 :]:
                distance = palette_distance(themes[a], themes[b])
                if distance <= 70.0:
                    union(a, b, "same-family-near-palette", distance)

    groups = defaultdict(list)
    for name in names:
        groups[find(name)].append(name)
    return [sorted(g) for g in groups.values() if len(g) > 1], reasons


def choose_survivors(themes):
    groups, reasons = find_duplicate_groups(themes)
    duplicates = {}
    for group in groups:
        survivor = min(group, key=lambda n: _survivor_score(n, themes[n]))
        for name in group:
            if name == survivor:
                continue
            pair = tuple(sorted((name, survivor)))
            info = reasons.get(pair)
            if not info:
                info = {
                    "reason": "duplicate-cluster",
                    "distance": round(palette_distance(themes[name], themes[survivor]), 2),
                }
            duplicates[name] = {"survivor": survivor, **info}
    return duplicates


def apply_dedupe(cache_dir, previews_dir, nvim_dir, manifest_path):
    themes = {}
    for filename in sorted(os.listdir(cache_dir)):
        if not filename.endswith(".json"):
            continue
        path = os.path.join(cache_dir, filename)
        try:
            with open(path, "r", encoding="utf-8") as f:
                themes[filename[:-5]] = json.load(f)
        except Exception:
            continue

    duplicates = choose_survivors(themes)
    removed_preview = 0
    removed_nvim = 0
    for name in sorted(duplicates):
        cache_path = os.path.join(cache_dir, f"{name}.json")
        preview_path = os.path.join(previews_dir, f"{name}.png")
        nvim_path = os.path.join(nvim_dir, f"{name}.lua")
        try:
            os.unlink(cache_path)
        except FileNotFoundError:
            pass
        try:
            os.unlink(preview_path)
            removed_preview += 1
        except FileNotFoundError:
            pass
        try:
            with open(nvim_path, "r", encoding="utf-8", errors="ignore") as f:
                generated = f.readline().startswith("-- Auto-generated by theme-sync")
            if generated:
                os.unlink(nvim_path)
                removed_nvim += 1
        except FileNotFoundError:
            pass

    payload = {
        "policy": {
            "exact": "same full Base16 palette and theme type",
            "near": "same normalized theme family and light/dark mode with mean Base16 RGB distance <= 70",
        },
        "raw_theme_count": len(themes),
        "unique_theme_count": len(themes) - len(duplicates),
        "duplicate_count": len(duplicates),
        "duplicates": duplicates,
    }
    os.makedirs(os.path.dirname(manifest_path), exist_ok=True)
    tmp = manifest_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp, manifest_path)
    return payload, removed_preview, removed_nvim
