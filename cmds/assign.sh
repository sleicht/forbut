#!/usr/bin/env bash
# cmds/assign.sh — forbut::assign
# Fuzzy-select uncommitted hunks and assign to a stack.
# This is the core/killer feature of forbut — interactive hunk-to-branch assignment.
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

    # Step 1: Show uncommitted changes for hunk selection
    # but status shows CLI IDs for each hunk/file (e.g., g0, h0, i0)
    local selected_hunks
    selected_hunks=$(
        but status 2>/dev/null |
        _forbut_fzf FORBUT_ASSIGN_FZF_OPTS \
            --header="$header" \
            --preview="$preview_cmd" \
            --multi \
            --bind="ctrl-a:select-all"
    ) || return 0

    if [[ -z "$selected_hunks" ]]; then
        return 0
    fi

    # Extract hunk IDs (first field of each selected line)
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
        but branch list --all 2>/dev/null |
        _forbut_fzf FORBUT_ASSIGN_BRANCH_FZF_OPTS \
            --header="$branch_header" \
            --preview="$FORBUT _preview switch_branch {1}" \
            --no-multi
    ) || return 0

    local branch_id
    branch_id=$(echo "$target_branch" | awk '{print $1}')

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
# Preview: show hunk diff
# ---------------------------------------------------------------------------
_forbut_preview_assign_hunk() {
    local hunk_ref="$1"
    [[ -z "$hunk_ref" ]] && return

    local preview_pager
    preview_pager=$(_forbut_preview_pager)

    # Show the diff for the selected hunk/file
    (but diff "$hunk_ref" 2>/dev/null || git diff --color=always 2>/dev/null) | \
        eval "$preview_pager"
}
