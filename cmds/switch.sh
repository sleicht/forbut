#!/usr/bin/env bash
# cmds/switch.sh — forbut::switch
# Fuzzy-switch between virtual branches/stacks.
#
# Maps to: but apply <branch> / but unapply <branch>
# Forgit equivalent: forgit::switch_branch (in forgit/cmds/checkout.sh)
#
# Data contract (JSON-first):
#   1. Try `but branch list --all -j` → jq emits delimited rows.
#   2. If `but` doesn't support -j on this subcommand, fall back to text parse.
#   3. If not in a GitButler project, fall back to plain `git branch`.
#
# Row shape: <display>${_fbsep}<branch-name>
#   display  — what fzf shows (ANSI colours, * markers, status, remote, upstream)
#   payload  — clean branch name used by `but apply`, never parsed from display.
#
# Function ordering mirrors forgit/cmds/checkout.sh::switch_branch group:
#   _forbut_branch_preview  →  preview helper (≈ _forgit_branch_preview)
#   _forbut_switch_reload   →  reload helper for ctrl-x bind (forbut-specific)
#   _forbut_branch_list     →  branch lister (≈ _forgit_branch_list + git switch wrapper)
#   _forbut_switch          →  main entry    (≈ _forgit_switch_branch) — LAST

# ---------------------------------------------------------------------------
# Preview: show branch details
# ---------------------------------------------------------------------------
_forbut_branch_preview() {
    local branch
    branch=$(echo "$1" | _forbut_extract_payload) || return
    [[ -z $branch ]] && return

    but branch show "$branch" -f 2>/dev/null || {
        # Non-GitButler fallback: show git log for the branch
        git log --color=always --oneline -20 "$branch" -- 2>/dev/null ||
            echo "No details available for '$branch'"
    }
}

# ---------------------------------------------------------------------------
# Reload helper for ctrl-x bind (re-fetch list after unapply)
# ---------------------------------------------------------------------------
_forbut_switch_reload() {
    _forbut_branch_list
}

# ---------------------------------------------------------------------------
# List branches as _fbsep-delimited rows
# (≈ _forgit_branch_list, but emits the display/payload pair forbut needs)
# ---------------------------------------------------------------------------
_forbut_branch_list() {
    local json
    json=$(but branch list --all -j 2>/dev/null)

    # Path 1: valid JSON from `but` — build rows with jq.
    # Real schema (verified against but 0.x):
    #   { "appliedStacks": [{"heads": [{"name", "lastCommitAt", ...}]}],
    #     "branches":      [{"name", ...}] }  # unapplied
    if [[ -n $json ]] && echo "$json" | jq -e '(.appliedStacks // .branches) != null' >/dev/null 2>&1; then
        # Assert the fields we actually read from. Drift on either path
        # (applied or unapplied) trips the schema log.
        if ! _forbut_schema_assert "$json" '.appliedStacks | type == "array"' 'switch.appliedStacks'; then
            return 1
        fi
        if ! _forbut_schema_assert "$json" '.branches | type == "array"' 'switch.branches'; then
            return 1
        fi
        echo "$json" | jq -r --arg sep "$_fbsep" '
            # Applied stacks: each stack has one or more heads (branches).
            (.appliedStacks // [] | .[] | .heads // [] | .[] |
                "\u001b[32m●\u001b[0m [applied] \(.name)\($sep)\(.name)"
            ),
            # Unapplied branches: flat list.
            (.branches // [] | .[] |
                "  [local]   \(.name // .identity // "unknown")\($sep)\(.name // .identity // "unknown")"
            )
        ' 2>/dev/null && return 0
    fi

    # Path 2: `but branch list` text output (current stable path)
    local text
    text=$(but branch list --all 2>/dev/null)
    if [[ -n $text ]]; then
        echo "$text" | grep -E '^\s*(active|local|remote)\s' | while IFS= read -r line; do
            # Extract the branch name robustly: strip ANSI, drop leading marker,
            # pull the 3rd whitespace field, strip any '*' prefix.
            # NOTE: init locals to empty — bare `local name` in zsh prints
            # `name=<prior-value>` on subsequent iterations (typeset introspection).
            local clean="" name=""
            clean=$(echo "$line" | _forbut_strip_ansi)
            name=$(echo "$clean" | awk '{print $3}' | sed 's/^\*//')
            [[ -z $name ]] && continue
            printf '%s%s%s\n' "$line" "$_fbsep" "$name"
        done
        return 0
    fi

    # Path 3: non-GitButler repo — pure git fallback
    _forbut_git_branch_list | while IFS= read -r line; do
        local name=""
        name=$(echo "$line" | _forbut_extract_branch_name)
        [[ -z $name ]] && continue
        printf '%s%s%s\n' "$line" "$_fbsep" "$name"
    done
}

# ---------------------------------------------------------------------------
# git switch-branch selector (main entry — comes LAST, mirroring forgit)
# ---------------------------------------------------------------------------
_forbut_switch() {
    local header
    header="${FORBUT_COLOR_BOLD}Switch branch${FORBUT_COLOR_RESET}  "
    header+="${FORBUT_COLOR_DIM}enter${FORBUT_COLOR_RESET}=apply  "
    header+="${FORBUT_COLOR_DIM}ctrl-x${FORBUT_COLOR_RESET}=unapply  "
    header+="${FORBUT_COLOR_DIM}ctrl-/${FORBUT_COLOR_RESET}=toggle preview"

    local preview_cmd="$FORBUT preview branch_preview {}"

    local branch_name
    branch_name=$(
        _forbut_branch_list |
            _forbut_fzf FORBUT_SWITCH_FZF_OPTS \
                --delimiter="$_fbsep" \
                --with-nth=1 \
                --accept-nth=2 \
                --header="$header" \
                --preview="$preview_cmd" \
                --bind="ctrl-x:execute-silent(but unapply {} 2>/dev/null)+reload($FORBUT preview switch_reload)" \
                --bind="enter:accept"
    )

    # fzf with --accept-nth=2 returns only the payload — clean, no awk.
    if [[ -z $branch_name ]]; then
        return 0
    fi

    _forbut_info "Applying branch: $branch_name"
    but apply "$branch_name"
}
