#!/usr/bin/env bash
# forbut/lib/utils.sh — shared helpers for forbut
# Provides: dependency checks, fzf wrapper, colour definitions, pager resolution,
#           version guards, and output parsing utilities.

# ---------------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------------
FORBUT_VERSION="0.1.0"
REQUIRED_FZF_VERSION="0.42.0"

# ---------------------------------------------------------------------------
# Colour palette (ANSI escape codes)
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
    FORBUT_COLOR_RESET=$'\033[0m'
    FORBUT_COLOR_RED=$'\033[0;31m'
    FORBUT_COLOR_GREEN=$'\033[0;32m'
    FORBUT_COLOR_YELLOW=$'\033[0;33m'
    FORBUT_COLOR_BLUE=$'\033[0;34m'
    FORBUT_COLOR_MAGENTA=$'\033[0;35m'
    FORBUT_COLOR_CYAN=$'\033[0;36m'
    FORBUT_COLOR_BOLD=$'\033[1m'
    FORBUT_COLOR_DIM=$'\033[2m'
else
    FORBUT_COLOR_RESET=""
    FORBUT_COLOR_RED=""
    FORBUT_COLOR_GREEN=""
    FORBUT_COLOR_YELLOW=""
    FORBUT_COLOR_BLUE=""
    FORBUT_COLOR_MAGENTA=""
    FORBUT_COLOR_CYAN=""
    FORBUT_COLOR_BOLD=""
    FORBUT_COLOR_DIM=""
fi

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
_forbut_info() {
    printf '%s[forbut]%s %s\n' "$FORBUT_COLOR_CYAN" "$FORBUT_COLOR_RESET" "$*" >&2
}

_forbut_warn() {
    printf '%s[forbut]%s %s\n' "$FORBUT_COLOR_YELLOW" "$FORBUT_COLOR_RESET" "$*" >&2
}

_forbut_error() {
    printf '%s[forbut]%s %s\n' "$FORBUT_COLOR_RED" "$FORBUT_COLOR_RESET" "$*" >&2
}

_forbut_die() {
    _forbut_error "$@"
    return 1
}

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
_forbut_check_cmd() {
    command -v "$1" &>/dev/null
}

_forbut_require_but() {
    if ! _forbut_check_cmd but; then
        _forbut_die "'but' (GitButler CLI) is not installed or not on PATH." \
            "Install it from https://docs.gitbutler.com/cli"
        return 1
    fi
}

_forbut_require_fzf() {
    if ! _forbut_check_cmd fzf; then
        _forbut_die "'fzf' is not installed or not on PATH." \
            "Install it from https://github.com/junegunn/fzf"
        return 1
    fi
    local installed_fzf_version
    installed_fzf_version=$(fzf --version 2>/dev/null | awk '{print $1}')
    if [[ -z "$installed_fzf_version" ]]; then
        _forbut_die "Could not determine fzf version."
        return 1
    fi
    local higher
    higher=$(printf '%s\n' "$REQUIRED_FZF_VERSION" "$installed_fzf_version" | sort -V | tail -n1)
    if [[ "$higher" != "$installed_fzf_version" ]]; then
        _forbut_die "fzf version $REQUIRED_FZF_VERSION or higher is required (found $installed_fzf_version)."
        return 1
    fi
}

_forbut_check_prerequisites() {
    _forbut_require_but || return 1
    _forbut_require_fzf || return 1
}

# ---------------------------------------------------------------------------
# Optional tool detection (delta, bat)
# ---------------------------------------------------------------------------
_forbut_has_delta() {
    _forbut_check_cmd delta
}

_forbut_has_bat() {
    _forbut_check_cmd bat || _forbut_check_cmd batcat
}

_forbut_bat_cmd() {
    if _forbut_check_cmd bat; then
        echo "bat"
    elif _forbut_check_cmd batcat; then
        echo "batcat"
    else
        echo "cat"
    fi
}

# ---------------------------------------------------------------------------
# Pager resolution
# ---------------------------------------------------------------------------
# Cascading pager resolution:
# 1. FORBUT_PAGER (user override)
# 2. delta (if available)
# 3. git core.pager
# 4. cat
_forbut_pager() {
    if [[ -n "${FORBUT_PAGER:-}" ]]; then
        echo "$FORBUT_PAGER"
    elif _forbut_has_delta; then
        echo "delta"
    else
        local git_pager
        git_pager=$(git config core.pager 2>/dev/null)
        if [[ -n "$git_pager" ]]; then
            echo "$git_pager"
        else
            echo "cat"
        fi
    fi
}

# Preview pager — used inside fzf preview windows.
# delta needs --width for preview panes.
_forbut_preview_pager() {
    if [[ -n "${FORBUT_PREVIEW_PAGER:-}" ]]; then
        echo "$FORBUT_PREVIEW_PAGER"
    elif _forbut_has_delta; then
        echo "delta --width=\${FZF_PREVIEW_COLUMNS:-80}"
    else
        echo "cat"
    fi
}

# ---------------------------------------------------------------------------
# fzf wrapper
# ---------------------------------------------------------------------------
# Build the base fzf options string. Layers:
#   1. $FZF_DEFAULT_OPTS           (user's global fzf config)
#   2. forbut built-in defaults    (ANSI, height, keybindings, preview layout)
#   3. $FORBUT_FZF_DEFAULT_OPTS    (user's forbut-specific overrides)
_forbut_fzf_defaults() {
    local builtin_opts="--ansi --height=80% --border --reverse --info=inline"
    builtin_opts+=" --header-first"
    builtin_opts+=" --bind=ctrl-d:preview-page-down"
    builtin_opts+=" --bind=ctrl-u:preview-page-up"
    builtin_opts+=" --bind=ctrl-/:toggle-preview"
    builtin_opts+=" --preview-window=right:55%:wrap"
    builtin_opts+=" --color=header:italic"
    echo "${FZF_DEFAULT_OPTS:-} $builtin_opts ${FORBUT_FZF_DEFAULT_OPTS:-}"
}

# Run fzf with forbut defaults + per-command options.
# Usage: _forbut_fzf <FORBUT_CMD_FZF_OPTS_VAR> [extra-fzf-opts...]
# The first argument is the NAME of an env var holding per-command fzf options
# (e.g., "FORBUT_SWITCH_FZF_OPTS"). Pass "" to skip.
# Remaining arguments are passed directly to fzf as proper args, preserving
# quoting for values with spaces (--header, --preview, --bind, etc.).
_forbut_fzf() {
    local _cmd_opts_var="$1"; shift
    local _cmd_opts=""
    if [[ -n "$_cmd_opts_var" ]]; then
        _cmd_opts="${!_cmd_opts_var:-}"
    fi
    FZF_DEFAULT_OPTS="$(_forbut_fzf_defaults) $_cmd_opts" fzf "$@"
    local exit_code=$?
    # Treat ctrl-c / esc (130) as graceful exit
    [[ $exit_code -eq 130 ]] && return 0
    return $exit_code
}

# ---------------------------------------------------------------------------
# but JSON helpers
# ---------------------------------------------------------------------------
# Run a but command with --json and parse with jq.
# Usage: _forbut_but_json <but-subcommand...>
_forbut_but_json() {
    but "$@" --json 2>/dev/null
}

# Check if jq is available; many operations benefit from it but can fall back.
_forbut_has_jq() {
    _forbut_check_cmd jq
}

# ---------------------------------------------------------------------------
# but version guard
# ---------------------------------------------------------------------------
_forbut_but_version() {
    but --version 2>/dev/null | head -1
}

# ---------------------------------------------------------------------------
# Git repo guard
# ---------------------------------------------------------------------------
_forbut_require_repo() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        _forbut_die "Not inside a git repository."
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Preview dispatcher (self-invocation pattern)
# ---------------------------------------------------------------------------
# When fzf needs a preview, it calls back into forbut with:
#   forbut _preview <func> <args...>
# This ensures all helpers are available in the preview subprocess.
_forbut_preview() {
    local cmd="$1"; shift
    export FORBUT_IN_PREVIEW=1
    "_forbut_preview_${cmd}" "$@"
}

# ---------------------------------------------------------------------------
# Separator for fzf display vs payload
# ---------------------------------------------------------------------------
# Uses ASCII Unit Separator + Record Separator to split display text from
# machine-parseable data. Combined with fzf --with-nth and --accept-nth.
FORBUT_SEP=$'\x1f\x1e'

# Extract the payload (right side) from a separator-delimited fzf selection.
_forbut_extract_payload() {
    echo "$1" | sed "s/.*${FORBUT_SEP}//"
}

# Extract the display (left side) from a separator-delimited string.
_forbut_extract_display() {
    echo "$1" | sed "s/${FORBUT_SEP}.*//"
}
