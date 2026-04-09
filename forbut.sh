#!/usr/bin/env bash
# forbut.sh — main entry point / loader for forbut
# Source this file in your .bashrc / .zshrc to get shell functions and aliases.
#
# Usage:
#   [ -f ~/path/to/forbut/forbut.sh ] && source ~/path/to/forbut/forbut.sh
#
# Alias customisation (set before sourcing):
#   FORBUT_SWITCH_ALIAS=fbs
#   FORBUT_LOG_ALIAS=fbl
#   FORBUT_DIFF_ALIAS=fbd
#   FORBUT_ASSIGN_ALIAS=fba
#   FORBUT_DISCARD_ALIAS=fbD

# ---------------------------------------------------------------------------
# Resolve installation directory
# ---------------------------------------------------------------------------
if [[ -n "${ZSH_VERSION:-}" ]]; then
    # zsh: resolve symlinks and get the directory of this script
    0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
    0="${${(M)0:#/*}:-$PWD/$0}"
    FORBUT_INSTALL_DIR="${0:h}"
elif [[ -n "${BASH_VERSION:-}" ]]; then
    FORBUT_INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # Fallback: assume current directory
    FORBUT_INSTALL_DIR="${FORBUT_INSTALL_DIR:-$(pwd)}"
fi

export FORBUT_INSTALL_DIR
FORBUT="$FORBUT_INSTALL_DIR/bin/forbut"

# ---------------------------------------------------------------------------
# Source shared utilities
# ---------------------------------------------------------------------------
# shellcheck source=lib/utils.sh
source "$FORBUT_INSTALL_DIR/lib/utils.sh"

# ---------------------------------------------------------------------------
# Export FORBUT_* variables (backwards-compat migration)
# ---------------------------------------------------------------------------
if [[ -n "${ZSH_VERSION:-}" ]]; then
    # zsh: use parameter expansion flags to list matching variables
    for var in ${(k)parameters[(I)FORBUT_*]}; do
        export "$var"
    done
elif [[ -n "${BASH_VERSION:-}" ]]; then
    while IFS= read -r var; do
        if [[ -n "$var" ]]; then
            export "$var"
        fi
    done < <(compgen -v FORBUT_ 2>/dev/null || true)
fi

# ---------------------------------------------------------------------------
# Shell function registration
# ---------------------------------------------------------------------------
# Each function delegates to bin/forbut so all logic lives in one place.
# The only reason these exist is to provide nice shell-level names and
# to handle any operations that must run in the parent shell (e.g., cd).

forbut::switch() {
    "$FORBUT" switch "$@"
}

forbut::log() {
    "$FORBUT" log "$@"
}

forbut::diff() {
    "$FORBUT" diff "$@"
}

forbut::assign() {
    "$FORBUT" assign "$@"
}

forbut::discard() {
    "$FORBUT" discard "$@"
}

forbut::reorder() {
    "$FORBUT" reorder "$@"
}

# ---------------------------------------------------------------------------
# Alias registration
# ---------------------------------------------------------------------------
if [[ -z "${FORBUT_NO_ALIASES:-}" ]]; then
    # Each alias name is overridable via an environment variable.
    # Set the variable before sourcing this file to customise.
    builtin export FORBUT_SWITCH_ALIAS="${FORBUT_SWITCH_ALIAS:-fbs}"
    builtin export FORBUT_LOG_ALIAS="${FORBUT_LOG_ALIAS:-fbl}"
    builtin export FORBUT_DIFF_ALIAS="${FORBUT_DIFF_ALIAS:-fbd}"
    builtin export FORBUT_ASSIGN_ALIAS="${FORBUT_ASSIGN_ALIAS:-fba}"
    builtin export FORBUT_DISCARD_ALIAS="${FORBUT_DISCARD_ALIAS:-fbD}"
    builtin export FORBUT_REORDER_ALIAS="${FORBUT_REORDER_ALIAS:-fbr}"

    builtin alias "${FORBUT_SWITCH_ALIAS}"='forbut::switch'
    builtin alias "${FORBUT_LOG_ALIAS}"='forbut::log'
    builtin alias "${FORBUT_DIFF_ALIAS}"='forbut::diff'
    builtin alias "${FORBUT_ASSIGN_ALIAS}"='forbut::assign'
    builtin alias "${FORBUT_DISCARD_ALIAS}"='forbut::discard'
    builtin alias "${FORBUT_REORDER_ALIAS}"='forbut::reorder'
fi
