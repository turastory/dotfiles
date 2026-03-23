#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]]; then
    DRY_RUN=true
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_dry()   { echo -e "${BLUE}[DRY-RUN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check dependencies
if ! command -v stow &>/dev/null; then
    log_error "GNU Stow is not installed. Run: brew install stow"
    exit 1
fi

echo "=========================================="
if $DRY_RUN; then
    echo " Dotfiles Installer (DRY RUN - no changes)"
else
    echo " Dotfiles Installer"
fi
echo "=========================================="
echo ""

# --- Stow each package ---
STOW_DIR="$DOTFILES_DIR/dotfiles"
HAD_CONFLICT=false

for package_dir in "$STOW_DIR"/*/; do
    package="$(basename "$package_dir")"

    # Skip packages with .skipstow marker
    if [ -f "$package_dir/.skipstow" ]; then
        log_warn "Skipping (has .skipstow): $package"
        continue
    fi

    # Pre-create directories so stow symlinks FILES only, not entire dirs.
    # This prevents new files in those dirs from silently landing in the repo.
    while IFS= read -r -d '' file; do
        relative="${file#"$package_dir"}"
        target_dir="$HOME/$(dirname "$relative")"
        if [ ! -d "$target_dir" ]; then
            if $DRY_RUN; then
                log_dry "Would mkdir: $target_dir"
            else
                mkdir -p "$target_dir"
            fi
        fi
    done < <(find "$package_dir" -type f -not -name '.skipstow' -print0)

    if $DRY_RUN; then
        log_dry "Would stow: $package"
        # Show what stow would do
        stow --simulate --verbose=1 -t "$HOME" -d "$STOW_DIR" "$package" 2>&1 | \
            grep -E "^(LINK|UNLINK|MV)" | while read -r line; do
                log_dry "  $line"
            done || true
    else
        log_info "Stowing: $package"
        if stow_output="$(stow --verbose=1 -t "$HOME" -d "$STOW_DIR" "$package" 2>&1)"; then
            printf '%s\n' "$stow_output" | grep -E "^(LINK|UNLINK)" | while read -r line; do
                log_info "  $line"
            done || true
        else
            HAD_CONFLICT=true
            printf '%s\n' "$stow_output" | grep -E "^(LINK|UNLINK|CONFLICT)" | while read -r line; do
                log_error "  $line"
            done || true
            log_error "Conflict in '$package'. Existing files block stow."
            log_error "To fix: back up or remove the conflicting files, then re-run."
            log_error "Or use: stow --adopt -t \$HOME -d dotfiles $package"
            log_error "  (--adopt moves existing files INTO the repo, replacing repo copies)"
        fi
    fi
done

echo ""
if $DRY_RUN; then
    log_info "Dry run complete. No changes were made."
    echo ""
    echo "To apply: make install"
    echo "To adopt existing files into repo: make adopt"
elif $HAD_CONFLICT; then
    log_error "Dotfiles install completed with conflicts."
    exit 1
else
    log_info "All dotfiles stowed successfully!"
fi
echo ""
