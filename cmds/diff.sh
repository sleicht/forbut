#!/usr/bin/env bash
# cmds/diff.sh — forbut::diff
# Browse changed files with inline diff preview.
#
# Uses `but status -f -j` (JSON) to get all files across unassigned changes,
# staged changes, and commits across all stacks. Previews use `but diff <cli_id>`.
# Falls back to `git diff` for non-GitButler repos.
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

    # Preview uses the CLI ID (field 1) to show diff via but diff
    local preview_cmd="$FORBUT _preview diff_file {1}"

    local selected
    selected=$(
        _forbut_diff_file_list "$target" |
        _forbut_fzf FORBUT_DIFF_FZF_OPTS \
            --header="$header" \
            --preview="$preview_cmd" \
            --bind="enter:execute(but diff {1} 2>/dev/null | $pager)" \
            --no-sort
    ) || return 0
}

# ---------------------------------------------------------------------------
# Helper: list changed files from but status -f -j (JSON)
# ---------------------------------------------------------------------------
# Output format:  <cli_id>  [<status>]  <filepath>  (<location>)
# e.g.:           ur  [M]  flake.nix  (unassigned)
#                 ae  [M]  src/lib.rs  (staged → my-branch)
#                 sv:ae  [M]  src/lib.rs  (commit: Initial commit)
_forbut_diff_file_list() {
    local target="${1:-}"

    # If a specific target is given, just show its diff
    if [[ -n "$target" ]]; then
        _forbut_diff_target_list "$target"
        return
    fi

    # Try but status -f -j first (requires GitButler project + jq)
    if _forbut_has_jq; then
        local _but_json
        _but_json=$(but status -f -j 2>/dev/null)
        if echo "$_but_json" | jq -e '.stacks' &>/dev/null; then
            _forbut_diff_but_json "$_but_json"
            return
        fi
    fi

    # Fallback: git diff for non-GitButler repos
    _forbut_diff_git_fallback
}

# ---------------------------------------------------------------------------
# Primary: parse but status -f -j for all file changes
# ---------------------------------------------------------------------------
_forbut_diff_but_json() {
    local json="$1"
    echo "$json" | jq -r '
        # Unassigned changes
        (.unassignedChanges // [] | .[] |
            "\(.cliId)\t\(.changeType)\t\(.filePath)\tunassigned"
        ),
        # Staged (assigned) changes per stack
        (.stacks // [] | .[] | .assignedChanges // [] | .[] |
            "\(.cliId)\t\(.changeType)\t\(.filePath)\tstaged"
        ),
        # Committed file changes across all stacks/branches/commits
        (.stacks // [] | .[] | .branches // [] | .[] |
            . as $branch |
            .commits // [] | .[] |
            . as $commit |
            .changes // [] | .[] |
            "\(.cliId)\t\(.changeType)\t\(.filePath)\t\($commit.message // "commit")"
        )
    ' 2>/dev/null | while IFS=$'\t' read -r cli_id change_type file_path location; do
        [[ -z "$cli_id" ]] && continue
        local status_marker color
        case "$change_type" in
            modified) status_marker="M"; color="$FORBUT_COLOR_YELLOW" ;;
            added)    status_marker="A"; color="$FORBUT_COLOR_GREEN" ;;
            removed)  status_marker="D"; color="$FORBUT_COLOR_RED" ;;
            renamed)  status_marker="R"; color="$FORBUT_COLOR_MAGENTA" ;;
            *)        status_marker="?"; color="$FORBUT_COLOR_DIM" ;;
        esac
        # Truncate long commit messages for the location tag
        local short_loc
        short_loc=$(echo "$location" | cut -c1-40)
        printf '%s  %s[%s]%s  %s  %s(%s)%s\n' \
            "$cli_id" "$color" "$status_marker" "$FORBUT_COLOR_RESET" \
            "$file_path" "$FORBUT_COLOR_DIM" "$short_loc" "$FORBUT_COLOR_RESET"
    done
}

# ---------------------------------------------------------------------------
# Specific target: show diff file list for a CLI ID
# ---------------------------------------------------------------------------
_forbut_diff_target_list() {
    local target="$1"
    if _forbut_has_jq; then
        but diff "$target" -j 2>/dev/null | jq -r '
            .changes // [] | .[] |
            "\(.id)\t\(.status)\t\(.path)"
        ' 2>/dev/null | while IFS=$'\t' read -r id fstat path; do
            [[ -z "$id" ]] && continue
            local status_marker color
            case "$fstat" in
                modified) status_marker="M"; color="$FORBUT_COLOR_YELLOW" ;;
                added)    status_marker="A"; color="$FORBUT_COLOR_GREEN" ;;
                removed)  status_marker="D"; color="$FORBUT_COLOR_RED" ;;
                renamed)  status_marker="R"; color="$FORBUT_COLOR_MAGENTA" ;;
                *)        status_marker="?"; color="$FORBUT_COLOR_DIM" ;;
            esac
            printf '%s  %s[%s]%s  %s\n' \
                "$id" "$color" "$status_marker" "$FORBUT_COLOR_RESET" "$path"
        done
    else
        but diff "$target" 2>/dev/null
    fi
}

# ---------------------------------------------------------------------------
# Fallback: git diff for non-GitButler repos
# ---------------------------------------------------------------------------
_forbut_diff_git_fallback() {
    {
        git diff --name-status 2>/dev/null
        git diff --name-status --cached 2>/dev/null
    } | sort -u | while IFS=$'\t' read -r fstat file rest; do
        [[ -z "$fstat" ]] && continue
        case "$fstat" in
            M)  printf '%s  %s[M]%s  %s\n' "$file" "$FORBUT_COLOR_YELLOW" "$FORBUT_COLOR_RESET" "$file" ;;
            A)  printf '%s  %s[A]%s  %s\n' "$file" "$FORBUT_COLOR_GREEN" "$FORBUT_COLOR_RESET" "$file" ;;
            D)  printf '%s  %s[D]%s  %s\n' "$file" "$FORBUT_COLOR_RED" "$FORBUT_COLOR_RESET" "$file" ;;
            R*) printf '%s  %s[%s]%s  %s -> %s\n' "$file" "$FORBUT_COLOR_CYAN" "$fstat" "$FORBUT_COLOR_RESET" "$file" "${rest:-}" ;;
            *)  printf '%s  [%s]  %s\n' "$file" "$fstat" "$file" ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Preview: show diff for a CLI ID or file path
# ---------------------------------------------------------------------------
_forbut_preview_diff_file() {
    local ref="$1"
    [[ -z "$ref" ]] && return

    local preview_pager
    preview_pager=$(_forbut_preview_pager)

    # Try but diff first (works for CLI IDs like "ur", "sv:ae", etc.)
    local but_output
    but_output=$(but diff "$ref" 2>/dev/null)
    if [[ -n "$but_output" ]]; then
        echo "$but_output" | eval "$preview_pager"
        return
    fi

    # Fallback to git diff for file paths
    git diff --color=always -- "$ref" 2>/dev/null | eval "$preview_pager"
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        git diff --cached --color=always -- "$ref" 2>/dev/null | eval "$preview_pager"
    fi
}
