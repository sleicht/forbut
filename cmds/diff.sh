#!/usr/bin/env bash
# cmds/diff.sh — forbut::diff
# Browse changed files with inline diff preview.
#
# Maps to: but diff <target>
# Forgit equivalent: forgit::diff

_forbut_cmd_diff() {
    local target="${1:-}"

    local header
    header="${FORBUT_COLOR_BOLD}Changed files${FORBUT_COLOR_RESET}  "
    header+="${FORBUT_COLOR_DIM}enter${FORBUT_COLOR_RESET}=full diff  "
    header+="${FORBUT_COLOR_DIM}ctrl-/${FORBUT_COLOR_RESET}=toggle preview"

    local pager
    pager=$(_forbut_pager)
    local preview_cmd="$FORBUT _preview diff_file {1}"

    # Get list of changed files from but status or git diff.
    # but status provides CLI IDs (e.g., g0, h0) which can be passed to but diff.
    # We also support falling back to git diff --name-status.
    local diff_source
    if [[ -n "$target" ]]; then
        diff_source="but diff $target 2>/dev/null"
    else
        # Use git diff --name-status for file listing (more parseable)
        diff_source="_forbut_diff_file_list"
    fi

    local selected
    selected=$(
        eval "$diff_source" |
        _forbut_fzf FORBUT_DIFF_FZF_OPTS \
            --header="$header" \
            --preview="$preview_cmd" \
            --bind="enter:execute(but diff {1} 2>/dev/null | $pager || git diff --color=always -- {-1} | $pager)" \
            --no-sort
    ) || return 0
}

# ---------------------------------------------------------------------------
# Helper: list changed files with status markers
# ---------------------------------------------------------------------------
_forbut_diff_file_list() {
    # Try but status first (to get CLI IDs), fall back to git
    local but_status
    but_status=$(but status 2>/dev/null) || true

    if [[ -n "$but_status" ]]; then
        echo "$but_status"
        return
    fi

    # Fallback: git diff --name-status with formatting
    git diff --name-status HEAD 2>/dev/null | while IFS=$'\t' read -r status file rest; do
        case "$status" in
            M)  printf '%s[M]%s  %s\n' "$FORBUT_COLOR_YELLOW" "$FORBUT_COLOR_RESET" "$file" ;;
            A)  printf '%s[A]%s  %s\n' "$FORBUT_COLOR_GREEN" "$FORBUT_COLOR_RESET" "$file" ;;
            D)  printf '%s[D]%s  %s\n' "$FORBUT_COLOR_RED" "$FORBUT_COLOR_RESET" "$file" ;;
            R*) printf '%s[%s]%s  %s -> %s\n' "$FORBUT_COLOR_CYAN" "$status" "$FORBUT_COLOR_RESET" "$file" "$rest" ;;
            *)  printf '[%s]  %s\n' "$status" "$file" ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Preview: show diff for a specific file
# ---------------------------------------------------------------------------
_forbut_preview_diff_file() {
    local file_ref="$1"
    [[ -z "$file_ref" ]] && return

    local preview_pager
    preview_pager=$(_forbut_preview_pager)

    # Try but diff with the CLI ID first, fall back to git diff
    (but diff "$file_ref" 2>/dev/null || git diff --color=always -- "$file_ref" 2>/dev/null) | \
        eval "$preview_pager"
}
