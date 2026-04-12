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

_forbut_require_jq() {
    if ! _forbut_check_cmd jq; then
        _forbut_die "'jq' is required by forbut (JSON is the primary contract with 'but')." \
            "Install with: brew install jq  /  apt install jq  /  pacman -S jq"
        return 1
    fi
}

_forbut_check_prerequisites() {
    _forbut_require_but || return 1
    _forbut_require_fzf || return 1
    _forbut_require_jq || return 1
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
# fzf wrapper
# ---------------------------------------------------------------------------
# Run fzf with forbut defaults + per-command options.
# Usage: _forbut_fzf <FORBUT_CMD_FZF_OPTS_VAR> [extra-fzf-opts...]
# The first argument is the NAME of an env var holding per-command fzf options
# (e.g., "FORBUT_SWITCH_FZF_OPTS"). Pass "" to skip.
# Global fzf defaults are set via FORBUT_FZF_DEFAULT_OPTS (defined below),
# which users may override from their shell config.
_forbut_fzf() {
    local _cmd_opts_var="$1"; shift
    local _cmd_opts=""
    if [[ -n "$_cmd_opts_var" ]]; then
        _cmd_opts="${!_cmd_opts_var:-}"
    fi
    FZF_DEFAULT_OPTS="$FORBUT_FZF_DEFAULT_OPTS $_cmd_opts" fzf "$@"
    local exit_code=$?
    # Treat ctrl-c / esc (130) as graceful exit
    [[ $exit_code -eq 130 ]] && return 0
    return $exit_code
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
#   forbut preview <func> <args...>
# This ensures all helpers are available in the preview subprocess.
_forbut_preview() {
    local cmd="$1"; shift
    export FORBUT_IN_PREVIEW=1
    "_forbut_${cmd}" "$@"
}

_forbut_enter() {
    local cmd="$1"; shift
    "_forbut_${cmd}" "$@"
}

# ===========================================================================
# forgit-aligned helpers (ported from bin/git-forgit)
# ===========================================================================
# These replace the earlier ad-hoc parsing approach. Every fuzzy picker in
# forbut produces rows shaped as: <display>${_fbsep}<payload>
# fzf then shows field 1 (display) and returns field 2 (payload) via
# --delimiter/--with-nth=1/--accept-nth=2. Commands never parse display text.

# Internal display/payload separator. Lowercase because it's an implementation
# detail; users should never override it. (US = 0x1f, RS = 0x1e — unlikely to
# appear in git output, file paths, branch names, or commit messages.)
_fbsep=$'\x1f\x1e'

# FORBUT_FZF_DEFAULT_OPTS — users can override in their shell config to tweak
# global forbut fzf behaviour. Per-command FORBUT_<CMD>_FZF_OPTS still layer on
# top via _forbut_fzf.
FORBUT_FZF_DEFAULT_OPTS="
${FZF_DEFAULT_OPTS:-}
--ansi
--height=80%
--border
--reverse
--info=inline
--header-first
--bind=ctrl-d:preview-page-down
--bind=ctrl-u:preview-page-up
--bind=ctrl-/:toggle-preview
--bind=alt-w:toggle-preview-wrap
--preview-window=right:55%:wrap
--color=header:italic
${FORBUT_FZF_DEFAULT_OPTS:-}
"

# ---------------------------------------------------------------------------
# Text extraction primitives
# ---------------------------------------------------------------------------
_forbut_strip_ansi() {
    local ESC=$'\033'
    sed "s/${ESC}\[[0-9;]*m//g"
}

# Pull the first git SHA from stdin and strip whitespace.
_forbut_extract_sha() {
    grep -Eo '[a-f0-9]+' | head -1 | tr -d '[:space:]'
}

# Copy the first SHA in $1 to the clipboard.
_forbut_yank_sha() {
    echo "$1" | _forbut_extract_sha | ${FORBUT_COPY_CMD:-pbcopy}
}

# Extract a branch name from a `git branch` / `but branch list` output line:
# strips ANSI, current/worktree markers ('* '/'+ '), and symbolic-ref arrows.
_forbut_extract_branch_name() {
    _forbut_strip_ansi |
        sed -E 's/^[*+ ] //; s/ -> .*//' |
        awk '{print $1}'
}

# tac on GNU, tail -r on BSD/macOS.
_forbut_reverse_lines() {
    tac 2>/dev/null || tail -r
}

# Split a space-separated string in $2 into a global array named $1.
_forbut_parse_array() {
    ${IFS+"false"} && unset old_IFS || old_IFS="$IFS"
    IFS=" " read -r -a "$1" <<< "$2"
    ${old_IFS+"false"} && unset IFS || IFS="$old_IFS"
}

# ---------------------------------------------------------------------------
# Branch / worktree listing (pure-git fallback for non-GitButler repos)
# ---------------------------------------------------------------------------
# Emits a plain git branch list with the current branch first. Used as the
# fallback when `but branch list` is unavailable or the repo has no stacks.
_forbut_git_branch_list() {
    local current
    current=$(git branch --show-current 2>/dev/null)
    if [[ -n "$current" ]]; then
        printf '%s* %s%s\n' "$FORBUT_COLOR_DIM" "$current" "$FORBUT_COLOR_RESET"
    else
        printf '%s* (HEAD detached at %s)%s\n' \
            "$FORBUT_COLOR_DIM" "$(git rev-parse --short HEAD 2>/dev/null)" "$FORBUT_COLOR_RESET"
    fi
    git branch --color=always "$@" 2>/dev/null | grep -v '^\*' | grep -v ' -> '
}

# Worktree changes in porcelain form, with null-terminated paths so filenames
# with spaces/newlines/backslashes survive intact. Output is one line per
# entry, shaped as: <coloured [status] display>${_fbsep}<absolute path>
_forbut_worktree_changes() {
    local rootdir show_untracked
    rootdir=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
    show_untracked=$(git config status.showUntrackedFiles 2>/dev/null)

    git -c color.status=always status --porcelain -z \
        --untracked-files="${show_untracked:-all}" 2>/dev/null |
        tr '\0' '\n' |
        awk -v sep="$_fbsep" -v root="$rootdir" '
            NF == 0 { next }
            {
                # Porcelain format: "XY path" where XY is the two-char status
                status = substr($0, 1, 2)
                path = substr($0, 4)
                printf "[%s]  %s%s%s/%s\n", status, path, sep, root, path
            }
        '
}

# List all tracked files, null-terminated so paths with whitespace survive.
_forbut_list_files() {
    local rootdir
    rootdir=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
    git ls-files -z "$@" "$rootdir" 2>/dev/null | tr '\0' '\n' | uniq
}

# ---------------------------------------------------------------------------
# Keyed pager resolution (forgit-style)
# ---------------------------------------------------------------------------
# _forbut_get_pager <key>
#   core    — default diff pager
#   diff    — git config pager.diff, else delta, else cat
#   show    — git config pager.show, else delta, else cat
#   blame   — git config pager.blame, else cat
#   enter   — LESS -r (used when an Enter action pipes into a pager)
_forbut_get_pager() {
    local key="${1:-core}"
    case "$key" in
        core)
            if [[ -n "${FORBUT_PAGER:-}" ]]; then
                echo "$FORBUT_PAGER"
            elif _forbut_has_delta; then
                echo "delta"
            else
                local gp
                gp=$(git config core.pager 2>/dev/null)
                echo "${gp:-cat}"
            fi
            ;;
        diff)
            local dp
            dp=$(git config pager.diff 2>/dev/null)
            if [[ -n "${FORBUT_DIFF_PAGER:-}" ]]; then
                echo "$FORBUT_DIFF_PAGER"
            elif [[ -n "$dp" ]]; then
                echo "$dp"
            else
                _forbut_get_pager core
            fi
            ;;
        show)
            local sp
            sp=$(git config pager.show 2>/dev/null)
            if [[ -n "${FORBUT_SHOW_PAGER:-}" ]]; then
                echo "$FORBUT_SHOW_PAGER"
            elif [[ -n "$sp" ]]; then
                echo "$sp"
            else
                _forbut_get_pager core
            fi
            ;;
        blame)
            local bp
            bp=$(git config pager.blame 2>/dev/null)
            if [[ -n "${FORBUT_BLAME_PAGER:-}" ]]; then
                echo "$FORBUT_BLAME_PAGER"
            elif [[ -n "$bp" ]]; then
                echo "$bp"
            else
                _forbut_get_pager core
            fi
            ;;
        enter)
            echo "${FORBUT_ENTER_PAGER:-LESS='-r' less}"
            ;;
        *)
            echo "cat"
            ;;
    esac
}

# Route output through the correct pager. Inside fzf preview windows
# (FORBUT_IN_PREVIEW=1), prefer FORBUT_PREVIEW_PAGER; otherwise use the
# key-based pager. This marker is set by _forbut_preview.
_forbut_pager_route() {
    local key="${1:-core}"; shift
    local pager
    if [[ -n "${FORBUT_IN_PREVIEW:-}" ]] && [[ -n "${FORBUT_PREVIEW_PAGER:-}" ]]; then
        pager="$FORBUT_PREVIEW_PAGER"
    else
        pager=$(_forbut_get_pager "$key")
    fi
    [[ -z "$pager" ]] && return 1
    eval "$pager $*"
}

# ---------------------------------------------------------------------------
# JSON schema guard + drift log
# ---------------------------------------------------------------------------
# _forbut_schema_assert <json-blob> <jq-path> <command-name>
# Exits non-zero and logs a drift record if the jq path is not present.
# The drift log is append-only at $XDG_STATE_HOME/forbut/schema-drift.log and
# rotates when it exceeds ~1MB. Each record is a one-line JSON object.
_forbut_schema_drift_log_path() {
    local dir="${XDG_STATE_HOME:-$HOME/.local/state}/forbut"
    mkdir -p "$dir" 2>/dev/null
    echo "$dir/schema-drift.log"
}

_forbut_schema_drift_log() {
    local missing_path="$1" command="$2" raw_sample="$3"
    local log_file
    log_file=$(_forbut_schema_drift_log_path) || return 0
    local but_version forbut_version timestamp
    but_version=$(but --version 2>/dev/null | head -1 | tr -d '\n')
    forbut_version="$FORBUT_VERSION"
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)

    # Build the record with jq so quoting is always correct.
    if _forbut_check_cmd jq; then
        jq -cn \
            --arg ts "$timestamp" \
            --arg bv "$but_version" \
            --arg fv "$forbut_version" \
            --arg mp "$missing_path" \
            --arg cmd "$command" \
            --arg raw "$raw_sample" \
            '{timestamp:$ts, but_version:$bv, forbut_version:$fv, missing_path:$mp, command:$cmd, raw_sample:$raw}' \
            >> "$log_file" 2>/dev/null
    fi

    # Rotate if file exceeds ~1MB.
    if [[ -f "$log_file" ]]; then
        local size
        size=$(wc -c < "$log_file" 2>/dev/null | tr -d ' ')
        if [[ -n "$size" ]] && (( size > 1048576 )); then
            mv "$log_file" "$log_file.1" 2>/dev/null
        fi
    fi
}

# ---------------------------------------------------------------------------
# but wrapper — strips stdout banners GitButler prints during background sync
# ---------------------------------------------------------------------------
# GitButler's `but` CLI prints lines like "Initiated a background sync ..."
# to STDOUT (not stderr). Those lines pollute captured diffs and break jq
# when mixed with JSON. This wrapper filters them before output reaches callers.
_forbut_but() {
    but "$@" 2>/dev/null | sed -E '/Initiated a background sync/d; /^Last fetch was/d'
}

# Add ANSI colour to but diff --no-tui box-drawing output.
# Colours lines containing │+ (additions) green and │- (deletions) red.
_forbut_colorize_but_diff() {
    sed -E $'s/(.*\u2502\\+.*)/\x1b[32m\\1\x1b[0m/; s/(.*\u2502-.*)/\x1b[31m\\1\x1b[0m/'
}

# ---------------------------------------------------------------------------
# Unassigned-changes list (shared by assign/discard/diff)
# ---------------------------------------------------------------------------
# Emits _fbsep-delimited rows for unassigned worktree changes only.
# JSON-first via `but status -f -j`, falling back to pure-git porcelain.
# Row shape: <coloured [status] filepath>${_fbsep}<cli_id-or-path>
_forbut_unassigned_list() {
    local json
    json=$(_forbut_but status -f -j)
    if [[ -n "$json" ]] && echo "$json" | jq -e '.unassignedChanges // empty' >/dev/null 2>&1; then
        if ! _forbut_schema_assert "$json" '.unassignedChanges | type == "array"' 'unassigned'; then
            return 1
        fi
        echo "$json" | jq -r --arg sep "$_fbsep" '
            def marker:
                if   . == "modified" then "\u001b[33m[M]\u001b[0m"
                elif . == "added"    then "\u001b[32m[A]\u001b[0m"
                elif . == "removed"  then "\u001b[31m[D]\u001b[0m"
                elif . == "renamed"  then "\u001b[35m[R]\u001b[0m"
                else "\u001b[2m[?]\u001b[0m" end;
            .unassignedChanges // [] | .[] |
            "\(.changeType | marker)  \(.filePath)\($sep)\(.cliId)"
        ' 2>/dev/null
        return
    fi

    # Non-GitButler fallback: worktree changes (already _fbsep-delimited).
    _forbut_worktree_changes
}

_forbut_schema_assert() {
    local json="$1" jq_path="$2" command="$3"
    if [[ -z "$json" ]]; then
        _forbut_error "Empty JSON from 'but' — is 'but' installed and the repo a GitButler project?"
        return 1
    fi
    if ! echo "$json" | jq -e "$jq_path" >/dev/null 2>&1; then
        local but_version sample
        but_version=$(but --version 2>/dev/null | head -1)
        sample=$(echo "$json" | head -c 200)
        _forbut_error "Schema drift: field '$jq_path' missing from 'but' output ($command)."
        _forbut_error "  but version: ${but_version:-unknown}"
        _forbut_error "  forbut version: $FORBUT_VERSION"
        _forbut_error "  Drift log: $(_forbut_schema_drift_log_path)"
        _forbut_error "  Please file an issue at https://github.com/user/forbut/issues"
        _forbut_schema_drift_log "$jq_path" "$command" "$sample"
        return 1
    fi
    return 0
}
