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
#
# Function ordering mirrors forgit/cmds/log.sh:
#   _forbut_log_preview   →  preview helper (≈ _forgit_log_preview)
#   _forbut_log_enter     →  enter helper   (≈ _forgit_log_enter)
#   _forbut_git_log       →  git wrapper    (≈ _forgit_git_log)
#   _forbut_log           →  main entry     (≈ _forgit_log) — LAST

# ---------------------------------------------------------------------------
# Preview: show the commit diff
# ---------------------------------------------------------------------------
_forbut_log_commit_view() {
    local commit_id="$1"
    local show_output diff_output

    show_output=$(_forbut_but show "$commit_id" 2>/dev/null)
    diff_output=$(_forbut_but diff --no-tui "$commit_id" 2>/dev/null)

    if [[ -n $show_output ]] || [[ -n $diff_output ]]; then
        [[ -n $show_output ]] && printf '%s\n' "$show_output"
        if [[ -n $diff_output ]]; then
            printf '%s\n' "$diff_output" | _forbut_colorize_but_diff
        fi
        return 0
    fi

    git show --color=always "$commit_id" 2>/dev/null
}

_forbut_log_preview() {
    local commit_id
    commit_id=$(echo "$1" | _forbut_extract_payload) || return

    local preview_pager
    preview_pager=$(_forbut_get_pager show)

    local output
    output=$(_forbut_log_commit_view "$commit_id")
    if [[ -n $output ]]; then
        echo "$output" | eval "$preview_pager"
        return
    fi
}

# ---------------------------------------------------------------------------
# Enter: open full-screen interactive commit diff
# ---------------------------------------------------------------------------
_forbut_log_enter() {
    local commit_id
    commit_id=$(echo "$1" | _forbut_extract_payload) || return

    local enter_pager
    enter_pager=$(_forbut_get_pager enter)

    local output
    output=$(_forbut_log_commit_view "$commit_id")
    if [[ -n $output ]]; then
        echo "$output" | eval "$enter_pager"
        return
    fi
}

# ---------------------------------------------------------------------------
# List commits as _fbsep-delimited rows (≈ _forgit_git_log)
# ---------------------------------------------------------------------------
_forbut_git_log() {
    local graph log_format branch
    log_format=$1
    shift
    branch="${1:-}"
    shift
    graph=()
    [[ $_forbut_log_graph_enable == true ]] && graph=(--graph)
    _forbut_log_git_opts=()
    _forbut_parse_array _forbut_log_git_opts "--abbrev-commit --date=relative -200"
    local args=("${graph[@]}" --color=always --format="$log_format" "${_forbut_log_git_opts[@]}")
    if [[ -n $branch ]]; then
        git log "${args[@]}" "$branch" "$@" 2>/dev/null | _forbut_emojify
    else
        git log "${args[@]}" "$@" 2>/dev/null | _forbut_emojify
    fi
}

# ---------------------------------------------------------------------------
# git commit viewer (main entry — comes LAST, mirroring forgit)
# ---------------------------------------------------------------------------
_forbut_log() {
    local branch header preview_cmd quoted_files log_format
    local -a opts
    branch="${1:-}"
    quoted_files=$(_forbut_quote_files "$@")

    header="${FORBUT_COLOR_BOLD}Commit log${FORBUT_COLOR_RESET}  "
    header+="${FORBUT_COLOR_DIM}enter${FORBUT_COLOR_RESET}=show commit  "
    header+="${FORBUT_COLOR_DIM}ctrl-y${FORBUT_COLOR_RESET}=copy hash  "
    header+="${FORBUT_COLOR_DIM}ctrl-/${FORBUT_COLOR_RESET}=toggle preview"

    preview_cmd="$FORBUT preview log_preview {} $quoted_files"

    opts=(
        +s +m --tiebreak=index
        --delimiter="$_fbsep"
        --with-nth=1
        --accept-nth=2
        --header="$header"
        --preview="$preview_cmd"
        --bind="ctrl-y:execute-silent($FORBUT yank_sha {})"
        --bind="enter:execute($FORBUT enter log_enter {} $quoted_files)"
    )

    # fzf returns the clean short SHA (payload). Enter dispatches to
    # _forbut_log_enter; ctrl-y copies via the shared yank helper.
    log_format=${FORBUT_GLO_FORMAT:-$_forbut_log_format}
    _forbut_git_log "$log_format" "$branch" "$@" |
        _forbut_fzf FORBUT_LOG_FZF_OPTS "${opts[@]}"
    fzf_exit_code=$?
    # exit successfully on 130 (ctrl-c/esc)
    [[ $fzf_exit_code == 130 ]] && return 0
    return $fzf_exit_code
}
