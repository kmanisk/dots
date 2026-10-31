#!/usr/bin/env bash
# Configure repository-local Git hooks for automatic system-context synchronization.
set -euo pipefail

repo="$(chezmoi source-path)"
if [ -d "$repo/.git" ] && [ -d "$repo/scripts/git-hooks" ]; then
    git -C "$repo" config core.hooksPath scripts/git-hooks
fi
