#!/usr/bin/env bash
# install.sh — installer for forbut
# Copies forbut to a user-specified location and sets up PATH.

set -euo pipefail

FORBUT_INSTALL_PREFIX="${FORBUT_INSTALL_PREFIX:-$HOME/.local}"
SYMLINK=0
UNINSTALL=0

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

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR=""
BIN_DIR=""
SHARE_DIR=""
BASH_COMPLETION_DIR=""
ZSH_COMPLETION_DIR=""
FISH_COMPLETION_DIR=""
MAN_DIR=""
MANPAGE_PATH=""

usage_cmd() {
    if command -v usage >/dev/null 2>&1; then
        usage "$@"
        return 0
    fi

    if command -v mise >/dev/null 2>&1; then
        (cd "$SOURCE_DIR" && mise exec usage -- usage "$@")
        return 0
    fi

    return 1
}

set_prefix_paths() {
    INSTALL_DIR="$FORBUT_INSTALL_PREFIX/share/forbut"
    BIN_DIR="$FORBUT_INSTALL_PREFIX/bin"
    SHARE_DIR="$FORBUT_INSTALL_PREFIX/share"
    BASH_COMPLETION_DIR="$SHARE_DIR/bash-completion/completions"
    ZSH_COMPLETION_DIR="$SHARE_DIR/zsh/site-functions"
    FISH_COMPLETION_DIR="$SHARE_DIR/fish/vendor_completions.d"
    MAN_DIR="$SHARE_DIR/man/man1"
    MANPAGE_PATH="$MAN_DIR/forbut.1"
}

install_path() {
    local src="$1"
    local dest="$2"

    mkdir -p "$(dirname "$dest")"

    if [[ $SYMLINK -eq 1 ]]; then
        rm -rf "$dest"
        ln -sf "$src" "$dest"
    else
        if [[ -d $src ]]; then
            rm -rf "$dest"
            cp -R "$src" "$dest"
        else
            cp -f "$src" "$dest"
        fi
    fi
}

install_runtime_payload() {
    if [[ $SYMLINK -eq 1 ]]; then
        info "Using symlinks (development mode)"
    fi

    install_path "$SOURCE_DIR/forbut.sh" "$INSTALL_DIR/forbut.sh"
    install_path "$SOURCE_DIR/lib" "$INSTALL_DIR/lib"
    install_path "$SOURCE_DIR/cmds" "$INSTALL_DIR/cmds"
    install_path "$SOURCE_DIR/bin" "$INSTALL_DIR/bin"
    chmod +x "$INSTALL_DIR/bin/git-forbut"
    ln -sf "$INSTALL_DIR/bin/git-forbut" "$BIN_DIR/git-forbut"
}

install_completion_artifacts() {
    install_path "$SOURCE_DIR/completions/git-forbut.bash" "$BASH_COMPLETION_DIR/git-forbut"
    install_path "$SOURCE_DIR/completions/_git-forbut" "$ZSH_COMPLETION_DIR/_git-forbut"
    install_path "$SOURCE_DIR/completions/git-forbut.fish" "$FISH_COMPLETION_DIR/git-forbut.fish"

    ok "Installed shell completion files."
}

install_optional_manpage() {
    if [[ ! -f "$SOURCE_DIR/forbut.usage.kdl" ]]; then
        warn "Skipping manpage generation because forbut.usage.kdl was not found."
        return 0
    fi

    mkdir -p "$MAN_DIR"

    if usage_cmd generate manpage -f "$SOURCE_DIR/forbut.usage.kdl" --out-file "$MANPAGE_PATH" >/dev/null 2>&1; then
        ok "Installed generated manpage at $MANPAGE_PATH"
    else
        warn "Skipping manpage generation because usage is unavailable."
    fi
}

print_post_install_instructions() {
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

    info "Installed completion files:"
    echo "    bash: $BASH_COMPLETION_DIR/git-forbut"
    echo "    zsh:  $ZSH_COMPLETION_DIR/_git-forbut"
    echo "    fish: $FISH_COMPLETION_DIR/git-forbut.fish"
    if [[ -f $MANPAGE_PATH ]]; then
        echo "    man:  $MANPAGE_PATH"
        info "After adding $FORBUT_INSTALL_PREFIX/share/man to MANPATH, run:"
        echo ""
        echo "    man forbut"
        echo ""
    fi

    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        warn "$BIN_DIR is not on your PATH."
        warn "Add this to your shell config:"
        echo ""
        echo "    export PATH=\"$BIN_DIR:\$PATH\""
        echo ""
    fi
}

print_usage() {
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
    1. Installs forbut to PREFIX/share/forbut/
    2. Symlinks PREFIX/share/forbut/bin/git-forbut to PREFIX/bin/git-forbut
    3. Installs checked-in shell completions under PREFIX/share/
    4. Generates a forbut manpage when usage is available
    5. Prints shell integration instructions

${BOLD}SHELL INTEGRATION${RESET}
    After installing, add to your .bashrc or .zshrc:

        source "\$HOME/.local/share/forbut/forbut.sh"

${BOLD}ARTIFACTS${RESET}
    bash completion: PREFIX/share/bash-completion/completions/git-forbut
    zsh completion:  PREFIX/share/zsh/site-functions/_git-forbut
    fish completion: PREFIX/share/fish/vendor_completions.d/git-forbut.fish
    manpage:         PREFIX/share/man/man1/forbut.1 (optional)
EOF
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        --prefix=*) FORBUT_INSTALL_PREFIX="${arg#--prefix=}" ;;
        --symlink) SYMLINK=1 ;;
        --uninstall) UNINSTALL=1 ;;
        -h | --help)
            print_usage
            exit 0
            ;;
        *) error "Unknown option: $arg" ;;
    esac
done

set_prefix_paths

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
if [[ $UNINSTALL -eq 1 ]]; then
    info "Uninstalling forbut from $FORBUT_INSTALL_PREFIX ..."
    rm -f "$BIN_DIR/git-forbut"
    rm -f "$BASH_COMPLETION_DIR/git-forbut"
    rm -f "$ZSH_COMPLETION_DIR/_git-forbut"
    rm -f "$FISH_COMPLETION_DIR/git-forbut.fish"
    rm -f "$MANPAGE_PATH"
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

mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$BASH_COMPLETION_DIR" "$ZSH_COMPLETION_DIR" "$FISH_COMPLETION_DIR"

install_runtime_payload
install_completion_artifacts
install_optional_manpage
print_post_install_instructions
