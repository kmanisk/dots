#!/bin/bash
# ==============================================================================
# tufdots bootstrap: install dependencies, seed profile, verify age identity,
# and initialize/apply chezmoi repository.
# ==============================================================================
set -euo pipefail

REPO_URL="https://github.com/kmanisk/tufdots.git"

if [ ! -f /etc/arch-release ]; then
    echo "ERROR: tufdots supports Arch/CachyOS only." >&2
    exit 1
fi

# 1. git + base-devel (needed to build paru)
if ! command -v git >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm git base-devel
fi

# 2. paru (AUR helper used by the package reconciler)
if ! command -v paru >/dev/null 2>&1; then
    echo "==> Installing paru..."
    tmpdir=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/paru.git "$tmpdir/paru"
    (cd "$tmpdir/paru" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
fi

# 3. chezmoi + age (age decrypts encrypted dotfiles on apply)
paru -S --needed --noconfirm chezmoi age

# 4. Pre-seed chezmoi config so `init --apply` picks the right machine profile
mkdir -p "$HOME/.config/chezmoi"
if [ ! -f "$HOME/.config/chezmoi/chezmoi.toml" ]; then
    cat > "$HOME/.config/chezmoi/chezmoi.toml" <<'EOF'
encryption = "age"
[age]
    identity = "/home/onyx/.config/chezmoi/key.txt"
    recipient = "age1shu7a5lx3puszpg9r9e39u2t2a6yl3mvnfezhsulfze8335k9fhslf8x78"

[data]
    machine = "asus-tuf-f16"
EOF
    echo "==> Wrote ~/.config/chezmoi/chezmoi.toml (machine = asus-tuf-f16, encryption = age)"
else
    echo "==> ~/.config/chezmoi/chezmoi.toml already exists, leaving it alone"
fi

# 5. Check age identity before applying encrypted configurations
AGE_KEY="$HOME/.config/chezmoi/key.txt"
if [ ! -f "$AGE_KEY" ]; then
    echo "=============================================================================="
    echo "NOTICE: Age identity not found at $AGE_KEY"
    echo "The repository contains age-encrypted files. Please provision your private key:"
    echo "  1. Securely copy your age private key to: $AGE_KEY"
    echo "  2. Enforce strict permissions: chmod 600 $AGE_KEY"
    echo "  3. Re-run: chezmoi apply"
    echo "=============================================================================="
fi

if [[ "${1:-}" == "--apply" ]] || [[ "${1:-}" == "-a" ]]; then
    if [ ! -f "$AGE_KEY" ]; then
        echo "ERROR: Cannot auto-apply without age identity at $AGE_KEY" >&2
        echo "Please copy your age private key to $AGE_KEY (chmod 600) and run:" >&2
        echo "  chezmoi init --apply $REPO_URL" >&2
        exit 1
    fi
    echo "==> Step 2/2: Auto-applying dotfiles via chezmoi..."
    exec chezmoi init --apply "$REPO_URL"
fi

echo ""
echo "Step 1 done. After provisioning $AGE_KEY (chmod 600), run step 2/2:"
echo "  chezmoi init --apply $REPO_URL"
echo "(Or pass '--apply' to install.sh with $AGE_KEY present for 1-step deployment)"
