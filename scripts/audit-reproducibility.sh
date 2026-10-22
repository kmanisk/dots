#!/usr/bin/env bash
# ==============================================================================
# tufdots reproducibility audit
# Scans repository for prohibited machine-specific leakage, hardcoded accounts,
# paths, and runtime state before commits.
# ==============================================================================
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

check_forbidden() {
    local pattern="$1"
    local description="$2"

    local matches
    matches=$(rg -n --hidden \
        --glob '!.git/**' \
        --glob '!docs/**' \
        --glob '!scripts/**' \
        --glob '!scripts*' \
        --glob '!README.md' \
        --glob '!GAMING.md' \
        -e "$pattern" "$ROOT" 2>/dev/null || true)

    if [[ -n "$matches" ]]; then
        printf '\n[FAIL] %s: detected matches below:\n%s\n' "$description" "$matches" >&2
        fail=1
    else
        printf '[PASS] %s\n' "$description"
    fi
}

echo "==> Running reproducibility audit on: $ROOT"
echo "------------------------------------------------------------------"

check_forbidden '/home/onyx' 'Zero hardcoded user home paths (/home/onyx)'
check_forbidden '875656642' 'Zero hardcoded personal Steam Account IDs (875656642)'
check_forbidden 'userdata/[0-9]+' 'Zero tracked Steam userdata identity directories'

echo "------------------------------------------------------------------"
if (( fail != 0 )); then
    echo "==> AUDIT FAILED: Fix the detected machine leakages above." >&2
    exit 1
fi

echo "==> ALL AUDIT CHECKS PASSED: Repository is clean and reproducible."
exit 0
