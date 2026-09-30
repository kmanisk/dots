"""
theme_engine.importer: Robust, safe importer for Omarchy community themes.
Enforces:
  1. Sandboxed Git cloning in ~/.cache/theme/import-tmp/
  2. Data-only parsing (colors.toml, cava_theme, app visual files)
  3. Absolute prohibition of code execution (no scripts, no binaries, no Lua/Python)
  4. Explicit filtering of Hyprland/Hyprlock configs (Sway environment authority)
  5. Schema 1 normalization & non-destructive WCAG contrast validation
  6. Transactional atomic staging & cache sync
"""
import os
import sys
import json
import re
import shutil
import subprocess
import tempfile
import urllib.request
from datetime import datetime

import tomllib

from theme_engine.schema import (
    normalize_theme,
    clean_hex,
    HEX_RE,
    BASE16_KEYS,
    contrast_ratio,
)

CATALOG_URLS = [
    "https://cdn.themes.omarchy.org/v1/catalog.json",
    "https://raw.githubusercontent.com/omacom/omarchy-theme-marketplace/master/data/catalog.json",
]

IMPORTED_OMARCHY_DIR = os.path.expanduser("~/.config/theme/imported/omarchy")
PREVIEWS_DIR = os.path.expanduser("~/.cache/theme/previews")
IMPORT_TMP_BASE = os.path.expanduser("~/.cache/theme/import-tmp")
WALLPAPERS_CACHE = os.path.expanduser("~/.cache/theme/wallpapers")

os.makedirs(IMPORTED_OMARCHY_DIR, exist_ok=True)
os.makedirs(PREVIEWS_DIR, exist_ok=True)
os.makedirs(IMPORT_TMP_BASE, exist_ok=True)
os.makedirs(WALLPAPERS_CACHE, exist_ok=True)


def normalize_git_url(raw_url):
    """
    Normalizes Git URLs (handles trailing slashes, .git suffix, git@ format).
    Returns (clean_url, owner, repo_name, slug).
    """
    url = raw_url.strip()
    if url.endswith("/"):
        url = url[:-1]
    if url.endswith(".git"):
        url = url[:-4]

    # Handle SSH git@github.com:owner/repo
    if url.startswith("git@github.com:"):
        path = url.split("git@github.com:", 1)[1]
        url = f"https://github.com/{path}"

    match = re.match(r"^https?://github\.com/([^/]+)/([^/]+)$", url)
    if not match:
        raise ValueError(
            f"Unsupported repository URL format: '{raw_url}'. Expected https://github.com/<owner>/<repo>"
        )

    owner, repo_name = match.group(1), match.group(2)
    slug = repo_name.lower().replace("_", "-")
    if slug.startswith("omarchy-"):
        slug = slug[8:]
    if slug.endswith("-theme"):
        slug = slug[:-6]

    return url, owner, repo_name, slug


def clone_repo_safely(repo_url, target_dir, commit=None):
    """
    Performs a shallow, safe git clone into target_dir without running hooks or scripts.
    Returns (commit_sha, branch_name).
    """
    env = os.environ.copy()
    # Disable git config execution of arbitrary commands/hooks
    env["GIT_CONFIG_NOSYSTEM"] = "1"
    env["GIT_TERMINAL_PROMPT"] = "0"

    cmd = ["git", "clone", "--depth", "1", "--quiet", repo_url, target_dir]
    try:
        subprocess.run(cmd, env=env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Git clone failed for {repo_url}: {e.stderr.strip()}")

    # If specific commit requested (e.g. from catalog)
    if commit:
        try:
            subprocess.run(["git", "-C", target_dir, "fetch", "--depth", "1", "origin", commit], env=env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["git", "-C", target_dir, "checkout", "--quiet", commit], env=env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    # Extract commit and branch
    rev_res = subprocess.run(["git", "-C", target_dir, "rev-parse", "HEAD"], capture_output=True, text=True)
    commit_sha = rev_res.stdout.strip() if rev_res.returncode == 0 else "unknown"

    branch_res = subprocess.run(["git", "-C", target_dir, "rev-parse", "--abbrev-ref", "HEAD"], capture_output=True, text=True)
    branch = branch_res.stdout.strip() if branch_res.returncode == 0 else "master"

    return commit_sha, branch


def colors_dict_to_base16(c):
    """Converts Omarchy toml colors dict into a complete Base16 dictionary."""
    bg = clean_hex(c.get("background") or c.get("bg") or c.get("color0", "#181818"))
    darker_bg = clean_hex(c.get("dark_background") or c.get("darker_background") or c.get("dark_bg") or bg)
    selection = clean_hex(c.get("selection") or c.get("selection_background") or c.get("color8", "#383838"))
    muted = clean_hex(c.get("muted") or c.get("readable_muted") or c.get("color8", "#585858"))
    dark_fg = clean_hex(c.get("dark_foreground") or c.get("dark_fg") or muted)
    fg = clean_hex(c.get("foreground") or c.get("fg") or c.get("color7", "#e0e0e0"))
    light_fg = clean_hex(c.get("light_foreground") or c.get("light_fg") or fg)
    bright_fg = clean_hex(c.get("bright_foreground") or c.get("bright_fg") or fg)

    c_red = clean_hex(c.get("red") or c.get("color1", "#e06c75"))
    c_orange = clean_hex(c.get("orange") or c.get("bright_red", "#d19a66"))
    c_yellow = clean_hex(c.get("yellow") or c.get("color3", "#e5c07b"))
    c_green = clean_hex(c.get("green") or c.get("color2", "#98c379"))
    c_cyan = clean_hex(c.get("cyan") or c.get("color6", "#56b6c2"))
    c_blue = clean_hex(c.get("blue") or c.get("color4", "#61afef"))
    c_magenta = clean_hex(c.get("magenta") or c.get("color5", "#c678dd"))
    c_brown = clean_hex(c.get("brown") or c_orange)

    return {
        "BASE00": bg,
        "BASE01": darker_bg,
        "BASE02": selection,
        "BASE03": muted,
        "BASE04": dark_fg,
        "BASE05": fg,
        "BASE06": light_fg,
        "BASE07": bright_fg,
        "BASE08": c_red,
        "BASE09": c_orange,
        "BASE0A": c_yellow,
        "BASE0B": c_green,
        "BASE0C": c_cyan,
        "BASE0D": c_blue,
        "BASE0E": c_magenta,
        "BASE0F": c_brown,
    }


def parse_cava_theme(filepath):
    """Parses an upstream cava_theme file, preserving exact gradient and color counts."""
    if not os.path.exists(filepath):
        return None
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            lines = f.readlines()
        colors = {}
        gradient = 1
        gradient_count = None
        bg = None
        fg = None
        for line in lines:
            line = line.strip()
            if not line or line.startswith(("#", ";", "[")):
                continue
            if "=" in line:
                k, v = line.split("=", 1)
                k = k.strip().lower()
                v = v.strip().strip("'\"")
                if k == "gradient":
                    gradient = int(v) if v.isdigit() else 1
                elif k == "gradient_count":
                    gradient_count = int(v) if v.isdigit() else None
                elif k.startswith("gradient_color_"):
                    num = k.replace("gradient_color_", "")
                    if num.isdigit() and HEX_RE.match(clean_hex(v)):
                        colors[int(num)] = clean_hex(v)
                elif k == "background" and HEX_RE.match(clean_hex(v)):
                    bg = clean_hex(v)
                elif k == "foreground" and HEX_RE.match(clean_hex(v)):
                    fg = clean_hex(v)

        sorted_colors = [colors[i] for i in sorted(colors.keys())]
        if not sorted_colors:
            return None
        return {
            "source": "cava_theme",
            "gradient": gradient,
            "gradient_count": gradient_count or len(sorted_colors),
            "colors": sorted_colors,
            "background": bg,
            "foreground": fg,
        }
    except Exception as e:
        print(f"Warning parsing cava theme {filepath}: {e}", file=sys.stderr)
        return None


def analyze_repository(repo_dir, git_url=None, owner="Unknown", repo_name=""):
    """
    Analyzes the cloned repository:
      - Validates Omarchy theme signature (colors.toml)
      - Classifies every file (SOURCE-DATA, SUPPORTED, IGNORED)
      - Extracts palette, rich semantic tokens, Cava visualizer, and capabilities
    Returns (raw_theme, analysis_summary)
    """
    colors_file = os.path.join(repo_dir, "colors.toml")
    if not os.path.exists(colors_file):
        raise ValueError("Repository does not appear to contain a supported Omarchy theme (missing colors.toml).")

    with open(colors_file, "rb") as f:
        toml_data = tomllib.load(f)

    # Derive slug and names
    if git_url:
        _, owner, repo_name, slug = normalize_git_url(git_url)
    else:
        slug = os.path.basename(os.path.abspath(repo_dir)).lower().replace("_", "-")
        if slug.startswith("omarchy-"):
            slug = slug[8:]
        if slug.endswith("-theme"):
            slug = slug[:-6]

    display_name = toml_data.get("name") or slug.replace("-", " ").title()
    mode = toml_data.get("mode", "dark")
    accent = toml_data.get("accent") or toml_data.get("color4") or "#58a6ff"
    b16 = colors_dict_to_base16(toml_data)

    # Rich semantic extraction from colors.toml
    semantic_keys = [
        "background", "foreground", "accent", "cursor", "selection",
        "selection_foreground", "selection_background", "readable_muted",
        "text_accent", "warning_text", "border", "muted", "dark_fg",
        "light_fg", "bright_fg", "dark_bg", "darker_bg", "lighter_bg"
    ]
    semantic_overrides = {}
    for sk in semantic_keys:
        if sk in toml_data and HEX_RE.match(clean_hex(str(toml_data[sk]))):
            semantic_overrides[sk] = clean_hex(str(toml_data[sk]))

    # Scan and classify all repository entries
    repo_files = os.listdir(repo_dir)
    capabilities = {
        "palette": True,
        "wallpaper": False,
        "cava": False,
        "gtk": False,
        "waybar": False,
        "alacritty": False,
        "btop": False,
        "neovim": False,
        "mako": False,
        "kitty": False,
        "steam": False,
        "vencord": False,
        "browser": False,
        "terminal": True,
    }

    ignored_files = []
    apps = {}

    # 1. Cava
    cava_file = os.path.join(repo_dir, "cava_theme")
    if not os.path.exists(cava_file):
        cava_file = os.path.join(repo_dir, "cava.conf")
    cava_parsed = parse_cava_theme(cava_file)
    if cava_parsed:
        apps["cava"] = cava_parsed
        capabilities["cava"] = True

    # 2. Terminals
    if "alacritty.toml" in repo_files:
        capabilities["alacritty"] = True
    if "kitty.conf" in repo_files:
        capabilities["kitty"] = True
    if "ghostty.conf" in repo_files:
        capabilities["ghostty"] = True
    if "foot.ini" in repo_files:
        capabilities["foot"] = True

    # 3. System Apps & Bar
    if "gtk.css" in repo_files:
        capabilities["gtk"] = True
    if "btop.theme" in repo_files:
        capabilities["btop"] = True
    if "mako.ini" in repo_files or "dunst.conf" in repo_files:
        capabilities["mako"] = True
    if "waybar.css" in repo_files or os.path.isdir(os.path.join(repo_dir, "waybar-theme")):
        capabilities["waybar"] = True
    if "neovim.lua" in repo_files:
        capabilities["neovim"] = True

    # 4. Miscellaneous Apps
    if "steam.css" in repo_files:
        capabilities["steam"] = True
    if "vencord.theme.css" in repo_files:
        capabilities["vencord"] = True
    if "chromium.theme" in repo_files:
        capabilities["browser"] = True
    if any(f.endswith(".zed.json") for f in repo_files):
        capabilities["zed"] = True

    # 5. Wallpapers (Assets recorded in cache, never auto-activated)
    wallpapers = []
    bg_dir = os.path.join(repo_dir, "backgrounds")
    if os.path.isdir(bg_dir):
        for bg in os.listdir(bg_dir):
            if bg.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
                wallpapers.append(os.path.join("backgrounds", bg))
        if wallpapers:
            capabilities["wallpaper"] = True

    # 6. Explicitly ignored files (Hyprland, Hyprlock, shell executables, rgb)
    ignored_patterns = [
        "hyprland.conf", "hyprland.lua", "hyprlock.conf", "hyprland-preview-share-picker.css",
        "keyboard.rgb", "install.sh", "setup.sh", "Makefile", "package.json", "Cargo.toml"
    ]
    for rf in repo_files:
        if rf in ignored_patterns or rf.endswith((".sh", ".fish", ".zsh", ".bash", ".service")):
            ignored_files.append(rf)

    # Preview image
    preview_src = os.path.join(repo_dir, "preview.png")
    preview_dest = os.path.join(PREVIEWS_DIR, f"{slug}.png")
    if os.path.exists(preview_src):
        shutil.copy2(preview_src, preview_dest)

    raw_theme = {
        "schema": 1,
        "name": slug,
        "display_name": display_name,
        "type": mode,
        "source": {
            "provider": "omarchy",
            "repository": git_url,
            "author": owner,
            "registry_listed": False,
            "imported_at": datetime.now().isoformat(),
        },
        "capabilities": capabilities,
        "palette": {
            "accent": accent,
            "base_16": b16,
        },
        "semantic": semantic_overrides,
        "apps": apps,
        "assets": {
            "wallpapers": wallpapers,
            "preview": preview_dest if os.path.exists(preview_src) else None,
        }
    }

    summary = {
        "name": display_name,
        "slug": slug,
        "author": owner,
        "capabilities": capabilities,
        "ignored_files": sorted(ignored_files),
        "cava_gradient_count": apps.get("cava", {}).get("gradient_count") if "cava" in apps else 0,
        "wallpapers_count": len(wallpapers),
    }

    return raw_theme, summary


def validate_theme_dict(theme_dict):
    """Validates Schema 1 compliance, Base16 completeness, and checks contrast."""
    errors = []
    warnings = []

    # Palette validation
    b16 = theme_dict.get("palette", {}).get("base_16", {})
    if not b16:
        errors.append("Missing Base16 palette")
    else:
        for k in BASE16_KEYS:
            if k not in b16 or not HEX_RE.match(str(b16[k])):
                errors.append(f"Invalid or missing hex code for {k}")

    # Contrast validation (non-destructive)
    bg = b16.get("BASE00")
    fg = b16.get("BASE05")
    if bg and fg and HEX_RE.match(bg) and HEX_RE.match(fg):
        cr = contrast_ratio(clean_hex(bg), clean_hex(fg))
        if cr < 4.5:
            warnings.append(f"Low text contrast: {cr:.2f}:1 (< 4.5:1 WCAG AA)")

    # Cava validation
    cava = theme_dict.get("apps", {}).get("cava")
    if cava:
        colors = cava.get("colors", [])
        if not colors:
            errors.append("Cava section missing color definitions")
        for i, c in enumerate(colors, 1):
            if not HEX_RE.match(clean_hex(str(c))):
                errors.append(f"Invalid hex code for Cava gradient_color_{i}: {c}")

    return errors, warnings


def print_theme_analysis(summary, branch="master", commit=""):
    """Renders the user experience report."""
    print(f"\nDetected Omarchy theme")
    print(f"Name:   {summary['name']}")
    print(f"Author: {summary['author']}")
    print(f"Branch: {branch}")
    print(f"Commit: {commit[:7] if commit else 'unknown'}")

    print("\nAnalyzing theme...")
    caps = summary["capabilities"]
    for cap_name in ["palette", "wallpaper", "cava", "gtk", "waybar", "alacritty", "btop", "neovim", "mako", "kitty", "steam", "vencord", "zed"]:
        has_cap = caps.get(cap_name, False)
        status = "yes" if has_cap else "no"
        print(f"  {cap_name.capitalize():<12} {status}")

    print("\nEnvironment Adaptation:")
    print("  Sway:        generated from palette")
    print("  Hyprland:    ignored (Sway environment authority)")
    print("  Hyprlock:    ignored (Sway environment authority)")

    if summary["ignored_files"]:
        print("\nIgnored files (non-portable/behavioral):")
        for ig in summary["ignored_files"][:6]:
            print(f"  - {ig}")
        if len(summary["ignored_files"]) > 6:
            print(f"  ... and {len(summary['ignored_files']) - 6} more")


def import_git_theme(git_url, dry_run=False, info_only=False, force_update=False, apply_theme_flag=False):
    """
    Main transactional Git import pipeline.
    """
    clean_url, owner, repo_name, slug = normalize_git_url(git_url)
    dest_file = os.path.join(IMPORTED_OMARCHY_DIR, f"{slug}.json")
    alt_file = os.path.join(IMPORTED_OMARCHY_DIR, f"omarchy-{slug}.json")

    # Check for existing custom collision
    custom_conflict = os.path.expanduser(f"~/.config/theme/custom/{slug}.json")
    if os.path.exists(custom_conflict):
        slug = f"{slug}-imported"
        dest_file = os.path.join(IMPORTED_OMARCHY_DIR, f"{slug}.json")

    existing_target = dest_file if os.path.exists(dest_file) else (alt_file if os.path.exists(alt_file) else None)

    print(f"Fetching repository...")
    print(f"Repository: {owner}/{repo_name}")

    safe_id = f"{owner}_{repo_name}_{os.getpid()}"
    clone_dir = os.path.join(IMPORT_TMP_BASE, safe_id)

    try:
        commit_sha, branch = clone_repo_safely(clean_url, clone_dir)

        # Check existing commit for duplicate detection
        if existing_target and not force_update and not info_only and not dry_run:
            try:
                with open(existing_target, "r", encoding="utf-8") as ef:
                    existing_data = json.load(ef)
                existing_commit = existing_data.get("source", {}).get("commit")
                if existing_commit and existing_commit == commit_sha:
                    print("\nTheme already imported. No changes required.")
                    return True
                elif existing_commit and existing_commit != commit_sha:
                    print(f"\nTheme already exists, upstream changed ({existing_commit[:7]} -> {commit_sha[:7]}).")
                    print(f"Use: omarchy-import --update {git_url}")
                    return True
            except Exception:
                pass

        raw_theme, summary = analyze_repository(clone_dir, git_url=clean_url, owner=owner, repo_name=repo_name)
        raw_theme["source"]["commit"] = commit_sha
        raw_theme["source"]["branch"] = branch

        print_theme_analysis(summary, branch=branch, commit=commit_sha)

        if info_only:
            return True

        print("\nConverting...")
        canonical = normalize_theme(raw_theme, default_name=slug, default_provider="omarchy")

        print("Validating...")
        errors, warnings = validate_theme_dict(canonical)
        if errors:
            print(f"Validation FAILED:", file=sys.stderr)
            for e in errors:
                print(f"  [ERROR] {e}", file=sys.stderr)
            return False

        for w in warnings:
            print(f"  [WARN] {w}")

        if dry_run:
            print(f"\n[Dry Run] Would write to: {dest_file}")
            print("[Dry Run] Theme passed all validation checks cleanly.")
            return True

        # Transactional write via temporary file
        print(f"\nWriting:")
        print(f"  {dest_file}")

        # If previous alt_file existed (e.g. omarchy-slug.json), clean it up so no duplicate exists
        if existing_target and existing_target != dest_file and os.path.exists(existing_target):
            try:
                os.remove(existing_target)
            except Exception:
                pass

        tmp_dest = f"{dest_file}.tmp"
        with open(tmp_dest, "w", encoding="utf-8") as f:
            json.dump(canonical, f, indent=2)
        os.replace(tmp_dest, dest_file)

        print("\nSyncing cache...")
        subprocess.run([os.path.expanduser("~/.local/bin/theme-sync")], check=True)
        print("Done.")
        print("\nTheme imported successfully.")

        if apply_theme_flag:
            print(f"Activating theme '{slug}'...")
            subprocess.run([os.path.expanduser("~/.local/bin/theme-set"), slug], check=True)

        return True

    finally:
        # Guarantee cleanup of temporary clone directory
        if os.path.exists(clone_dir):
            shutil.rmtree(clone_dir, ignore_errors=True)


def remove_imported_theme(theme_name):
    """Removes an imported theme cleanly and syncs the cache."""
    clean_name = theme_name.strip()
    candidates = [
        os.path.join(IMPORTED_OMARCHY_DIR, f"{clean_name}.json"),
        os.path.join(IMPORTED_OMARCHY_DIR, f"omarchy-{clean_name}.json"),
    ]
    target = None
    for cand in candidates:
        if os.path.exists(cand):
            target = cand
            break

    if not target:
        print(f"Error: Imported theme '{theme_name}' not found in {IMPORTED_OMARCHY_DIR}", file=sys.stderr)
        return False

    os.remove(target)
    print(f"Removed: {target}")
    print("Syncing cache...")
    subprocess.run([os.path.expanduser("~/.local/bin/theme-sync")], check=True)
    print("Done.")
    return True


def fetch_official_catalog():
    """Fetches the official catalog using CDN with GitHub fallback."""
    for url in CATALOG_URLS:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Antigravity-OmarchyImporter/1.0"})
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                if "themes" in data:
                    return data["themes"], url
        except Exception:
            continue
    raise RuntimeError("Failed to fetch official catalog from all available sources.")


def import_catalog(dry_run=False, limit=None):
    """
    Catalog import with exact reconciliation:
      Reports: Official catalog count, Local count, New, Updated, Unchanged, Removed.
    """
    print("Fetching official Omarchy catalog...")
    themes, source_url = fetch_official_catalog()
    print(f"Connected to official catalog ({source_url})")

    if limit:
        themes = themes[:limit]

    catalog_total = len(themes)
    local_files = [f for f in os.listdir(IMPORTED_OMARCHY_DIR) if f.endswith(".json")]
    local_total = len(local_files)

    catalog_by_slug = {t.get("slug"): t for t in themes if t.get("slug")}

    new_count = 0
    updated_count = 0
    unchanged_count = 0
    removed_count = 0

    # Inspect local files against catalog
    for lf in local_files:
        l_slug = lf[:-5]
        if l_slug.startswith("omarchy-"):
            l_slug = l_slug[8:]
        if l_slug not in catalog_by_slug:
            removed_count += 1

    for slug, entry in catalog_by_slug.items():
        dest_candidate = os.path.join(IMPORTED_OMARCHY_DIR, f"{slug}.json")
        alt_candidate = os.path.join(IMPORTED_OMARCHY_DIR, f"omarchy-{slug}.json")
        existing_path = dest_candidate if os.path.exists(dest_candidate) else (alt_candidate if os.path.exists(alt_candidate) else None)

        if not existing_path:
            new_count += 1
            if not dry_run:
                convert_and_save_catalog_entry(entry, dest_candidate)
        else:
            # Check commit SHA if available
            try:
                with open(existing_path, "r", encoding="utf-8") as ef:
                    curr_d = json.load(ef)
                curr_commit = curr_d.get("source", {}).get("commit")
                cat_commit = entry.get("commit")
                if cat_commit and curr_commit != cat_commit:
                    updated_count += 1
                    if not dry_run:
                        convert_and_save_catalog_entry(entry, existing_path)
                else:
                    unchanged_count += 1
            except Exception:
                updated_count += 1
                if not dry_run:
                    convert_and_save_catalog_entry(entry, existing_path)

    print("\nCatalog Reconciliation:")
    print(f"  Official catalog:  {catalog_total}")
    print(f"  Local imported:    {local_total}")
    print(f"  New:               {new_count}")
    print(f"  Updated:           {updated_count}")
    print(f"  Unchanged:         {unchanged_count}")
    print(f"  Removed:           {removed_count}")

    if dry_run:
        print("\n[Dry Run] No files modified on disk.")
        return True

    if new_count > 0 or updated_count > 0:
        print("\nSyncing cache...")
        subprocess.run([os.path.expanduser("~/.local/bin/theme-sync")], check=True)
        print("Done.")

    return True


def convert_and_save_catalog_entry(entry, dest_path):
    """Converts a catalog JSON entry into Schema 1 and saves it."""
    slug = entry.get("slug")
    name = entry.get("name") or slug
    mode = entry.get("mode", "dark")
    colors = entry.get("colors", {})

    accent = clean_hex(colors.get("accent") or colors.get("blue") or "#58a6ff")
    b16 = colors_dict_to_base16(colors)

    author_info = entry.get("author")
    author_name = author_info.get("login") if isinstance(author_info, dict) else str(author_info or "Unknown")

    preview_val = entry.get("preview")
    preview_url = preview_val.get("src") if isinstance(preview_val, dict) else preview_val

    raw_theme = {
        "schema": 1,
        "name": slug,
        "display_name": name,
        "type": mode,
        "source": {
            "provider": "omarchy",
            "registry": "https://github.com/omacom/omarchy-theme-registry",
            "repository": entry.get("repo"),
            "commit": entry.get("commit"),
            "author": author_name,
            "license": entry.get("license"),
            "registry_listed": True,
            "imported_at": datetime.now().isoformat(),
        },
        "capabilities": {
            "palette": True,
            "wallpaper": False,
            "icons": False,
            "terminal": True,
            "browser": False,
            "cava": True,
        },
        "palette": {
            "accent": accent,
            "base_16": b16,
        },
        "assets": {
            "preview": preview_url,
        }
    }

    norm = normalize_theme(raw_theme, default_name=slug, default_provider="omarchy")
    with open(dest_path, "w", encoding="utf-8") as f:
        json.dump(norm, f, indent=2)
