#!/usr/bin/env bash
# cmds/diff.sh — forbut::diff
# Browse changed files with inline diff preview.
#
# Maps to: but diff <target> / git diff
# Forgit equivalent: forgit::diff

_forbut_cmd_diff() {
    local target="${1:-}"

    local header
    header="${FORBUT_COLOR_BOLD}Changed files${FORBUT_COLOR_RESET}  "
    header+="${FORBUT_COLOR_DIM}enter${FORBUT_COLOR_RESET}=full diff  "
    header+="${FORBUT_COLOR_DIM}ctrl-/${FORBUT_COLOR_RESET}=toggle preview"

    local pager
    pager=$(_forbut_pager)

    # Preview shows the diff for the file path (last field after the status marker)
    local preview_cmd="$FORBUT _preview diff_file {2..}"

    local selected
    selected=$(
        _forbut_diff_file_list "$target" |
        _forbut_fzf FORBUT_DIFF_FZF_OPTS \
            --header="$header" \
            --preview="$preview_cmd" \
            --bind="enter:execute(git diff --color=always -- {2..} | $pager)" \
            --no-sort
    ) || return 0
}

# ---------------------------------------------------------------------------
# Helper: list changed files with status markers
# ---------------------------------------------------------------------------
_forbut_diff_file_list() {
    local target="${1:-}"

    if [[ -n "$target" ]]; then
        # Diff against a specific ref
        git diff --name-status "$target" 2>/dev/null
    else
        # Uncommitted changes: staged + unstaged
        {
            git diff --name-status 2>/dev/null
            git diff --name-status --cached 2>/dev/null
        } | sort -u
    fi | while IFS=$'\t' read -r status file rest; do
        [[ -z "$status" ]] && continue
        case "$status" in
            M)  printf '%s[M]%s  %s\n' "$FORBUT_COLOR_YELLOW" "$FORBUT_COLOR_RESET" "$file" ;;
            A)  printf '%s[A]%s  %s\n' "$FORBUT_COLOR_GREEN" "$FORBUT_COLOR_RESET" "$file" ;;
            D)  printf '%s[D]%s  %s\n' "$FORBUT_COLOR_RED" "$FORBUT_COLOR_RESET" "$file" ;;
            R*) printf '%s[%s]%s  %s -> %s\n' "$FORBUT_COLOR_CYAN" "$status" "$FORBUT_COLOR_RESET" "$file" "${rest:-}" ;;
            *)  printf '[%s]  %s\n' "$status" "$file" ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Preview: show diff for a specific file
# ---------------------------------------------------------------------------
_forbut_preview_diff_file() {
    # All args form the file path (handles paths with spaces)
    local file_ref="$*"
    [[ -z "$file_ref" ]] && return

    local preview_pager
    preview_pager=$(_forbut_preview_pager)

    git diff --color=always -- "$file_ref" 2>/dev/null | eval "$preview_pager"
    # If no unstaged diff, try staged
    if [[ ${PIPESTATUS[0]} -ne 0 ]] || [[ ! -s /dev/stdin ]]; then
        git diff --cached --color=always -- "$file_ref" 2>/dev/null | eval "$preview_pager"
    fi
}
