#!/usr/bin/env bash
# cmds/switch.sh — forbut::switch
# Fuzzy-switch between virtual branches/stacks.
#
# Maps to: but apply <branch> / but unapply <branch>
# Forgit equivalent: forgit::checkout_branch

_forbut_cmd_switch() {
    local header
    header="${FORBUT_COLOR_BOLD}Switch branch${FORBUT_COLOR_RESET}  "
    header+="${FORBUT_COLOR_DIM}enter${FORBUT_COLOR_RESET}=apply  "
    header+="${FORBUT_COLOR_DIM}ctrl-x${FORBUT_COLOR_RESET}=unapply  "
    header+="${FORBUT_COLOR_DIM}ctrl-/${FORBUT_COLOR_RESET}=toggle preview"

    local preview_cmd="$FORBUT _preview switch_branch {1}"

    local selected
    selected=$(
        but branch list --all 2>/dev/null |
        _forbut_fzf \
            --header="$header" \
            --preview="$preview_cmd" \
            --bind="ctrl-x:execute-silent(but unapply {1} 2>/dev/null)+reload(but branch list --all 2>/dev/null)" \
            --bind="enter:accept" \
            ${FORBUT_SWITCH_FZF_OPTS:-}
    ) || return 0

    # Extract the branch short code (first field)
    local branch_id
    branch_id=$(echo "$selected" | awk '{print $1}')

    if [[ -z "$branch_id" ]]; then
        return 0
    fi

    # Apply the selected branch
    _forbut_info "Applying branch: $branch_id"
    but apply "$branch_id"
}

# ---------------------------------------------------------------------------
# Preview: show branch details (commits, PR info)
# ---------------------------------------------------------------------------
_forbut_preview_switch_branch() {
    local branch_id="$1"
    [[ -z "$branch_id" ]] && return

    # Show branch details with files
    but branch show "$branch_id" -f 2>/dev/null || \
        echo "No details available for '$branch_id'"
}
