#!/usr/bin/env bash
# Refresh the auto-managed verified live-workstation snapshot in SYSTEM_CONTEXT.md.
# This script records observable runtime facts only; semantic documentation remains agent-authored.
set -euo pipefail

repo="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$repo" ]; then
    printf 'sync-system-context: not inside a Git repository\n' >&2
    exit 2
fi

context="$repo/docs/system/SYSTEM_CONTEXT.md"
if [ ! -f "$context" ]; then
    printf 'sync-system-context: missing %s\n' "$context" >&2
    exit 2
fi

validate_sway=0
if [ "${1:-}" = "--validate-sway" ]; then
    validate_sway=1
elif [ -n "${1:-}" ]; then
    printf 'Usage: %s [--validate-sway]\n' "$0" >&2
    exit 2
fi

clean_one_line() {
    tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

cmd_or_unavailable() {
    local output
    output="$("$@" 2>/dev/null | head -n1 | clean_one_line || true)"
    [ -n "$output" ] && printf '%s' "$output" || printf 'unavailable'
}

stamp="$(date +%F)"
os_name="$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | head -n1 | cut -d= -f2- | sed 's/^"//; s/"$//' || true)"
[ -n "$os_name" ] || os_name="unknown"
kernel="$(uname -r 2>/dev/null || printf 'unavailable')"

sway_version="$(cmd_or_unavailable sway --version)"
gpu_mode="$(cmd_or_unavailable supergfxctl -g)"
nvidia_gpu="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 | clean_one_line || true)"
nvidia_driver="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1 | clean_one_line || true)"
[ -n "$nvidia_gpu" ] || nvidia_gpu="unavailable"
[ -n "$nvidia_driver" ] || nvidia_driver="unavailable"

pipewire_version="$(pipewire --version 2>/dev/null | awk '/Compiled with libpipewire/{print $NF; exit}')"
[ -n "$pipewire_version" ] || pipewire_version="unavailable"
wireplumber_version="$(wireplumber --version 2>/dev/null | awk '/Compiled with libwireplumber/{print $NF; exit}')"
[ -n "$wireplumber_version" ] || wireplumber_version="unavailable"
default_sink="$(cmd_or_unavailable pactl get-default-sink)"
default_source="$(cmd_or_unavailable pactl get-default-source)"

mount_info() {
    local target="$1" mounted_target out
    mounted_target="$(findmnt -n -T "$target" -o TARGET 2>/dev/null | head -n1 | clean_one_line || true)"
    if [ "$target" != "/" ] && [ "$mounted_target" != "$target" ]; then
        printf 'not mounted/unavailable'
        return 0
    fi
    out="$(findmnt -n -T "$target" -o SOURCE,FSTYPE,TARGET 2>/dev/null | head -n1 | clean_one_line || true)"
    [ -n "$out" ] && printf '%s' "$out" || printf 'not mounted/unavailable'
}
root_mount="$(mount_info /)"
games_mount="$(mount_info /mnt/Games)"
windows_mount="$(mount_info /mnt/windows)"

failed_system="$(systemctl --failed --no-legend --plain 2>/dev/null | awk 'NF{n++} END{print n+0}')"
failed_user="$(systemctl --user --failed --no-legend --plain 2>/dev/null | awk 'NF{n++} END{print n+0}')"

sway_validation="not required for this commit"
output_summary="unavailable (no reachable Sway IPC session)"
persisted_scale="unavailable"
reload_path="raw swaymsg reload"

if [ "$validate_sway" -eq 1 ]; then
    if command -v sway-check >/dev/null 2>&1; then
        sway-check
    elif [ -x "$repo/dot_local/bin/executable_sway-check" ]; then
        "$repo/dot_local/bin/executable_sway-check"
    else
        sway -C -c "${SWAY_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/sway/config}"
    fi
    sway_validation="PASS"
fi

if command -v swaymsg >/dev/null 2>&1 && swaymsg -t get_version >/dev/null 2>&1; then
    if command -v python3 >/dev/null 2>&1; then
        output_summary="$(swaymsg -r -t get_outputs 2>/dev/null | python3 -c '
import json, sys
active=[o for o in json.load(sys.stdin) if o.get("active")]
if not active:
    print("unavailable (no active output)")
else:
    o=active[0]; m=o.get("current_mode") or {}
    hz=(m.get("refresh",0) or 0)/1000
    scale=float(o.get("scale",1) or 1)
    print(f"{o.get(chr(110)+chr(97)+chr(109)+chr(101), chr(63))}, {m.get(chr(119)+chr(105)+chr(100)+chr(116)+chr(104), chr(63))}x{m.get(chr(104)+chr(101)+chr(105)+chr(103)+chr(104)+chr(116), chr(63))} @ {hz:.3f} Hz, scale {scale:.2f}, adaptive sync {o.get(chr(97)+chr(100)+chr(97)+chr(112)+chr(116)+chr(105)+chr(118)+chr(101)+chr(95)+chr(115)+chr(121)+chr(110)+chr(99)+chr(95)+chr(115)+chr(116)+chr(97)+chr(116)+chr(117)+chr(115), chr(63))}")
' || true)"
    fi

    scale_conf="${XDG_CONFIG_HOME:-$HOME/.config}/sway/config.d/99-ui-scale.conf"
    if [ -r "$scale_conf" ]; then
        candidate="$(grep -oE 'scale[[:space:]]+[0-9]+([.][0-9]+)?' "$scale_conf" | awk '{print $2}' | head -n1 || true)"
        [ -n "$candidate" ] && persisted_scale="$candidate"
    fi
    if command -v sway-safe-reload >/dev/null 2>&1; then
        reload_path="\`sway-safe-reload\` (validates before \`swaymsg reload\`)"
    fi
fi

block_file="$(mktemp)"
trap 'rm -f "$block_file"' EXIT
cat >"$block_file" <<EOF
<!-- AUTO:SYSTEM_STATE:BEGIN -->
> Auto-synchronized from the live workstation by \`scripts/sync-system-context.sh\`. This is measured runtime state, not semantic documentation. Do not edit inside these markers.

- Last live sync: **$stamp**.
- OS/kernel: \`$os_name\` / \`$kernel\`.
- GPU mode: \`$gpu_mode\`.
- NVIDIA: \`$nvidia_gpu\`, driver \`$nvidia_driver\`.
- Sway: \`$sway_version\`; validation: **$sway_validation**.
- Active output: \`$output_summary\`.
- Persisted generated UI scale: \`$persisted_scale\`.
- Sway reload path: $reload_path.
- Audio: PipeWire \`$pipewire_version\`, WirePlumber \`$wireplumber_version\`.
- Default audio sink: \`$default_sink\`.
- Default audio source: \`$default_source\`.
- Root mount: \`$root_mount\`.
- Games mount: \`$games_mount\`.
- Windows mount: \`$windows_mount\`.
- Failed systemd units: system \`$failed_system\`, user \`$failed_user\`.

These values are a convenience snapshot for cross-agent context. Exact runtime-sensitive values must still be re-queried before diagnosis or modification.
<!-- AUTO:SYSTEM_STATE:END -->
EOF

python3 - "$context" "$block_file" <<'PY'
from pathlib import Path
import sys

context = Path(sys.argv[1])
block = Path(sys.argv[2]).read_text()
text = context.read_text()
start = "<!-- AUTO:SYSTEM_STATE:BEGIN -->"
end = "<!-- AUTO:SYSTEM_STATE:END -->"
if start not in text or end not in text:
    raise SystemExit("sync-system-context: auto-managed markers are missing from SYSTEM_CONTEXT.md")
before, rest = text.split(start, 1)
_, after = rest.split(end, 1)
new_text = before + block + after
if new_text != text:
    context.write_text(new_text)
PY

printf 'sync-system-context: refreshed verified live workstation snapshot in %s\n' "$context"
