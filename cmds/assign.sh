#!/usr/bin/env bash
# cmds/assign.sh — forbut::assign
# Fuzzy-select uncommitted hunks and assign to a stack.
# This is the core/killer feature of forbut: interactive hunk-to-branch
# assignment that forgit can't do (no virtual branches in vanilla git).
#
# Flow:
#   1. Select one or more unassigned changes via _forbut_unassigned_list
#      → fzf returns payloads (cli_ids).
#   2. Select a target branch via _forbut_switch_list → fzf returns
#      payload (branch name).
#   3. Execute `but stage <cli_ids> <branch>`.
#
# Every payload comes back clean from fzf via --accept-nth=2 — no awk,
# no sed, no column guessing.
#
# Maps to: but stage <hunk_ids> <branch>
# Forgit equivalent: forgit::add (but more powerful with virtual branches)

_forbut_cmd_assign() {
    local header
    header="${FORBUT_COLOR_BOLD}Assign hunks to branch${FORBUT_COLOR_RESET}  "
    header+="${FORBUT_COLOR_DIM}tab${FORBUT_COLOR_RESET}=select  "
    header+="${FORBUT_COLOR_DIM}enter${FORBUT_COLOR_RESET}=assign selected  "
    header+="${FORBUT_COLOR_DIM}ctrl-a${FORBUT_COLOR_RESET}=select all  "
    header+="${FORBUT_COLOR_DIM}ctrl-/${FORBUT_COLOR_RESET}=toggle preview"

    local preview_cmd="$FORBUT _preview assign_hunk {}"

    # Step 1: Fuzzy-pick unassigned hunks. fzf returns one payload per line
    # (the CLI IDs), already clean.
    local selected_ids
    selected_ids=$(
        _forbut_unassigned_list |
        _forbut_fzf FORBUT_ASSIGN_FZF_OPTS \
            --delimiter="$_FBSEP" \
            --with-nth=1 \
            --accept-nth=2 \
            --header="$header" \
            --preview="$preview_cmd" \
            --multi \
            --bind="ctrl-a:select-all"
    )

    if [[ -z "$selected_ids" ]]; then
        return 0
    fi

    # fzf with --multi returns one payload per line. Join with commas for
    # `but stage`.
    local hunk_ids
    hunk_ids=$(echo "$selected_ids" | paste -sd ',' -)

    if [[ -z "$hunk_ids" ]]; then
        _forbut_warn "No hunks selected."
        return 0
    fi

    # Step 2: Pick the target branch. _forbut_switch_list reuses the same
    # display/payload contract — branch name comes back clean.
    local branch_header
    branch_header="${FORBUT_COLOR_BOLD}Select target branch${FORBUT_COLOR_RESET}  "
    branch_header+="${FORBUT_COLOR_DIM}enter${FORBUT_COLOR_RESET}=assign to this branch"

    local target_branch
    target_branch=$(
        _forbut_switch_list |
        _forbut_fzf FORBUT_ASSIGN_BRANCH_FZF_OPTS \
            --delimiter="$_FBSEP" \
            --with-nth=1 \
            --accept-nth=2 \
            --header="$branch_header" \
            --preview="$FORBUT _preview switch_branch {}" \
            --no-multi
    )

    if [[ -z "$target_branch" ]]; then
        _forbut_warn "No branch selected."
        return 0
    fi

    # Step 3: Execute the assignment. Both payloads are opaque — no parsing.
    _forbut_info "Staging hunks ($hunk_ids) to branch: $target_branch"
    but stage "$hunk_ids" "$target_branch"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        _forbut_info "Done. Hunks assigned successfully."
    else
        _forbut_error "Failed to assign hunks (exit code: $exit_code)."
    fi

    return $exit_code
}

# ---------------------------------------------------------------------------
# Preview: show the diff for a single hunk payload (CLI ID)
# ---------------------------------------------------------------------------
_forbut_preview_assign_hunk() {
    local hunk_ref
    if [[ "$1" == *"$_FBSEP"* ]]; then
        hunk_ref="${1#*"$_FBSEP"}"
    else
        hunk_ref="$1"
    fi
    [[ -z "$hunk_ref" ]] && return

    local preview_pager
    preview_pager=$(_forbut_get_pager diff)

    local but_output
    but_output=$(_forbut_but diff --no-tui "$hunk_ref")
    if [[ -n "$but_output" ]]; then
        echo "$but_output" | eval "$preview_pager"
        return
    fi

    # Fallback for pure-git repos: treat payload as a file path.
    git diff --color=always -- "$hunk_ref" 2>/dev/null | eval "$preview_pager"
}
