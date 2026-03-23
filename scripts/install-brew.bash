#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GREEN='\033[0;32m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

echo "=========================================="
echo " Homebrew Package Installer"
echo "=========================================="
echo ""

# Check if Homebrew is installed
if ! command -v brew &>/dev/null; then
    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo >> $HOME/.zprofile
    echo 'eval "$(/opt/homebrew/bin/brew shellenv zsh)"' >> $HOME/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv zsh)"
else
    log_info "Homebrew already installed."
fi

log_info "Installing packages from Brewfile..."
brew bundle --file="$DOTFILES_DIR/Brewfile" --verbose

echo ""
log_info "Homebrew packages installed successfully!"
