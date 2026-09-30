"""
theme_engine.manifest: Fast O(N) metadata change detection using file mtime_ns and size.
Avoids reparsing unchanged themes and catches in-place file content edits.
"""
import os
import json
import glob
import tempfile

DEFAULT_MANIFEST_PATH = os.path.expanduser("~/.cache/theme/manifest.json")

def load_manifest(path=DEFAULT_MANIFEST_PATH):
    if os.path.isfile(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"version": 1, "files": {}}

def save_manifest(manifest, path=DEFAULT_MANIFEST_PATH):
    dirname = os.path.dirname(path)
    os.makedirs(dirname, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=dirname, delete=False, encoding="utf-8") as tf:
        json.dump(manifest, tf, indent=2)
        temp_name = tf.name
    os.replace(temp_name, path)

def get_file_meta(filepath):
    try:
        st = os.stat(filepath)
        return {
            "mtime_ns": st.st_mtime_ns,
            "size": st.st_size
        }
    except OSError:
        return None

def find_source_files(dirs):
    """Scan list of source directories for theme files (.json or .lua)."""
    found = []
    for d in dirs:
        d = os.path.expanduser(d)
        if not os.path.isdir(d):
            continue
        for root, _, files in os.walk(d):
            for f in files:
                if f.endswith(".json") or f.endswith(".lua"):
                    found.append(os.path.join(root, f))
    return sorted(found)

def is_cache_stale(dirs, manifest_path=DEFAULT_MANIFEST_PATH):
    """
    Fast O(N) check. Returns (stale: bool, changed_files: list).
    Checks if any file has been added, removed, or has changed mtime/size.
    """
    manifest = load_manifest(manifest_path)
    recorded = manifest.get("files", {})
    current_files = find_source_files(dirs)

    current_set = set(current_files)
    recorded_set = set(recorded.keys())

    if current_set != recorded_set:
        return True, list(current_set.symmetric_difference(recorded_set))

    changed = []
    for f in current_files:
        meta = get_file_meta(f)
        if not meta:
            changed.append(f)
            continue
        rec = recorded.get(f)
        if not rec or rec.get("mtime_ns") != meta["mtime_ns"] or rec.get("size") != meta["size"]:
            changed.append(f)

    return (len(changed) > 0), changed

def update_manifest_for_files(dirs, manifest_path=DEFAULT_MANIFEST_PATH):
    current_files = find_source_files(dirs)
    new_files = {}
    for f in current_files:
        meta = get_file_meta(f)
        if meta:
            new_files[f] = meta
    manifest = {"version": 1, "files": new_files}
    save_manifest(manifest, manifest_path)
    return manifest
