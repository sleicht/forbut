#!/usr/bin/env bash
# cmds/show.sh — forbut commit/file viewer helpers

# ---------------------------------------------------------------------------
# Commit view: show a commit via but show + but diff, or fall back to git show
# ---------------------------------------------------------------------------
_forbut_show_commit_view() {
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

_forbut_show_commit_file_rows() {
    local commit_id="$1"
    shift

    git show --pretty='' --name-status --diff-merges=first-parent --color=always "$commit_id" -- "$@" 2>/dev/null |
        awk -v sep="$_fbsep" '
            BEGIN { OFS="" }
            NF >= 2 {
                status = $1
                path = $2
                if (NF > 2) {
                    display = "[" status "] " path "  ->  " $3
                    payload = path "\t" $3
                } else {
                    display = "[" status "] " path
                    payload = path
                }
                print display, sep, payload
            }
        '
}

_forbut_show_file_view() {
    local commit_id="$1"
    local file_payload="$2"

    if [[ $file_payload == *$'\t'* ]]; then
        local old_path new_path show_output
        old_path=${file_payload%%$'\t'*}
        new_path=${file_payload#*$'\t'}
        show_output=$(git show --color=always "$commit_id" -- "$old_path" "$new_path" 2>/dev/null)
        [[ -n $show_output ]] && printf '%s\n' "$show_output"
        return
    fi

    git show --color=always "$commit_id" -- "$file_payload" 2>/dev/null
}

_forbut_show_file_preview() {
    local file_payload="$1"
    local commit_id="$2"
    local preview_pager

    preview_pager=$(_forbut_get_pager show)
    _forbut_show_file_view "$commit_id" "$(echo "$file_payload" | _forbut_extract_payload)" | eval "$preview_pager"
}

_forbut_show_file_enter() {
    local file_payload="$1"
    local commit_id="$2"
    local enter_pager

    enter_pager=$(_forbut_get_pager enter)
    _forbut_show_file_view "$commit_id" "$(echo "$file_payload" | _forbut_extract_payload)" | eval "$enter_pager"
}

_forbut_show() {
    local commit_id="$1"
    shift

    local header preview_cmd escaped_commit
    local -a opts
    escaped_commit=${commit_id//\{/\\\{}

    header="${FORBUT_COLOR_BOLD}Commit files${FORBUT_COLOR_RESET}  "
    header+="${FORBUT_COLOR_DIM}enter${FORBUT_COLOR_RESET}=show file diff  "
    header+="${FORBUT_COLOR_DIM}ctrl-/${FORBUT_COLOR_RESET}=toggle preview"

    preview_cmd="$FORBUT preview show_file_preview {} $escaped_commit"

    opts=(
        +m -0 --tiebreak=index
        --delimiter="$_fbsep"
        --with-nth=1
        --accept-nth=2
        --header="$header"
        --preview="$preview_cmd"
        --bind="enter:execute($FORBUT enter show_file_enter {} $escaped_commit)"
    )

    _forbut_show_commit_file_rows "$commit_id" "$@" |
        _forbut_fzf FORBUT_SHOW_FZF_OPTS "${opts[@]}"
}