#!/usr/bin/env bash
# cmds/assign.sh — forbut::assign
# Fuzzy-select uncommitted hunks and assign to a stack.
# This is the core/killer feature of forbut — interactive hunk-to-branch assignment.
#
# Uses `but status -j` (JSON) to get unassigned changes with CLI IDs,
# then `but diff <cli_id>` for previews, and `but stage` to assign.
#
# Maps to: but stage <hunk_ids> <branch>
# Forgit equivalent: forgit::add (but more powerful with virtual branch targeting)

_forbut_cmd_assign() {
    local header
    header="${FORBUT_COLOR_BOLD}Assign hunks to branch${FORBUT_COLOR_RESET}  "
    header+="${FORBUT_COLOR_DIM}tab${FORBUT_COLOR_RESET}=select  "
    header+="${FORBUT_COLOR_DIM}enter${FORBUT_COLOR_RESET}=assign selected  "
    header+="${FORBUT_COLOR_DIM}ctrl-a${FORBUT_COLOR_RESET}=select all  "
    header+="${FORBUT_COLOR_DIM}ctrl-/${FORBUT_COLOR_RESET}=toggle preview"

    local preview_cmd="$FORBUT _preview assign_hunk {1}"

    # Step 1: Show uncommitted/unassigned changes for hunk selection
    local selected_hunks
    selected_hunks=$(
        _forbut_unassigned_file_list |
        _forbut_fzf FORBUT_ASSIGN_FZF_OPTS \
            --header="$header" \
            --preview="$preview_cmd" \
            --multi \
            --bind="ctrl-a:select-all"
    ) || return 0

    if [[ -z "$selected_hunks" ]]; then
        return 0
    fi

    # Extract CLI IDs (first field of each selected line)
    local hunk_ids
    hunk_ids=$(echo "$selected_hunks" | awk '{print $1}' | paste -sd ',' -)

    if [[ -z "$hunk_ids" ]]; then
        _forbut_warn "No hunks selected."
        return 0
    fi

    # Step 2: Select target branch
    local branch_header
    branch_header="${FORBUT_COLOR_BOLD}Select target branch${FORBUT_COLOR_RESET}  "
    branch_header+="${FORBUT_COLOR_DIM}enter${FORBUT_COLOR_RESET}=assign to this branch"

    local target_branch
    target_branch=$(
        _forbut_branch_list |
        _forbut_fzf FORBUT_ASSIGN_BRANCH_FZF_OPTS \
            --header="$branch_header" \
            --preview="$FORBUT _preview switch_branch {3}" \
            --no-multi
    ) || return 0

    local branch_id
    branch_id=$(echo "$target_branch" | awk '{print $3}' | sed 's/^\*//')

    if [[ -z "$branch_id" ]]; then
        _forbut_warn "No branch selected."
        return 0
    fi

    # Step 3: Execute the assignment
    _forbut_info "Staging hunks ($hunk_ids) to branch: $branch_id"
    but stage "$hunk_ids" "$branch_id"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        _forbut_info "Done. Hunks assigned successfully."
    else
        _forbut_error "Failed to assign hunks (exit code: $exit_code)."
    fi

    return $exit_code
}

# ---------------------------------------------------------------------------
# Helper: list unassigned changes from but status -j (JSON)
# ---------------------------------------------------------------------------
# Output format: <cli_id>  [<status>]  <filepath>
_forbut_unassigned_file_list() {
    local _but_json
    _but_json=$(but status -j 2>/dev/null) || true
    if _forbut_has_jq && echo "$_but_json" | jq -e '.unassignedChanges' &>/dev/null; then
        echo "$_but_json" | jq -r '
            .unassignedChanges // [] | .[] |
            "\(.cliId)\t\(.changeType)\t\(.filePath)"
        ' 2>/dev/null | while IFS=$'\t' read -r cli_id change_type file_path; do
            [[ -z "$cli_id" ]] && continue
            local status_marker color
            case "$change_type" in
                modified) status_marker="M"; color="$FORBUT_COLOR_YELLOW" ;;
                added)    status_marker="A"; color="$FORBUT_COLOR_GREEN" ;;
                removed)  status_marker="D"; color="$FORBUT_COLOR_RED" ;;
                renamed)  status_marker="R"; color="$FORBUT_COLOR_MAGENTA" ;;
                *)        status_marker="?"; color="$FORBUT_COLOR_DIM" ;;
            esac
            printf '%s  %s[%s]%s  %s\n' \
                "$cli_id" "$color" "$status_marker" "$FORBUT_COLOR_RESET" "$file_path"
        done
    else
        # Fallback: git status for non-GitButler repos
        git diff --name-status 2>/dev/null | while IFS=$'\t' read -r fstat file; do
            [[ -z "$fstat" ]] && continue
            printf '%s  [%s]  %s\n' "$file" "$fstat" "$file"
        done
    fi
}

# ---------------------------------------------------------------------------
# Preview: show hunk diff
# ---------------------------------------------------------------------------
_forbut_preview_assign_hunk() {
    local hunk_ref="$1"
    [[ -z "$hunk_ref" ]] && return

    local preview_pager
    preview_pager=$(_forbut_preview_pager)

    # Use but diff with CLI ID for preview
    local but_output
    but_output=$(but diff "$hunk_ref" 2>/dev/null) || true
    if [[ -n "$but_output" ]]; then
        echo "$but_output" | eval "$preview_pager"
        return
    fi

    # Fallback to git diff
    git diff --color=always -- "$hunk_ref" 2>/dev/null | eval "$preview_pager"
}
