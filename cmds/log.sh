#!/usr/bin/env bash
# cmds/log.sh — forbut::log
# Browse commit log across current stack with diff preview.
#
# Maps to: but branch show <branch> / but show <commit>
# Forgit equivalent: forgit::log

_forbut_cmd_log() {
    local branch="${1:-}"

    local header
    header="${FORBUT_COLOR_BOLD}Commit log${FORBUT_COLOR_RESET}  "
    header+="${FORBUT_COLOR_DIM}enter${FORBUT_COLOR_RESET}=show full diff  "
    header+="${FORBUT_COLOR_DIM}ctrl-y${FORBUT_COLOR_RESET}=copy hash  "
    header+="${FORBUT_COLOR_DIM}ctrl-/${FORBUT_COLOR_RESET}=toggle preview"

    local pager
    pager=$(_forbut_pager)

    local preview_cmd="$FORBUT _preview log_commit {1}"

    # Get the list of commits.
    # If a branch is specified, show that branch's commits.
    # Otherwise, use git log for the current branch.
    local log_source
    if [[ -n "$branch" ]]; then
        log_source="but branch show $branch -f 2>/dev/null"
    else
        log_source="git log --oneline --color=always --decorate -50"
    fi

    local selected
    selected=$(
        eval "$log_source" |
        _forbut_fzf \
            --header="$header" \
            --preview="$preview_cmd" \
            --bind="ctrl-y:execute-silent(echo {1} | tr -d '[:space:]' | pbcopy 2>/dev/null || echo {1} | xclip -selection clipboard 2>/dev/null)" \
            --bind="enter:execute(but show {1} 2>/dev/null | $pager || git show --color=always {1} | $pager)" \
            --no-sort \
            ${FORBUT_LOG_FZF_OPTS:-}
    ) || return 0
}

# ---------------------------------------------------------------------------
# Preview: show commit diff
# ---------------------------------------------------------------------------
_forbut_preview_log_commit() {
    local commit_id="$1"
    [[ -z "$commit_id" ]] && return

    local preview_pager
    preview_pager=$(_forbut_preview_pager)

    # Try but show first, fall back to git show
    (but show "$commit_id" 2>/dev/null || git show --color=always --stat "$commit_id" 2>/dev/null) | \
        eval "$preview_pager"
}
