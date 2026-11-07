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
import html as html_module
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime

import tomllib
import yaml


from theme_engine.schema import (
    normalize_theme,
    clean_hex,
    HEX_RE,
    BASE16_KEYS,
    contrast_ratio,
    blend_colors,
    relative_luminance,
)

REGISTRY_CATALOG_URLS = [
    "https://themes.omarchy.org/v1/catalog.min.json",
    "https://themes.omarchy.org/v1/catalog.json",
]

GALLERY_URLS = [
    "https://raw.githubusercontent.com/omacom/omarchy-site/master/themes/index.html",
    "https://raw.githubusercontent.com/omacom/omarchy-site/main/themes/index.html",
    "https://omarchy.org/themes/",
]

# Legacy endpoints are last-resort compatibility fallbacks only.
LEGACY_CATALOG_URLS = [
    "https://cdn.themes.omarchy.org/v1/catalog.json",
    "https://raw.githubusercontent.com/omacom/omarchy-theme-marketplace/master/data/catalog.json",
]

IMPORTED_OMARCHY_DIR = os.path.expanduser("~/.config/theme/imported/omarchy")
PREVIEWS_DIR = os.path.expanduser("~/.cache/theme/previews")
IMPORT_TMP_BASE = os.path.expanduser("~/.cache/theme/import-tmp")
WALLPAPERS_CACHE = os.path.expanduser("~/.local/share/theme/wallpapers/upstream")
REPOSITORY_DISCOVERY_VERSION = 3

os.makedirs(IMPORTED_OMARCHY_DIR, exist_ok=True)
os.makedirs(PREVIEWS_DIR, exist_ok=True)
os.makedirs(IMPORT_TMP_BASE, exist_ok=True)
os.makedirs(WALLPAPERS_CACHE, exist_ok=True)


def sync_to_chezmoi_source(target_path):
    """Persist an imported live file into chezmoi when this machine uses it."""
    if not shutil.which("chezmoi") or not os.path.exists(target_path):
        return
    try:
        subprocess.run(
            ["chezmoi", "add", target_path],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=10,
        )
    except Exception as exc:
        print(f"Warning: could not sync {target_path} into chezmoi: {exc}", file=sys.stderr)


def remove_from_chezmoi_source(target_path):
    """Remove the managed source copy for a target file, if one exists."""
    if not shutil.which("chezmoi"):
        return
    try:
        proc = subprocess.run(
            ["chezmoi", "source-path", target_path],
            capture_output=True,
            text=True,
            timeout=5,
        )
        source_path = proc.stdout.strip() if proc.returncode == 0 else ""
        if source_path and os.path.isfile(source_path):
            os.remove(source_path)
    except Exception as exc:
        print(f"Warning: could not remove chezmoi source for {target_path}: {exc}", file=sys.stderr)


def sync_import_directory_to_chezmoi():
    """Batch-persist the imported-theme directory with one chezmoi process."""
    if not shutil.which("chezmoi") or not os.path.isdir(IMPORTED_OMARCHY_DIR):
        return
    try:
        subprocess.run(
            ["chezmoi", "add", "--recursive", IMPORTED_OMARCHY_DIR],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=30,
        )
    except Exception as exc:
        print(f"Warning: could not batch-sync imported themes into chezmoi: {exc}", file=sys.stderr)


def prune_chezmoi_import_source_to_live():
    """Make the managed imported-theme file set match the live imported set."""
    if not shutil.which("chezmoi"):
        return
    try:
        proc = subprocess.run(
            ["chezmoi", "source-path"], capture_output=True, text=True, timeout=5, check=True
        )
        source_dir = os.path.join(proc.stdout.strip(), "dot_config/theme/imported/omarchy")
        if not os.path.isdir(source_dir):
            return
        live_names = {f for f in os.listdir(IMPORTED_OMARCHY_DIR) if f.endswith(".json")}
        for filename in os.listdir(source_dir):
            if filename.endswith(".json") and filename not in live_names:
                os.remove(os.path.join(source_dir, filename))
    except Exception as exc:
        print(f"Warning: could not prune chezmoi imported-theme source: {exc}", file=sys.stderr)


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

    # If the validated registry pins a commit, failure to fetch/check it out is
    # fatal. Falling back silently to repository HEAD would defeat validation.
    if commit:
        try:
            subprocess.run(
                ["git", "-C", target_dir, "fetch", "--depth", "1", "origin", str(commit)],
                env=env,
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
                text=True,
            )
            subprocess.run(
                ["git", "-C", target_dir, "checkout", "--quiet", str(commit)],
                env=env,
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
                text=True,
            )
        except subprocess.CalledProcessError as exc:
            raise RuntimeError(
                f"Could not checkout validated catalog commit {commit} for {repo_url}: "
                f"{(exc.stderr or '').strip()}"
            ) from exc

    # Extract commit and branch
    rev_res = subprocess.run(["git", "-C", target_dir, "rev-parse", "HEAD"], capture_output=True, text=True)
    commit_sha = rev_res.stdout.strip() if rev_res.returncode == 0 else "unknown"

    branch_res = subprocess.run(["git", "-C", target_dir, "rev-parse", "--abbrev-ref", "HEAD"], capture_output=True, text=True)
    branch = branch_res.stdout.strip() if branch_res.returncode == 0 else "master"

    return commit_sha, branch


def colors_dict_to_base16(c):
    """Converts colors dict into a complete Base16 dictionary."""
    # Check if direct BASE00..BASE0F are already present
    b16_direct = {}
    for k in BASE16_KEYS:
        if k in c and HEX_RE.match(clean_hex(str(c[k]))):
            b16_direct[k] = clean_hex(str(c[k]))
        elif k.lower() in c and HEX_RE.match(clean_hex(str(c[k.lower()]))):
            b16_direct[k] = clean_hex(str(c[k.lower()]))

    if len(b16_direct) == 16:
        return b16_direct

    bg = clean_hex(c.get("background") or c.get("bg") or c.get("color0", "#181818"))
    darker_bg = clean_hex(c.get("dark_background") or c.get("darker_background") or c.get("dark_bg") or c.get("color0") or bg)
    raw_sel = clean_hex(c.get("selection") or c.get("selection_background") or c.get("selected_bg") or c.get("color8", "#383838"))
    accent = clean_hex(c.get("accent") or c.get("color4") or "#58a6ff")
    if relative_luminance(bg) < 0.35:
        if relative_luminance(raw_sel) > 0.25:
            selection = blend_colors(bg, accent, 0.14)
        else:
            selection = raw_sel
    else:
        if relative_luminance(raw_sel) < 0.40:
            selection = blend_colors(bg, "#000000", 0.10)
        else:
            selection = raw_sel
    muted = clean_hex(c.get("muted") or c.get("readable_muted") or c.get("color8", "#585858"))
    dark_fg = clean_hex(c.get("dark_foreground") or c.get("dark_fg") or c.get("color7") or muted)
    fg = clean_hex(c.get("foreground") or c.get("fg") or c.get("color7", "#e0e0e0"))
    light_fg = clean_hex(c.get("light_foreground") or c.get("light_fg") or c.get("color7") or fg)
    bright_fg = clean_hex(c.get("bright_foreground") or c.get("bright_fg") or c.get("color15") or fg)

    c_red = clean_hex(c.get("red") or c.get("color1", "#e06c75"))
    c_orange = clean_hex(c.get("orange") or c.get("bright_red") or c.get("color9", "#d19a66"))
    c_yellow = clean_hex(c.get("yellow") or c.get("color3", "#e5c07b"))
    c_green = clean_hex(c.get("green") or c.get("color2", "#98c379"))
    c_cyan = clean_hex(c.get("cyan") or c.get("color6", "#56b6c2"))
    c_blue = clean_hex(c.get("blue") or c.get("color4", "#61afef"))
    c_magenta = clean_hex(c.get("magenta") or c.get("color5", "#c678dd"))
    c_brown = clean_hex(c.get("brown") or c.get("bright_magenta") or c.get("color13") or c_orange)

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
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
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


def find_candidate_files(repo_dir, max_depth=6):
    """
    Recursively scans repo_dir up to max_depth (skipping hidden and build dirs).
    Returns a dict of discovered candidate files grouped by format/app.
    """
    candidates = {
        "colors_toml": [],
        "palette_toml": [],
        "yaml_palette": [],
        "alacritty": [],
        "kitty": [],
        "ghostty": [],
        "btop": [],
        "foot": [],
        "cava": [],
        "gtk": [],
        "waybar": [],
        "mako": [],
        "dunst": [],
        "swayosd": [],
        "walker": [],
        "rofi": [],
        "neovim": [],
        "steam": [],
        "vencord": [],
        "browser": [],
        "icons": [],
        "zed": [],
        "wallpapers": [],
        "wallpaper_fallbacks": [],
        "previews": [],
        "ignored": [],
    }

    skip_dirs = {".git", ".github", ".cache", "node_modules", "target", "build", "dist", ".svn", ".hg"}
    ignored_exact = {
        "hyprland.conf", "hyprland.lua", "hyprlock.conf", "hypridle.conf",
        "hyprpaper.conf", "hyprland-preview-share-picker.css", "keyboard.rgb",
        "install.sh", "setup.sh", "Makefile", "package.json", "Cargo.toml",
    }

    repo_dir_abs = os.path.abspath(repo_dir)

    for root, dirs, files in os.walk(repo_dir_abs):
        rel_root = os.path.relpath(root, repo_dir_abs)
        parts = rel_root.split(os.sep) if rel_root != "." else []

        if len(parts) >= max_depth:
            dirs[:] = []
            continue
        dirs[:] = [d for d in dirs if d not in skip_dirs and not d.startswith(".")]

        for f in files:
            f_lower = f.lower()
            rel_file = os.path.relpath(os.path.join(root, f), repo_dir_abs)

            # Check ignored scripts and window manager configs
            if f_lower in ignored_exact or f_lower.endswith((".sh", ".bash", ".zsh", ".fish", ".service")):
                candidates["ignored"].append(rel_file)
                continue

            # Preview discovery
            if f_lower in ("preview.png", "preview.jpg", "preview.jpeg", "preview.webp") or (
                "preview" in f_lower and f_lower.endswith((".png", ".jpg", ".jpeg", ".webp"))
            ):
                candidates["previews"].append(rel_file)
                continue

            # Wallpaper discovery. Conventional background/wallpaper paths win.
            # If a repository stores wallpapers elsewhere, retain non-UI images as
            # fallback candidates and use them only after explicit paths are exhausted.
            if f_lower.endswith((".png", ".jpg", ".jpeg", ".webp")):
                low_path = rel_file.replace("\\", "/").lower()
                if any(w in low_path for w in ("background", "wallpaper", "bg/")):
                    candidates["wallpapers"].append(rel_file)
                    continue
                ui_asset_tokens = (
                    "preview", "screenshot", "thumbnail", "thumb", "logo",
                    "icon", "badge", "avatar", "banner", "social", "readme",
                    "unlock", "lockscreen", "lock-screen", "lock_screen", "splash",
                )
                if not any(token in low_path for token in ui_asset_tokens):
                    candidates["wallpaper_fallbacks"].append(rel_file)
                    continue

            # Palette files
            if f_lower == "colors.toml":
                candidates["colors_toml"].append(rel_file)
            elif f_lower in ("palette.toml", "theme.toml", "colorscheme.toml"):
                candidates["palette_toml"].append(rel_file)
            elif f_lower in ("base16.yaml", "base16.yml", "base24.yaml", "base24.yml", "colors.yaml", "colors.yml", "palette.yaml", "palette.yml"):
                candidates["yaml_palette"].append(rel_file)
            elif f_lower.startswith("alacritty") and f_lower.endswith((".toml", ".yml", ".yaml")):
                candidates["alacritty"].append(rel_file)
            elif f_lower == "kitty.conf":
                candidates["kitty"].append(rel_file)
            elif f_lower in ("ghostty.conf", "ghostty-theme"):
                candidates["ghostty"].append(rel_file)
            elif f_lower in ("btop.theme", "btop.conf") or "btop" in rel_file:
                candidates["btop"].append(rel_file)
            elif f_lower == "foot.ini":
                candidates["foot"].append(rel_file)
            elif f_lower in ("cava_theme", "cava.conf") or "cava" in rel_file:
                candidates["cava"].append(rel_file)
            elif f_lower.endswith(".css") and "gtk" in rel_file.lower():
                candidates["gtk"].append(rel_file)
            elif "waybar" in rel_file.lower() and f_lower.endswith((".css", ".json")):
                candidates["waybar"].append(rel_file)
            elif f_lower in ("mako.ini", "mako.conf"):
                candidates["mako"].append(rel_file)
            elif f_lower == "dunst.conf":
                candidates["dunst"].append(rel_file)
            elif f_lower == "swayosd.css":
                candidates["swayosd"].append(rel_file)
            elif f_lower == "walker.css":
                candidates["walker"].append(rel_file)
            elif f_lower.endswith(".rasi"):
                candidates["rofi"].append(rel_file)
            elif f_lower == "neovim.lua" or "nvim" in rel_file:
                candidates["neovim"].append(rel_file)
            elif f_lower == "steam.css":
                candidates["steam"].append(rel_file)
            elif f_lower == "vencord.theme.css":
                candidates["vencord"].append(rel_file)
            elif f_lower == "chromium.theme":
                candidates["browser"].append(rel_file)
            elif f_lower == "icons.theme":
                candidates["icons"].append(rel_file)
            elif f_lower.endswith(".zed.json"):
                candidates["zed"].append(rel_file)

    # Sort root files first
    for k in candidates:
        candidates[k].sort(key=lambda p: (p.count(os.sep), len(p)))

    return candidates


def select_wallpaper_candidates(paths, limit=None):
    """Return deterministic wallpaper paths, optionally capped by `limit`.

    Prefer the repository's canonical `backgrounds/` directory, followed by
    conventional wallpaper directories, other non-UI images, and finally
    historical/alternate/portrait assets. Omarchy import calls this uncapped so
    every relevant discovered repository image is retained.
    """
    def natural_key(value):
        value = value.replace("\\", "/").lower()
        return re.sub(r"\d+", lambda m: f"{int(m.group()):08d}", value)

    def priority(path):
        p = path.replace("\\", "/").lstrip("./")
        low = p.lower()
        top = low.split("/", 1)[0]
        historical = any(token in low for token in (
            "old-background", "backgrounds-old", "backgrounds_alt",
            "backgrounds-alt", "vertical", "portrait",
        ))
        if top == "backgrounds" and not historical:
            bucket = 0
        elif top in {"wallpapers", "wallpaper"} and not historical:
            bucket = 1
        elif not historical and ("/backgrounds/" in f"/{low}" or "/wallpapers/" in f"/{low}"):
            bucket = 2
        elif historical:
            bucket = 4
        else:
            bucket = 3
        return (bucket, natural_key(p))

    selected = []
    seen = set()
    for path in sorted(paths or [], key=priority):
        normalized = path.replace("\\", "/")
        key = normalized.casefold()
        if key in seen:
            continue
        seen.add(key)
        selected.append(normalized)
        if limit is not None and len(selected) >= max(0, int(limit)):
            break
    return selected


def _safe_wallpaper_filename(index, source_path):
    base = os.path.basename(source_path)
    base = re.sub(r"[^A-Za-z0-9._@+-]+", "-", base).strip("-") or f"wallpaper-{index}"
    return f"{index:02d}-{base}"


def persist_repository_wallpapers(repo_dir, slug, canonical):
    """Persist only the chosen images from the repository before its clone is deleted."""
    candidates = list((canonical.get("assets") or {}).get("wallpapers") or [])
    if not candidates:
        return

    source = canonical.get("source") or {}
    destination = os.path.join(WALLPAPERS_CACHE, slug)
    stage = tempfile.mkdtemp(prefix=f".{slug}-wallpapers-", dir=WALLPAPERS_CACHE)
    files = []
    try:
        for index, relative in enumerate(candidates, 1):
            relative = str(relative).replace("\\", "/").lstrip("./")
            source_file = os.path.realpath(os.path.join(repo_dir, relative))
            repo_root = os.path.realpath(repo_dir) + os.sep
            if not source_file.startswith(repo_root) or not os.path.isfile(source_file):
                continue
            filename = _safe_wallpaper_filename(index, relative)
            shutil.copy2(source_file, os.path.join(stage, filename))
            files.append({"source": relative, "file": filename})

        if not files:
            raise RuntimeError(f"{slug}: wallpaper candidates were recorded but no repository image could be preserved")

        manifest = {
            "theme": slug,
            "repository": str(source.get("repository") or ""),
            "ref": str(source.get("commit") or source.get("branch") or "main"),
            "discovery_version": REPOSITORY_DISCOVERY_VERSION,
            "candidates": candidates,
            "files": files,
        }
        with open(os.path.join(stage, "manifest.json"), "w", encoding="utf-8") as handle:
            json.dump(manifest, handle, indent=2, sort_keys=True)
            handle.write("\n")

        backup = destination + f".old-{os.getpid()}"
        if os.path.exists(backup):
            shutil.rmtree(backup, ignore_errors=True)
        if os.path.isdir(destination):
            os.replace(destination, backup)
        try:
            os.replace(stage, destination)
            stage = None
        except Exception:
            if os.path.isdir(backup) and not os.path.exists(destination):
                os.replace(backup, destination)
            raise
        shutil.rmtree(backup, ignore_errors=True)
    finally:
        if stage and os.path.isdir(stage):
            shutil.rmtree(stage, ignore_errors=True)


def parse_alacritty_dict(data):
    """Extracts flat colors dictionary from Alacritty dictionary structure."""
    c = {}
    colors = data.get("colors", {}) if isinstance(data, dict) else {}
    primary = colors.get("primary", {})
    cursor = colors.get("cursor", {})
    normal = colors.get("normal", {})
    bright = colors.get("bright", {})
    selection = colors.get("selection", {})

    if "background" in primary:
        c["background"] = clean_hex(primary["background"])
    if "foreground" in primary:
        c["foreground"] = clean_hex(primary["foreground"])
    if "cursor" in cursor:
        c["cursor"] = clean_hex(cursor["cursor"])
        c["accent"] = c["cursor"]
    if "text" in cursor:
        c["cursor_text"] = clean_hex(cursor["text"])
    if isinstance(selection, dict) and "background" in selection:
        c["selection"] = clean_hex(selection["background"])
    if isinstance(selection, dict) and "text" in selection:
        c["selection_foreground"] = clean_hex(selection["text"])

    normal_map = {
        "black": "color0",
        "red": "color1",
        "green": "color2",
        "yellow": "color3",
        "blue": "color4",
        "magenta": "color5",
        "cyan": "color6",
        "white": "color7",
    }
    for name, code in normal_map.items():
        if name in normal:
            val = clean_hex(normal[name])
            c[code] = val
            c[name] = val

    bright_map = {
        "black": ("color8", "muted"),
        "red": ("color9", "bright_red", "orange"),
        "green": ("color10", "bright_green"),
        "yellow": ("color11", "bright_yellow"),
        "blue": ("color12", "bright_blue"),
        "magenta": ("color13", "bright_magenta", "brown"),
        "cyan": ("color14", "bright_cyan"),
        "white": ("color15", "bright_white", "bright_fg"),
    }
    for name, codes in bright_map.items():
        if name in bright:
            val = clean_hex(bright[name])
            if isinstance(codes, tuple):
                for cd in codes:
                    c[cd] = val
            else:
                c[codes] = val

    return c


def parse_toml_colors_file(filepath):
    """Parses a TOML file that contains color definitions."""
    try:
        with open(filepath, "rb") as f:
            data = tomllib.load(f)
        if "colors" in data and isinstance(data["colors"], dict):
            if "primary" in data["colors"] or "normal" in data["colors"]:
                return parse_alacritty_dict(data)
            merged = dict(data)
            merged.update(data["colors"])
            return merged
        return data
    except Exception as e:
        print(f"Warning parsing TOML {filepath}: {e}", file=sys.stderr)
        return None


def parse_yaml_palette_file(filepath):
    """Parses Base16/Base24 or colors YAML file."""
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        if not isinstance(data, dict):
            return None
        res = {}
        b16_found = False
        for k, v in data.items():
            k_lower = str(k).lower()
            if k_lower.startswith("base0") or k_lower.startswith("base1"):
                res[k.upper()] = clean_hex(str(v))
                b16_found = True
            elif k_lower in ("scheme", "name"):
                res["name"] = str(v)
            elif k_lower == "author":
                res["author"] = str(v)
        if b16_found:
            return res

        if "palette" in data and isinstance(data["palette"], dict):
            return data["palette"]
        if "colors" in data and isinstance(data["colors"], dict):
            return data["colors"]
        return data
    except Exception as e:
        print(f"Warning parsing YAML {filepath}: {e}", file=sys.stderr)
        return None


def parse_alacritty_file(filepath):
    try:
        if filepath.endswith((".yml", ".yaml")):
            with open(filepath, "r", encoding="utf-8") as f:
                data = yaml.safe_load(f)
        else:
            with open(filepath, "rb") as f:
                data = tomllib.load(f)
        return parse_alacritty_dict(data)
    except Exception as e:
        print(f"Warning parsing Alacritty {filepath}: {e}", file=sys.stderr)
        return None


def parse_kitty_file(filepath):
    try:
        c = {}
        theme_values = {}
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split()
                if len(parts) < 2:
                    continue
                k, v = parts[0].lower(), parts[1]
                val = clean_hex(v)
                if not HEX_RE.match(val):
                    continue
                theme_values[k] = val
                if k in ("background", "bg"):
                    c["background"] = val
                elif k in ("foreground", "fg"):
                    c["foreground"] = val
                elif k in ("cursor", "cursor_color"):
                    c["cursor"] = val
                    c["accent"] = val
                elif k in ("cursor_text_color", "cursor_text"):
                    c["cursor_text"] = val
                elif k in ("selection_background", "selection_bg"):
                    c["selection"] = val
                    c["selection_background"] = val
                elif k in ("selection_foreground", "selection_fg"):
                    c["selection_foreground"] = val
                elif k.startswith("color") and k[5:].isdigit():
                    c[k] = val
        if theme_values:
            c["theme"] = theme_values
        return c if len(c) >= 4 else None
    except Exception as e:
        print(f"Warning parsing Kitty {filepath}: {e}", file=sys.stderr)
        return None


def parse_ghostty_file(filepath):
    try:
        c = {}
        theme_values = {}
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" not in line:
                    continue
                k, v = line.split("=", 1)
                k, v = k.strip().lower(), v.strip().strip("'\"")
                if k == "palette" and "=" in v:
                    idx, color = v.split("=", 1)
                    idx, color = idx.strip(), color.strip()
                    if idx.isdigit() and HEX_RE.match(clean_hex(color)):
                        val = clean_hex(color)
                        c[f"color{idx}"] = val
                        theme_values[f"palette_{idx}"] = val
                elif HEX_RE.match(clean_hex(v)):
                    val = clean_hex(v)
                    theme_values[k] = val
                    if k in ("background", "bg"):
                        c["background"] = val
                    elif k in ("foreground", "fg"):
                        c["foreground"] = val
                    elif k in ("cursor-color", "cursor"):
                        c["cursor"] = val
                        c["accent"] = val
                    elif k in ("cursor-text", "cursor-text-color"):
                        c["cursor_text"] = val
                    elif k in ("selection-background", "selection_bg"):
                        c["selection"] = val
                        c["selection_background"] = val
                    elif k in ("selection-foreground", "selection_fg"):
                        c["selection_foreground"] = val
        if theme_values:
            c["theme"] = theme_values
        return c if len(c) >= 4 else None
    except Exception as e:
        print(f"Warning parsing Ghostty {filepath}: {e}", file=sys.stderr)
        return None


def parse_btop_file(filepath):
    """Parse btop theme colors and preserve the complete authored theme map."""
    try:
        c = {}
        theme_values = {}
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                m = re.match(r'theme\[(\w+)\]\s*=\s*[\'"]?([^\'"]*)[\'"]?', line)
                if not m:
                    continue
                k, raw = m.group(1).lower(), m.group(2).strip()
                if raw == "":
                    theme_values[k] = ""
                    continue
                val = clean_hex(raw)
                if not HEX_RE.match(val):
                    continue
                theme_values[k] = val
                if k == "main_bg":
                    c["background"] = val
                elif k == "main_fg":
                    c["foreground"] = val
                elif k == "title":
                    c["accent"] = val
                elif k == "selected_bg":
                    c["selection"] = val
                    c["selection_background"] = val
                elif k == "selected_fg":
                    c["selection_foreground"] = val
                elif k == "div_line":
                    c["border"] = val
        if theme_values:
            c["theme"] = theme_values
        return c if c else None
    except Exception as e:
        print(f"Warning parsing Btop {filepath}: {e}", file=sys.stderr)
        return None


def parse_mako_file(filepath):
    """Parse unambiguous Mako theme colors; behavior/geometry remain local.

    Omarchy repositories do not consistently place global colors before filter
    sections. Scan the whole file, but accept a color key only when every
    occurrence agrees so a section-specific override cannot become our global
    notification palette by accident.
    """
    try:
        occurrences = {
            "background-color": [],
            "text-color": [],
            "border-color": [],
        }
        with open(filepath, "r", encoding="utf-8", errors="replace") as handle:
            for raw_line in handle:
                line = raw_line.strip()
                if not line or line.startswith(("#", ";")) or "=" not in line:
                    continue
                key, value = [part.strip() for part in line.split("=", 1)]
                if key not in occurrences:
                    continue
                match = re.search(r"#[0-9a-fA-F]{6}", value)
                if match:
                    occurrences[key].append(clean_hex(match.group(0)))
        values = {}
        for key, found in occurrences.items():
            unique = sorted(set(found))
            if len(unique) == 1:
                values[key.replace("-", "_")] = unique[0]
        return values or None
    except Exception as exc:
        print(f"Warning parsing Mako {filepath}: {exc}", file=sys.stderr)
        return None


def parse_chromium_theme(filepath):
    """Parse Omarchy chromium.theme RGB triplet into a canonical frame color."""
    try:
        text = open(filepath, "r", encoding="utf-8", errors="replace").read().strip()
        parts = [part.strip() for part in text.split(",")]
        if len(parts) != 3:
            return None
        rgb = [int(part) for part in parts]
        if any(value < 0 or value > 255 for value in rgb):
            return None
        return {"frame": "#{:02x}{:02x}{:02x}".format(*rgb)}
    except Exception:
        return None


def parse_icon_theme(filepath):
    """Read a requested icon-theme name; runtime applies it only when installed."""
    try:
        value = open(filepath, "r", encoding="utf-8", errors="replace").read().strip()
    except OSError:
        return None
    if not value or len(value) > 128 or "\n" in value or "\r" in value:
        return None
    if not re.fullmatch(r"[A-Za-z0-9._ +@-]+", value):
        return None
    return {"name": value}


def build_authored_apps(repo_dir, candidates):
    """Extract safe, color-only app intent from upstream theme files.

    Do not carry fonts, geometry, keybindings, shell commands, or compositor
    settings from third-party repositories. Parsed color/profile data can be
    merged into local templates without surrendering workstation ownership.
    """
    apps = {}
    parsers = {
        "alacritty": parse_alacritty_file,
        "kitty": parse_kitty_file,
        "ghostty": parse_ghostty_file,
        "btop": parse_btop_file,
        "cava": parse_cava_theme,
        "mako": parse_mako_file,
        "browser": parse_chromium_theme,
        "icons": parse_icon_theme,
    }
    for app, parser in parsers.items():
        paths = list(candidates.get(app) or [])
        if not paths:
            continue
        relative = paths[0]
        parsed = parser(os.path.join(repo_dir, relative))
        if not parsed:
            continue
        if app in {"cava", "mako", "browser", "icons"}:
            profile = dict(parsed)
            profile["source_file"] = relative.replace("\\", "/")
        else:
            profile = {
                "source_file": relative.replace("\\", "/"),
                "colors": parsed,
            }
        apps[app] = profile
    return apps


def resolve_theme_palette(repo_dir, candidates):
    """
    Dynamically identifies the best palette source and enriches semantic tokens.
    Returns (primary_data, format_desc, mode, display_name)
    """
    primary_data = None
    format_desc = "Unknown"
    primary_path = None

    if candidates["colors_toml"]:
        primary_path = candidates["colors_toml"][0]
        primary_data = parse_toml_colors_file(os.path.join(repo_dir, primary_path))
        format_desc = f"Native Omarchy ({primary_path})"
    elif candidates["palette_toml"]:
        primary_path = candidates["palette_toml"][0]
        primary_data = parse_toml_colors_file(os.path.join(repo_dir, primary_path))
        format_desc = f"TOML Palette ({primary_path})"
    elif candidates["yaml_palette"]:
        primary_path = candidates["yaml_palette"][0]
        primary_data = parse_yaml_palette_file(os.path.join(repo_dir, primary_path))
        format_desc = f"YAML Palette ({primary_path})"
    elif candidates["alacritty"]:
        primary_path = candidates["alacritty"][0]
        primary_data = parse_alacritty_file(os.path.join(repo_dir, primary_path))
        format_desc = f"Alacritty Config ({primary_path})"
    elif candidates["kitty"]:
        primary_path = candidates["kitty"][0]
        primary_data = parse_kitty_file(os.path.join(repo_dir, primary_path))
        format_desc = f"Kitty Config ({primary_path})"
    elif candidates["ghostty"]:
        primary_path = candidates["ghostty"][0]
        primary_data = parse_ghostty_file(os.path.join(repo_dir, primary_path))
        format_desc = f"Ghostty Config ({primary_path})"
    elif candidates["btop"]:
        primary_path = candidates["btop"][0]
        primary_data = parse_btop_file(os.path.join(repo_dir, primary_path))
        format_desc = f"Btop Theme ({primary_path})"

    if not primary_data:
        raise ValueError(
            "Repository does not appear to contain a recognized theme palette. "
            "Supported formats: colors.toml, palette.toml, base16.yaml, alacritty.toml, kitty.conf, ghostty.conf, btop.theme"
        )

    # Cross-source semantic enrichment
    secondary_files = []
    if candidates["kitty"] and primary_path not in candidates["kitty"]:
        kd = parse_kitty_file(os.path.join(repo_dir, candidates["kitty"][0]))
        if kd:
            for k in ("selection", "selection_background", "selection_foreground", "cursor", "accent"):
                if k not in primary_data and k in kd:
                    primary_data[k] = kd[k]
            secondary_files.append("Kitty")

    if candidates["ghostty"] and primary_path not in candidates["ghostty"]:
        gd = parse_ghostty_file(os.path.join(repo_dir, candidates["ghostty"][0]))
        if gd:
            for k in ("selection", "selection_background", "selection_foreground", "cursor", "accent"):
                if k not in primary_data and k in gd:
                    primary_data[k] = gd[k]
            secondary_files.append("Ghostty")

    if candidates["btop"] and primary_path not in candidates["btop"]:
        bd = parse_btop_file(os.path.join(repo_dir, candidates["btop"][0]))
        if bd:
            for k in ("selection", "selection_background", "selection_foreground", "accent", "border"):
                if k not in primary_data and k in bd:
                    primary_data[k] = bd[k]
            secondary_files.append("Btop")

    if secondary_files:
        format_desc += f" (enriched with {', '.join(secondary_files)})"

    mode = primary_data.get("mode", "dark")
    display_name = primary_data.get("name") or primary_data.get("display_name")

    return primary_data, format_desc, mode, display_name


def analyze_repository(repo_dir, git_url=None, owner="Unknown", repo_name=""):
    """
    Analyzes the cloned repository:
      - Dynamically discovers palette across Omarchy root, subdirs, and terminal formats
      - Classifies every file (SOURCE-DATA, SUPPORTED, IGNORED)
      - Extracts palette, rich semantic tokens, Cava visualizer, and capabilities
    Returns (raw_theme, analysis_summary)
    """
    candidates = find_candidate_files(repo_dir)
    explicit_wallpapers = list(candidates["wallpapers"])
    fallback_wallpapers = list(candidates.get("wallpaper_fallbacks") or [])
    wallpapers_found = len(explicit_wallpapers) if explicit_wallpapers else len(fallback_wallpapers)
    # Conventional wallpaper/background paths are authoritative when present.
    # Miscellaneous repository images are a fallback only for themes that ship
    # no conventional wallpaper path at all; never mix lock-screen/readme art
    # into a valid backgrounds/ or wallpapers/ set.
    wallpaper_pool = explicit_wallpapers if explicit_wallpapers else fallback_wallpapers
    candidates["wallpapers"] = select_wallpaper_candidates(wallpaper_pool)

    # Derive slug
    if git_url:
        _, owner, repo_name, slug = normalize_git_url(git_url)
    else:
        slug = os.path.basename(os.path.abspath(repo_dir)).lower().replace("_", "-")
        if slug.startswith("omarchy-"):
            slug = slug[8:]
        if slug.endswith("-theme"):
            slug = slug[:-6]

    primary_data, format_desc, mode, detected_name = resolve_theme_palette(repo_dir, candidates)

    display_name = detected_name
    if not display_name:
        # Check README.md for title
        readme_path = os.path.join(repo_dir, "README.md")
        if os.path.exists(readme_path):
            try:
                with open(readme_path, "r", encoding="utf-8", errors="replace") as rf:
                    for line in rf:
                        line = line.strip()
                        if line.startswith("#"):
                            clean_t = re.sub(r'^[#\s\U00010000-\U0010ffff\u2600-\u27bf\u2300-\u23ff\ud800-\udbff\udc00-\udfff]+', '', line).strip()
                            clean_t = re.sub(r'^(omarchy|theme|the)\s+', '', clean_t, flags=re.I)
                            clean_t = re.sub(r'\s+(theme|omarchy)$', '', clean_t, flags=re.I).strip()
                            if clean_t:
                                display_name = clean_t
                            break
            except Exception:
                pass
    if not display_name:
        display_name = slug.replace("-", " ").title()

    accent = primary_data.get("accent") or primary_data.get("cursor") or primary_data.get("color4") or "#58a6ff"
    accent = clean_hex(str(accent))
    b16 = colors_dict_to_base16(primary_data)

    semantic_keys = [
        "background", "foreground", "accent", "cursor", "selection",
        "selection_foreground", "selection_background", "readable_muted",
        "text_accent", "warning_text", "border", "muted",
        "dark_foreground", "light_foreground", "bright_foreground",
        "dark_background", "darker_background", "lighter_background",
        "dark_fg", "light_fg", "bright_fg", "dark_bg", "darker_bg", "lighter_bg",
    ]
    semantic_overrides = {}
    for sk in semantic_keys:
        if sk in primary_data and HEX_RE.match(clean_hex(str(primary_data[sk]))):
            semantic_overrides[sk] = clean_hex(str(primary_data[sk]))

    # Current Omarchy themes may publish an explicit visible window border. Keep
    # it as the semantic border instead of falling back to a generic surface.
    active_border = primary_data.get("active_border_color")
    if active_border and HEX_RE.match(clean_hex(str(active_border))):
        semantic_overrides["border"] = clean_hex(str(active_border))

    authored_base30 = {
        "black": clean_hex(primary_data.get("background") or b16["BASE00"]),
        "darker_black": clean_hex(primary_data.get("darker_background") or primary_data.get("darker_bg") or b16["BASE01"]),
        "one_bg": clean_hex(primary_data.get("dark_background") or primary_data.get("dark_bg") or b16["BASE01"]),
        "one_bg2": clean_hex(primary_data.get("selection") or b16["BASE02"]),
        "one_bg3": clean_hex(primary_data.get("lighter_background") or primary_data.get("lighter_bg") or b16["BASE03"]),
        "grey": clean_hex(primary_data.get("muted") or b16["BASE03"]),
        "grey_fg": clean_hex(primary_data.get("dark_foreground") or primary_data.get("dark_fg") or b16["BASE04"]),
        "white": clean_hex(primary_data.get("foreground") or b16["BASE05"]),
        "red": b16["BASE08"], "orange": b16["BASE09"], "yellow": b16["BASE0A"],
        "green": b16["BASE0B"], "cyan": b16["BASE0C"], "teal": b16["BASE0C"],
        "blue": b16["BASE0D"], "purple": b16["BASE0E"], "pink": b16["BASE0F"],
        "folder_bg": accent,
    }

    capabilities = {
        "palette": True,
        "wallpaper": len(candidates["wallpapers"]) > 0,
        "cava": True,
        "gtk": len(candidates["gtk"]) > 0,
        "waybar": len(candidates["waybar"]) > 0,
        "alacritty": len(candidates["alacritty"]) > 0,
        "btop": len(candidates["btop"]) > 0,
        "neovim": len(candidates["neovim"]) > 0,
        "mako": len(candidates["mako"]) > 0,
        "kitty": len(candidates["kitty"]) > 0,
        "ghostty": len(candidates["ghostty"]) > 0,
        "foot": len(candidates["foot"]) > 0,
        "swayosd": len(candidates["swayosd"]) > 0,
        "walker": len(candidates["walker"]) > 0,
        "steam": len(candidates["steam"]) > 0,
        "vencord": len(candidates["vencord"]) > 0,
        "browser": len(candidates["browser"]) > 0,
        "icons": len(candidates["icons"]) > 0,
        "zed": len(candidates["zed"]) > 0,
        "terminal": True,
    }

    apps = build_authored_apps(repo_dir, candidates)

    # Previews. Use the expanded path for the local copy, but persist a
    # home-relative path in source metadata so catalog JSON stays portable.
    preview_dest = None
    preview_meta = None
    if candidates["previews"]:
        # Sort so preview.png / theme-preview come first
        candidates["previews"].sort(key=lambda p: (
            0 if "preview.png" in p.lower() else (1 if "theme-preview" in p.lower() else 2)
        ))
        preview_src = os.path.join(repo_dir, candidates["previews"][0])
        preview_dest = os.path.join(PREVIEWS_DIR, f"{slug}.png")
        try:
            shutil.copy2(preview_src, preview_dest)
            preview_meta = f"~/.cache/theme/previews/{slug}.png"
        except Exception:
            preview_dest = None
            preview_meta = None

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
        "authored": {
            "semantic": semantic_overrides,
            "base_30": authored_base30,
        },
        # Raw aliases are supplied for this first normalization pass. Canonical
        # files preserve them under `authored` so future syncs remain idempotent.
        "semantic": semantic_overrides,
        "base_30": authored_base30,
        "apps": apps,
        "assets": {
            "wallpapers": candidates["wallpapers"],
            "preview": preview_meta,
            "upstream_app_files": {
                app: paths[0].replace("\\", "/")
                for app, paths in candidates.items()
                if app in {"alacritty", "kitty", "ghostty", "btop", "cava", "mako", "browser", "icons"} and paths
            },
            "upstream_apps_version": 3,
        }
    }

    summary = {
        "name": display_name,
        "slug": slug,
        "author": owner,
        "format": format_desc,
        "capabilities": capabilities,
        "ignored_files": sorted(set(candidates["ignored"])),
        "cava_gradient_count": apps.get("cava", {}).get("gradient_count", 8) if "cava" in apps else 8,
        "wallpapers_count": len(candidates["wallpapers"]),
        "wallpapers_found": wallpapers_found,
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
    print(f"Format: {summary.get('format', 'Native Omarchy')}")
    print(f"Author: {summary['author']}")
    print(f"Branch: {branch}")
    print(f"Commit: {commit[:7] if commit else 'unknown'}")

    print("\nUpstream Repository Assets (shipped in git):")
    caps = summary["capabilities"]
    for cap_name in ["palette", "wallpaper", "cava", "gtk", "waybar", "alacritty", "btop", "neovim", "mako", "kitty", "ghostty", "foot", "swayosd", "walker", "steam", "vencord", "zed"]:
        if cap_name in caps:
            has_cap = caps.get(cap_name, False)
            if cap_name == "cava":
                c_status = f"yes ({summary.get('cava_gradient_count', 8)} colors)" if has_cap else "no (system synthesizes 8 colors)"
                print(f"  {cap_name.capitalize():<12} {c_status}")
            elif cap_name == "wallpaper":
                if has_cap:
                    kept = summary.get("wallpapers_count", 0)
                    found = summary.get("wallpapers_found", kept)
                    w_status = f"yes ({kept} kept of {found} found)"
                else:
                    w_status = "no"
                print(f"  {cap_name.capitalize():<12} {w_status}")
            elif cap_name == "zed":
                status = "yes (upstream file)" if has_cap else "no (system generates template)"
                print(f"  {cap_name.capitalize():<12} {status}")
            else:
                status = "yes" if has_cap else "no"
                print(f"  {cap_name.capitalize():<12} {status}")

    print("\nDesktop Adaptation (System Generated & Synchronized):")
    print("  Zed:         generated from palette (~/.config/zed/themes/nvchad-system.json)")
    print("  Sway:        generated from palette (~/.config/sway/)")
    print("  Alacritty:   generated from palette (~/.config/alacritty/)")
    print("  Cava:        generated from palette (~/.config/cava/config)")
    print("  GTK / Rofi:  generated from palette")
    print("  Hyprland:    ignored (Sway environment authority)")
    print("  Hyprlock:    ignored (Sway environment authority)")

    if summary["ignored_files"]:
        print("\nIgnored upstream files (foreign/behavioral):")
        for ig in summary["ignored_files"][:6]:
            print(f"  - {ig}")
        if len(summary["ignored_files"]) > 6:
            print(f"  ... and {len(summary['ignored_files']) - 6} more")




def import_git_theme(
    git_url,
    dry_run=False,
    info_only=False,
    force_update=False,
    apply_theme_flag=False,
    sync_cache=True,
    sync_source=True,
    commit=None,
):
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
        commit_sha, branch = clone_repo_safely(clean_url, clone_dir, commit=commit)

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

        # Preserve the repository's selected wallpapers before the temporary
        # clone is deleted. Omarchy themes use these exact files at runtime.
        persist_repository_wallpapers(clone_dir, slug, canonical)

        # Transactional write via temporary file
        print(f"\nWriting:")
        print(f"  {dest_file}")

        # If previous alt_file existed (e.g. omarchy-slug.json), clean it up so no duplicate exists
        if existing_target and existing_target != dest_file and os.path.exists(existing_target):
            try:
                if sync_source:
                    remove_from_chezmoi_source(existing_target)
                os.remove(existing_target)
            except Exception:
                pass

        tmp_dest = f"{dest_file}.tmp"
        with open(tmp_dest, "w", encoding="utf-8") as f:
            json.dump(canonical, f, indent=2, sort_keys=True)
        os.replace(tmp_dest, dest_file)
        if sync_source:
            sync_to_chezmoi_source(dest_file)

        if sync_cache:
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

    remove_from_chezmoi_source(target)
    os.remove(target)
    shutil.rmtree(os.path.join(WALLPAPERS_CACHE, clean_name), ignore_errors=True)
    shutil.rmtree(os.path.join(WALLPAPERS_CACHE, f"omarchy-{clean_name}"), ignore_errors=True)
    print(f"Removed: {target}")
    print("Syncing cache...")
    subprocess.run([os.path.expanduser("~/.local/bin/theme-sync")], check=True)
    print("Done.")
    return True


def _catalog_entries_from_json(data):
    """Normalize current/legacy registry JSON shapes into theme entry dicts."""
    if isinstance(data, dict):
        entries = data.get("themes") or data.get("entries") or data.get("items") or []
    elif isinstance(data, list):
        entries = data
    else:
        entries = []

    normalized = []
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        repo = entry.get("repo") or entry.get("repository") or entry.get("url")
        if not repo:
            continue
        try:
            clean_repo, _, _, derived_slug = normalize_git_url(str(repo))
        except ValueError:
            continue
        item = dict(entry)
        item["repo"] = clean_repo
        item["slug"] = item.get("slug") or derived_slug
        item["name"] = item.get("name") or item["slug"]
        commit = item.get("commit") or item.get("sha")
        if not commit and isinstance(item.get("version"), dict):
            commit = item["version"].get("commit") or item["version"].get("sha")
        if commit:
            item["commit"] = str(commit)
        normalized.append(item)
    return normalized


def fetch_registry_catalog():
    """Fetch Omarchy's validated published catalog when its CDN is reachable."""
    for url in REGISTRY_CATALOG_URLS:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Omarchy-Theme-Importer/2.0"})
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            entries = _catalog_entries_from_json(data)
            if entries:
                return entries, url
        except Exception:
            continue
    raise RuntimeError("Validated Omarchy registry catalog is unavailable.")


def fetch_gallery_catalog():
    """Read the current omarchy.org community gallery and its Git repository links."""
    entry_re = re.compile(
        r'<figcaption>\s*<a href="(https://github[.]com/[^"]+)">([^<]+)</a>\s*</figcaption>',
        re.IGNORECASE | re.DOTALL,
    )
    for url in GALLERY_URLS:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Omarchy-Theme-Importer/2.0"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                text = resp.read().decode("utf-8", errors="replace")
            entries = []
            seen = set()
            for repo, display_name in entry_re.findall(text):
                clean_repo, _, _, slug = normalize_git_url(repo)
                repo_key = clean_repo.lower()
                if repo_key in seen:
                    continue
                seen.add(repo_key)
                entries.append({
                    "slug": slug,
                    "name": html_module.unescape(display_name).strip(),
                    "repo": clean_repo,
                    "source": "omarchy.org/themes",
                })
            if entries:
                return entries, url
        except Exception:
            continue
    raise RuntimeError("Failed to fetch the current Omarchy community gallery.")


def fetch_official_catalog():
    """Prefer validated registry commits, then the public gallery, then legacy JSON."""
    try:
        return fetch_registry_catalog()
    except Exception:
        pass
    try:
        return fetch_gallery_catalog()
    except Exception:
        pass
    for url in LEGACY_CATALOG_URLS:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Omarchy-Theme-Importer/2.0"})
            with urllib.request.urlopen(req, timeout=10) as resp:
                entries = _catalog_entries_from_json(json.loads(resp.read().decode("utf-8")))
            if entries:
                return entries, url
        except Exception:
            continue
    raise RuntimeError("Failed to fetch Omarchy registry, gallery, or legacy fallbacks.")


def _local_import_records():
    records = []
    for filename in sorted(os.listdir(IMPORTED_OMARCHY_DIR)):
        if not filename.endswith(".json"):
            continue
        path = os.path.join(IMPORTED_OMARCHY_DIR, filename)
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            continue
        repo = (data.get("source") or {}).get("repository")
        records.append((path, data.get("name") or filename[:-5], repo))
    return records


def import_catalog(dry_run=False, limit=None):
    """Reconcile imports against Omarchy's validated registry or gallery fallback."""
    print("Fetching current Omarchy theme catalog...")
    themes, source_url = fetch_official_catalog()
    print(f"Connected to catalog source ({source_url})")

    full_catalog = list(themes)
    if limit:
        themes = themes[:limit]

    local_records = _local_import_records()
    local_repos = {repo.rstrip("/").lower() for _, _, repo in local_records if repo}
    catalog_repos = {str(t.get("repo") or "").rstrip("/").lower() for t in full_catalog if t.get("repo")}
    selected_repos = {str(t.get("repo") or "").rstrip("/").lower() for t in themes if t.get("repo")}
    new_count = sum(1 for repo in selected_repos if repo not in local_repos)
    stale = [(path, name, repo) for path, name, repo in local_records if repo and repo.rstrip("/").lower() not in catalog_repos]

    print("\nCatalog Reconciliation:")
    print(f"  Current catalog:     {len(full_catalog)}")
    print(f"  Selected this run:   {len(themes)}")
    print(f"  Local imported:      {len(local_records)}")
    print(f"  New repositories:    {new_count}")
    print(f"  No longer listed:    {len(stale)}")

    if dry_run:
        print("\n[Dry Run] No files modified on disk.")
        return True

    # Every selected repository is refreshed from its own palette source. The
    # worker path disables per-theme cache/source syncing; both happen once at
    # the end so a full catalog reconciliation remains fast and deterministic.
    failures = []
    with ThreadPoolExecutor(max_workers=min(6, max(1, len(themes)))) as pool:
        future_map = {}
        for entry in themes:
            repo = entry.get("repo")
            if not repo:
                continue
            future = pool.submit(
                import_git_theme,
                repo,
                False,
                False,
                True,
                False,
                False,
                False,
                entry.get("commit"),
            )
            future_map[future] = entry
        for future in as_completed(future_map):
            entry = future_map[future]
            try:
                if not future.result():
                    failures.append((entry.get("name"), entry.get("repo"), "validation/import failed"))
            except Exception as exc:
                failures.append((entry.get("name"), entry.get("repo"), str(exc)))

    # Canonicalize to exactly one local file per catalog repository. Older
    # importer versions used provider-prefixed or underscore slugs, so repo URL
    # identity is more reliable than filename identity during reconciliation.
    catalog_meta = {
        str(entry.get("repo") or "").rstrip("/").lower(): entry
        for entry in themes
        if entry.get("repo")
    }
    records_by_repo = {}
    for path, name, repo in _local_import_records():
        key = str(repo or "").rstrip("/").lower()
        records_by_repo.setdefault(key, []).append((path, name))

    duplicate_files_removed = 0
    for repo_key, records in records_by_repo.items():
        entry = catalog_meta.get(repo_key)
        if not entry:
            continue
        canonical_path = os.path.join(IMPORTED_OMARCHY_DIR, f"{entry['slug']}.json")
        if not os.path.exists(canonical_path) and records:
            source_path = records[0][0]
            if source_path != canonical_path:
                os.replace(source_path, canonical_path)
        for path, _ in records:
            if path == canonical_path or not os.path.exists(path):
                continue
            remove_from_chezmoi_source(path)
            os.remove(path)
            duplicate_files_removed += 1

    # Normalize display names/provenance from the authoritative catalog. README
    # title heuristics are intentionally secondary to registry/gallery metadata.
    for path, _, repo in _local_import_records():
        key = str(repo or "").rstrip("/").lower()
        entry = catalog_meta.get(key)
        if not entry:
            continue
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            data["display_name"] = entry.get("name") or data.get("display_name")
            source = data.setdefault("source", {})
            source["registry"] = "https://omarchy.org/themes/"
            source["registry_catalog"] = source_url
            source["registry_listed"] = True
            source["registry_commit_pinned"] = bool(entry.get("commit"))
            tmp = path + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, sort_keys=True)
                f.write("\n")
            os.replace(tmp, path)
        except Exception as exc:
            print(f"Warning: could not apply catalog metadata to {path}: {exc}", file=sys.stderr)

    removed = 0
    retained_active = 0
    if not limit:
        active_path = os.path.expanduser("~/.local/state/theme/name")
        try:
            active = open(active_path, "r", encoding="utf-8").read().strip()
        except Exception:
            active = ""
        for path, name, _ in stale:
            if not os.path.exists(path):
                continue
            # The same path may have been refreshed from a renamed/moved
            # repository during this reconciliation. Re-check its current
            # provenance before removing anything based on the pre-refresh list.
            try:
                with open(path, "r", encoding="utf-8") as f:
                    current_data = json.load(f)
                current_repo = str((current_data.get("source") or {}).get("repository") or "").rstrip("/").lower()
                if current_repo in catalog_repos:
                    continue
            except Exception:
                pass
            if name == active or os.path.splitext(os.path.basename(path))[0] == active:
                retained_active += 1
                continue
            remove_from_chezmoi_source(path)
            try:
                os.remove(path)
                removed += 1
            except FileNotFoundError:
                pass

    # Persist the complete reconciled directory with one chezmoi process. Manual
    # single-theme imports still use the per-file helper immediately.
    sync_import_directory_to_chezmoi()
    prune_chezmoi_import_source_to_live()

    print("\nSyncing canonical cache...")
    subprocess.run([os.path.expanduser("~/.local/bin/theme-sync"), "--force"], check=True)

    print("\nCatalog Result:")
    print(f"  Imported/refreshed: {len(themes) - len(failures)}")
    print(f"  Failed:             {len(failures)}")
    print(f"  Removed stale:      {removed}")
    print(f"  Removed repo copies:{duplicate_files_removed:>6}")
    if retained_active:
        print(f"  Retained active:    {retained_active}")
    if failures:
        print("  Unreachable/failed catalog entries:")
        for name, repo, reason in failures[:20]:
            print(f"    - {name}: {repo} ({reason})")
        print("  Note: unreachable upstream catalog links are skipped; no third-party mirror is substituted.")
    # A stale/deleted repository linked by the catalog must not poison the rest
    # of a successful reconciliation. Individual import failures remain visible
    # in the report and `--status` exposes them as missing until upstream fixes
    # the catalog entry.
    return True
