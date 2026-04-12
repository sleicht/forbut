#!/usr/bin/env bash
# install.sh — installer for forbut
# Copies forbut to a user-specified location and sets up PATH.

set -euo pipefail

FORBUT_INSTALL_PREFIX="${FORBUT_INSTALL_PREFIX:-$HOME/.local}"

# Colours
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

info() { printf '%s[forbut]%s %s\n' "$CYAN" "$RESET" "$*"; }
warn() { printf '%s[forbut]%s %s\n' "$YELLOW" "$RESET" "$*"; }
error() {
    printf '%s[forbut]%s %s\n' "$RED" "$RESET" "$*"
    exit 1
}
ok() { printf '%s[forbut]%s %s\n' "$GREEN" "$RESET" "$*"; }

usage() {
    cat <<EOF
${BOLD}forbut installer${RESET}

${BOLD}USAGE${RESET}
    ./install.sh [OPTIONS]

${BOLD}OPTIONS${RESET}
    --prefix=DIR    Install prefix (default: \$HOME/.local)
    --symlink       Symlink instead of copy (for development)
    --uninstall     Remove forbut from the install prefix
    -h, --help      Show this help

${BOLD}WHAT IT DOES${RESET}
    1. Copies forbut files to PREFIX/share/forbut/
    2. Symlinks bin/git-forbut to PREFIX/bin/git-forbut
    3. Prints shell integration instructions

${BOLD}SHELL INTEGRATION${RESET}
    After installing, add to your .bashrc or .zshrc:

        source "\$HOME/.local/share/forbut/forbut.sh"
EOF
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
SYMLINK=0
UNINSTALL=0

for arg in "$@"; do
    case "$arg" in
        --prefix=*) FORBUT_INSTALL_PREFIX="${arg#--prefix=}" ;;
        --symlink) SYMLINK=1 ;;
        --uninstall) UNINSTALL=1 ;;
        -h | --help)
            usage
            exit 0
            ;;
        *) error "Unknown option: $arg" ;;
    esac
done

INSTALL_DIR="$FORBUT_INSTALL_PREFIX/share/forbut"
BIN_DIR="$FORBUT_INSTALL_PREFIX/bin"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
if [[ $UNINSTALL -eq 1 ]]; then
    info "Uninstalling forbut from $FORBUT_INSTALL_PREFIX ..."
    rm -f "$BIN_DIR/git-forbut"
    rm -rf "$INSTALL_DIR"
    ok "Uninstalled. Remember to remove the 'source ...' line from your shell config."
    exit 0
fi

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------
if ! command -v fzf &>/dev/null; then
    warn "fzf is not installed. forbut requires fzf to function."
    warn "Install it from: https://github.com/junegunn/fzf"
fi

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
info "Installing forbut to $INSTALL_DIR ..."

mkdir -p "$INSTALL_DIR"/{lib,cmds,bin}
mkdir -p "$BIN_DIR"

if [[ $SYMLINK -eq 1 ]]; then
    # Development mode: symlink everything
    info "Using symlinks (development mode)"

    for item in forbut.sh lib cmds bin; do
        rm -rf "$INSTALL_DIR/$item"
        ln -sf "$SOURCE_DIR/$item" "$INSTALL_DIR/$item"
    done
else
    # Production mode: copy files
    cp -f "$SOURCE_DIR/forbut.sh" "$INSTALL_DIR/"
    cp -f "$SOURCE_DIR/lib/"*.sh "$INSTALL_DIR/lib/"
    cp -f "$SOURCE_DIR/cmds/"*.sh "$INSTALL_DIR/cmds/"
    cp -f "$SOURCE_DIR/bin/git-forbut" "$INSTALL_DIR/bin/"
fi

chmod +x "$INSTALL_DIR/bin/git-forbut"

# Create symlink in bin directory
ln -sf "$INSTALL_DIR/bin/git-forbut" "$BIN_DIR/git-forbut"

ok "Installed successfully."
echo ""
info "Add this to your ${BOLD}.bashrc${RESET} or ${BOLD}.zshrc${RESET}:"
echo ""
echo "    source \"$INSTALL_DIR/forbut.sh\""
echo ""
info "Then reload your shell or run:"
echo ""
echo "    source \"$INSTALL_DIR/forbut.sh\""
echo ""

# Check if bin is on PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    warn "$BIN_DIR is not on your PATH."
    warn "Add this to your shell config:"
    echo ""
    echo "    export PATH=\"$BIN_DIR:\$PATH\""
    echo ""
fi
