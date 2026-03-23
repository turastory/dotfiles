#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

OH_MY_ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$OH_MY_ZSH_DIR/custom}"

clone_if_missing() {
    local repo="$1"
    local dest="$2"
    local label="$3"

    if [ -d "$dest" ]; then
        log_info "$label already installed."
        return
    fi

    mkdir -p "$(dirname "$dest")"
    log_info "Installing $label..."
    git clone --depth=1 "$repo" "$dest"
}

echo "=========================================="
echo " Shell Bootstrap"
echo "=========================================="
echo ""

if ! command -v git &>/dev/null; then
    log_warn "git is required to bootstrap shell dependencies."
    exit 1
fi

clone_if_missing "https://github.com/ohmyzsh/ohmyzsh.git" \
    "$OH_MY_ZSH_DIR" \
    "oh-my-zsh"

clone_if_missing "https://github.com/romkatv/powerlevel10k.git" \
    "$ZSH_CUSTOM_DIR/themes/powerlevel10k" \
    "powerlevel10k"

clone_if_missing "https://github.com/zsh-users/zsh-autosuggestions" \
    "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" \
    "zsh-autosuggestions"

clone_if_missing "https://github.com/zsh-users/zsh-completions" \
    "$ZSH_CUSTOM_DIR/plugins/zsh-completions" \
    "zsh-completions"

if command -v rustc &>/dev/null && command -v cargo &>/dev/null; then
    log_info "Rust toolchain already available."
else
    log_warn "Rust toolchain is missing. Install brew packages first with 'make brew' or use 'make setup'."
    exit 1
fi

echo ""
log_info "Shell dependencies bootstrapped successfully!"
