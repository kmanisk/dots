#!/usr/bin/env bash
# Synchronize the auto-managed live Sway snapshot in SYSTEM_CONTEXT.md.
# Safe by design: skips modification when no live Sway IPC session is available.
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

if ! command -v swaymsg >/dev/null 2>&1 || ! swaymsg -t get_version >/dev/null 2>&1; then
    printf 'sync-system-context: no live Sway IPC session; leaving canonical live snapshot unchanged\n'
    exit 0
fi

validation="PASS"
if command -v sway-check >/dev/null 2>&1; then
    if ! sway-check >/dev/null 2>&1; then
        printf 'sync-system-context: sway-check failed; refusing to record state\n' >&2
        exit 1
    fi
else
    conf="${SWAY_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/sway/config}"
    if ! sway -C -c "$conf" >/dev/null 2>&1; then
        printf 'sync-system-context: Sway config validation failed; refusing to record state\n' >&2
        exit 1
    fi
fi

stamp="$(date +%F)"
sway_version="$(sway --version 2>/dev/null | head -n1 | sed 's/[[:space:]]\+$//')"
gpu_mode="$(supergfxctl -g 2>/dev/null | head -n1 | sed 's/[[:space:]]\+$//' || true)"
[ -n "$gpu_mode" ] || gpu_mode="unavailable"

if ! command -v jq >/dev/null 2>&1; then
    printf 'sync-system-context: jq is required for live Sway output parsing\n' >&2
    exit 2
fi

read -r output_name output_width output_height output_refresh output_scale output_adaptive < <(
    swaymsg -r -t get_outputs | jq -r '
        [.[] | select(.active)][0] as $o
        | [
            $o.name,
            $o.current_mode.width,
            $o.current_mode.height,
            (($o.current_mode.refresh / 1000) | tostring),
            (($o.scale * 100 | round) / 100 | tostring),
            $o.adaptive_sync_status
          ]
        | @tsv
    '
)

output_refresh="$(printf '%.3f' "$output_refresh")"
output_scale="$(printf '%.2f' "$output_scale")"

scale_conf="${XDG_CONFIG_HOME:-$HOME/.config}/sway/config.d/99-ui-scale.conf"
persisted_scale="unavailable"
if [ -r "$scale_conf" ]; then
    candidate="$(grep -oE 'scale[[:space:]]+[0-9]+([.][0-9]+)?' "$scale_conf" | awk '{print $2}' | head -n1 || true)"
    [ -n "$candidate" ] && persisted_scale="$candidate"
fi

reload_path="raw swaymsg reload"
if command -v sway-safe-reload >/dev/null 2>&1; then
    reload_path='`sway-safe-reload` (validates before `swaymsg reload`)'
fi

block_file="$(mktemp)"
trap 'rm -f "$block_file"' EXIT
cat >"$block_file" <<EOF
<!-- AUTO:SYSTEM_STATE:BEGIN -->
> Auto-synchronized from the live workstation by \`scripts/sync-system-context.sh\`. Do not edit inside these markers.

- Last live sync: **$stamp**.
- Sway validation: **$validation**.
- Sway version: \`$sway_version\`.
- GPU mode: \`$gpu_mode\`.
- Active output: \`$output_name\`, \`${output_width}x${output_height} @ ${output_refresh} Hz\`, scale \`$output_scale\`, adaptive sync \`$output_adaptive\`.
- Persisted generated UI scale: \`$persisted_scale\` from \`~/.config/sway/config.d/99-ui-scale.conf\`.
- Reload path: $reload_path.

These are verified runtime values, not permanent hardware identifiers. Connector names and versions must still be re-queried when exact values matter.
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

printf 'sync-system-context: updated %s from verified live Sway state\n' "$context"
