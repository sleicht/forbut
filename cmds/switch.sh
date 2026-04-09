#!/usr/bin/env bash
# cmds/switch.sh — forbut::switch
# Fuzzy-switch between virtual branches/stacks.
#
# Maps to: but apply <branch> / but unapply <branch>
# Forgit equivalent: forgit::checkout_branch
#
# but branch list --all output format:
#   Applied Branches              <- section header (filtered out)
#   active  √ *feature/my-branch       today     Author..
#   local   × feature/other-branch  ↑2  3w ago    Author..
# Column 1: type (active/local/remote)
# Column 2: merge status (√/×)
# Column 3: branch name (* prefix = applied)

# Helper: filter but branch list output to data rows only (skip headers/blanks)
_forbut_branch_list() {
    but branch list --all 2>/dev/null | grep -E '^\s*(active|local|remote)\s'
}

_forbut_cmd_switch() {
    local header
    header="${FORBUT_COLOR_BOLD}Switch branch${FORBUT_COLOR_RESET}  "
    header+="${FORBUT_COLOR_DIM}enter${FORBUT_COLOR_RESET}=apply  "
    header+="${FORBUT_COLOR_DIM}ctrl-x${FORBUT_COLOR_RESET}=unapply  "
    header+="${FORBUT_COLOR_DIM}ctrl-/${FORBUT_COLOR_RESET}=toggle preview"

    # {3} = branch name column; may have * prefix for applied branches
    local preview_cmd="$FORBUT _preview switch_branch {3}"

    local selected
    selected=$(
        _forbut_branch_list |
        _forbut_fzf FORBUT_SWITCH_FZF_OPTS \
            --header="$header" \
            --preview="$preview_cmd" \
            --bind="ctrl-x:execute-silent(name={3}; but unapply \${name#\\*} 2>/dev/null)+reload($FORBUT _preview switch_reload)" \
            --bind="enter:accept"
    ) || return 0

    # Extract the branch name (column 3), strip leading * if present
    local branch_name
    branch_name=$(echo "$selected" | awk '{print $3}' | sed 's/^\*//')

    if [[ -z "$branch_name" ]]; then
        return 0
    fi

    # Apply the selected branch
    _forbut_info "Applying branch: $branch_name"
    but apply "$branch_name"
}

# ---------------------------------------------------------------------------
# Preview: show branch details (commits, PR info)
# ---------------------------------------------------------------------------
_forbut_preview_switch_branch() {
    local branch_id="$1"
    # Strip leading * from applied branches
    branch_id="${branch_id#\*}"
    [[ -z "$branch_id" ]] && return

    # Show branch details with files
    but branch show "$branch_id" -f 2>/dev/null || \
        echo "No details available for '$branch_id'"
}

# Reload helper for ctrl-x bind (re-filter after unapply)
_forbut_preview_switch_reload() {
    _forbut_branch_list
}
