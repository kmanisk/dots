#!/usr/bin/env bash
# Verify that durable workstation/configuration changes carry the required semantic documentation.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  check-system-docs.sh --cached
  check-system-docs.sh --range <base> <head>
  check-system-docs.sh --files-from <path>

The file list must contain paths relative to the repository root.
EOF
}

repo="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$repo" ]; then
    printf 'check-system-docs: not inside a Git repository\n' >&2
    exit 2
fi
cd "$repo"

mode="${1:-}"
case "$mode" in
    --cached)
        mapfile -t changed < <(git diff --cached --name-only --diff-filter=ACMR)
        ;;
    --range)
        [ "$#" -eq 3 ] || { usage >&2; exit 2; }
        mapfile -t changed < <(git diff --name-only --diff-filter=ACMR "$2" "$3")
        ;;
    --files-from)
        [ "$#" -eq 2 ] || { usage >&2; exit 2; }
        mapfile -t changed < "$2"
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac

[ "${#changed[@]}" -gt 0 ] || exit 0

printf -v changed_text '%s\n' "${changed[@]}"

# Durable workstation/configuration implementation paths. Documentation-only commits are not gated.
system_change_re='^(AGENTS\.md$|CLAUDE\.md$|\.chezmoidata\.toml$|\.chezmoiignore$|\.chezmoiexternal\.toml\.tmpl$|\.chezmoitemplates/|\.github/workflows/system-docs-check\.yml$|dot_|private_|encrypted_|packages/|systemd/|install\.sh$|run_(once|onchange|after|before)_|scripts/)'
mapfile -t implementation < <(printf '%s' "$changed_text" | grep -E "$system_change_re" || true)
[ "${#implementation[@]}" -gt 0 ] || exit 0

errors=0
fail() {
    printf 'check-system-docs: ERROR: %s\n' "$*" >&2
    errors=$((errors + 1))
}

contains_path() {
    local exact="$1"
    printf '%s' "$changed_text" | grep -Fxq "$exact"
}

contains_re() {
    local re="$1"
    printf '%s' "$changed_text" | grep -Eq "$re"
}

if ! contains_path 'docs/system/SYSTEM_CHANGELOG.md'; then
    fail 'durable system changes require docs/system/SYSTEM_CHANGELOG.md in the same change set'
fi

# Active semantic documentation. Generated context, changelog, archives, future plans,
# personal learning notes, and dated audits do not count as owning subsystem docs.
mapfile -t semantic_docs < <(
    printf '%s' "$changed_text" \
        | grep -E '^docs/.*\.md$' \
        | grep -Ev '^docs/(archive|future|personal)/' \
        | grep -Ev '^docs/system/(SYSTEM_CONTEXT|SYSTEM_CHANGELOG|workstation-audit-[0-9]{4}-[0-9]{2}-[0-9]{2})\.md$' \
        || true
)

if [ "${#semantic_docs[@]}" -eq 0 ]; then
    fail 'durable system changes require at least one active semantic subsystem Markdown document under docs/'
fi

semantic_text=""
if [ "${#semantic_docs[@]}" -gt 0 ]; then
    printf -v semantic_text '%s\n' "${semantic_docs[@]}"
fi

require_doc_re() {
    local subsystem="$1" re="$2"
    if ! printf '%s' "$semantic_text" | grep -Eq "$re"; then
        fail "$subsystem changes require a matching active subsystem document; see docs/system/SUBSYSTEM_MAP.md"
    fi
}

impl_text=""
printf -v impl_text '%s\n' "${implementation[@]}"

# Common subsystem routing. Unknown helpers fall back to the generic semantic-doc requirement above.
if grep -Eq '^(dot_config/(pipewire|wireplumber)/|dot_local/bin/[^/]*(audio|mic|speaker|bt-|bluetooth)|systemd/[^/]*(audio|pipewire|wireplumber|bluetooth))' <<<"$impl_text"; then
    require_doc_re 'audio/Bluetooth' '^docs/(audio/|system/audio-(pipewire|stack-status)\.md$|ASUS_SPEAKER_DSP_)'
fi

if grep -Eq '^(dot_config/sway/config\.d/10-display\.conf$|dot_local/bin/[^/]*(vibrance|ctm|nvibr|gpu|brightness|backlight)|dot_config/[^/]*(nvidia|gpu))' <<<"$impl_text"; then
    require_doc_re 'display/GPU' '^docs/(display/|system/vibrance\.md$)'
fi

if grep -Eq '^(dot_config/sway/|dot_local/bin/[^/]*(sway|scratch|keep-awake|screen-|cursor)|dot_config/(foot|xremap)/)' <<<"$impl_text"; then
    require_doc_re 'Sway/input/desktop' '^docs/system/(sway|swayidle-locking-wakeup|xremap|foot|clipboard-shortcuts)\.md$'
fi

if grep -Eq '^(dot_config/(theme|fuzzel|rofi|gtk)|dot_local/bin/[^/]*(theme|fuzzel|rofi))' <<<"$impl_text"; then
    require_doc_re 'theme/launcher UI' '^docs/theme/'
fi

if grep -Eq '^(dot_config/(fish|alacritty|nvim|neovim|emacs)/|dot_local/bin/[^/]*(nvim|neovim|terminal|shell))' <<<"$impl_text"; then
    require_doc_re 'terminal/shell/editor' '^docs/system/(terminal-shell|foot|neovim)\.md$'
fi

if grep -Eq '^(dot_config/(MangoHud|steam)/|dot_local/bin/[^/]*(cs2|steam|elden|gta|proton|gamescope|lsfg)|[^/]*(GAMING|GTAIV).*\.md$)' <<<"$impl_text"; then
    require_doc_re 'gaming' '^docs/gaming/'
fi

if grep -Eq '^(dot_config/waydroid/|dot_local/bin/[^/]*waydroid|private_etc/[^/]*(libvirt|qemu)|systemd/[^/]*(libvirt|qemu|waydroid))' <<<"$impl_text"; then
    require_doc_re 'virtualization/Waydroid' '^docs/virtualization/'
fi

if grep -Eq '^(dot_local/bin/[^/]*(rog|asus|fan|battery)|dot_config/[^/]*(asus|rog))' <<<"$impl_text"; then
    require_doc_re 'ASUS hardware control' '^docs/(system/rogtui-hardware-control\.md$|projects/rogtui/)'
fi

if grep -Eq '^(private_etc/(fstab|.*snapper|.*btrfs)|dot_local/bin/[^/]*(mount|btrfs|snapper|rclone)|dot_config/rclone/)' <<<"$impl_text"; then
    require_doc_re 'storage/filesystem' '^docs/system/(SYSTEM-REPRODUCIBILITY|file-management|rclone)\.md$'
fi

if grep -Eq '^(private_etc/(default/grub|mkinitcpio|plymouth)|dot_local/[^/]*(grub|plymouth|boot)|run_[^/]*(boot|grub|plymouth))' <<<"$impl_text"; then
    require_doc_re 'boot/initramfs' '^docs/bootloader/'
fi

if grep -Eq '^(dot_local/bin/[^/]*(network|wifi|jio)|dot_config/(NetworkManager|network)/|private_etc/NetworkManager/)' <<<"$impl_text"; then
    require_doc_re 'networking' '^docs/system/'
fi

if grep -Eq '^(AGENTS\.md$|CLAUDE\.md$|dot_agents/|dot_codex/|dot_gemini/|dot_config/opencode/|scripts/(git-hooks/|sync-system-context\.sh$|check-system-docs\.sh$|sync-agent-skills\.sh$)|\.github/workflows/system-docs-check\.yml$|run_(once|after|onchange)_[^/]*agent)' <<<"$impl_text"; then
    require_doc_re 'agent infrastructure' '^docs/system/(agent-control-plane|SUBSYSTEM_MAP)\.md$'
fi

if [ "$errors" -ne 0 ]; then
    printf '\nChanged implementation files:\n' >&2
    printf '  %s\n' "${implementation[@]}" >&2
    printf '\nChanged active semantic docs:\n' >&2
    if [ "${#semantic_docs[@]}" -gt 0 ]; then
        printf '  %s\n' "${semantic_docs[@]}" >&2
    else
        printf '  (none)\n' >&2
    fi
    exit 1
fi

printf 'check-system-docs: PASS (%d implementation file(s), %d semantic doc(s))\n' \
    "${#implementation[@]}" "${#semantic_docs[@]}"
