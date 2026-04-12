#!/usr/bin/env bash
# cmds/log.sh — forbut::log
# Browse commit log with diff preview.
#
# Row shape: <git log display with graph/colours>${_fbsep}<short sha>
# Produced in a single `git log --format=...%x1f%x1e%h` call — embedding
# the separator directly in the git format string avoids any shell
# post-processing. fzf returns only the short SHA via --accept-nth=2.
#
# Maps to: but log / but show <commit>
# Forgit equivalent: forgit::log

# Git log format — ported from forgit's default.
# %x1f%x1e encodes the _fbsep separator (US + RS) as native git format escapes.
_FORBUT_LOG_FORMAT='%C(auto)%h%d %s %C(black)%C(bold)%cr%Creset%x1f%x1e%h'

_forbut_log() {
    local branch="${1:-}"

    local header
    header="${FORBUT_COLOR_BOLD}Commit log${FORBUT_COLOR_RESET}  "
    header+="${FORBUT_COLOR_DIM}enter${FORBUT_COLOR_RESET}=show commit  "
    header+="${FORBUT_COLOR_DIM}ctrl-y${FORBUT_COLOR_RESET}=copy hash  "
    header+="${FORBUT_COLOR_DIM}ctrl-/${FORBUT_COLOR_RESET}=toggle preview"

    local preview_cmd="$FORBUT preview log_preview {}"

    # fzf returns the clean short SHA (payload). Enter dispatches to
    # _forbut_log_enter; ctrl-y copies via the shared yank helper.
    local sha
    sha=$(
        _forbut_log_list "$branch" |
            _forbut_fzf FORBUT_LOG_FZF_OPTS \
                --delimiter="$_fbsep" \
                --with-nth=1 \
                --accept-nth=2 \
                --header="$header" \
                --preview="$preview_cmd" \
                --bind="ctrl-y:execute-silent(printf %s {} | ${FORBUT_COPY_CMD:-pbcopy} 2>/dev/null)" \
                --bind="enter:execute($FORBUT enter log_enter {})" \
                --no-sort
    )
    # sha is discarded — the action already ran via the enter bind.
}

# ---------------------------------------------------------------------------
# List commits as _fbsep-delimited rows
# ---------------------------------------------------------------------------
_forbut_log_list() {
    local branch="${1:-}"
    local args=(--graph --color=always --format="$_FORBUT_LOG_FORMAT" --abbrev-commit --date=relative -200)
    if [[ -n $branch ]]; then
        git log "${args[@]}" "$branch" 2>/dev/null
    else
        git log "${args[@]}" 2>/dev/null
    fi
}

# ---------------------------------------------------------------------------
# Preview: show the commit diff
# ---------------------------------------------------------------------------
_forbut_log_preview() {
    # fzf {} gives the full original line; extract the payload (field 2 after _fbsep).
    local commit_id
    if [[ $1 == *"$_fbsep"* ]]; then
        commit_id="${1#*"$_fbsep"}"
    else
        commit_id="$1"
    fi
    [[ -z $commit_id ]] && return

    local preview_pager
    preview_pager=$(_forbut_get_pager show)

    # Try but show first (GitButler-aware), fall back to git show.
    # _forbut_but strips sync banners; colorize adds ANSI to box-drawing diffs.
    local output
    output=$(_forbut_but show "$commit_id" 2>/dev/null)
    if [[ -n $output ]]; then
        echo "$output" | _forbut_colorize_but_diff | eval "$preview_pager"
        return
    fi

    git show --color=always "$commit_id" 2>/dev/null | eval "$preview_pager"
}

# ---------------------------------------------------------------------------
# Enter: open full-screen interactive commit diff
# ---------------------------------------------------------------------------
_forbut_log_enter() {
    # fzf {} gives the full original line; extract the payload (field 2 after _fbsep).
    local commit_id
    if [[ $1 == *"$_fbsep"* ]]; then
        commit_id="${1#*"$_fbsep"}"
    else
        commit_id="$1"
    fi
    [[ -z $commit_id ]] && return

    local enter_pager
    enter_pager=$(_forbut_get_pager enter)

    # Same fallback chain as preview but with the interactive enter pager.
    local output
    output=$(_forbut_but show "$commit_id" 2>/dev/null)
    if [[ -n $output ]]; then
        echo "$output" | _forbut_colorize_but_diff | eval "$enter_pager"
        return
    fi

    git show --color=always "$commit_id" 2>/dev/null | eval "$enter_pager"
}
