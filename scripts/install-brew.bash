#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_BREWFILE="$DOTFILES_DIR/Brewfile.local"

GREEN='\033[0;32m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

brew_binary() {
    if command -v brew &>/dev/null; then
        command -v brew
        return 0
    fi

    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

echo "=========================================="
echo " Homebrew Package Installer"
echo "=========================================="
echo ""

# Check if Homebrew is installed
if ! command -v brew &>/dev/null; then
    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    log_info "Homebrew already installed."
fi

BREW_BIN="$(brew_binary)"
if [ -z "$BREW_BIN" ]; then
    log_info "Homebrew installation completed, but brew was not found on PATH."
    exit 1
fi

eval "$("$BREW_BIN" shellenv)"

log_info "Installing packages from Brewfile..."
brew bundle --file="$DOTFILES_DIR/Brewfile" --verbose

if [ -f "$LOCAL_BREWFILE" ]; then
    log_info "Installing packages from Brewfile.local..."
    brew bundle --file="$LOCAL_BREWFILE" --verbose
fi

echo ""
log_info "Homebrew packages installed successfully!"
