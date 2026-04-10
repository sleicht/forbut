#!/usr/bin/env bash
# cmds/discard.sh — forbut::discard
# Fuzzy-select hunks/files to discard (destructive).
#
# Uses the shared _forbut_unassigned_list helper so discard + assign +
# diff all see the same changes through the same JSON-first contract.
# Payloads are CLI IDs (in a GitButler project) or file paths (pure git).
#
# Maps to: but hunk discard <target>  /  git checkout -- <file>
# Forgit equivalent: forgit::clean + forgit::checkout::file

_forbut_cmd_discard() {
    local header
    header="${FORBUT_COLOR_BOLD}Discard changes${FORBUT_COLOR_RESET}  "
    header+="${FORBUT_COLOR_RED}WARNING: this is destructive!${FORBUT_COLOR_RESET}  "
    header+="${FORBUT_COLOR_DIM}tab${FORBUT_COLOR_RESET}=select  "
    header+="${FORBUT_COLOR_DIM}enter${FORBUT_COLOR_RESET}=discard selected  "
    header+="${FORBUT_COLOR_DIM}ctrl-/${FORBUT_COLOR_RESET}=toggle preview"

    local preview_cmd="$FORBUT _preview discard_item {}"

    local selected_ids
    selected_ids=$(
        _forbut_unassigned_list |
        _forbut_fzf FORBUT_DISCARD_FZF_OPTS \
            --delimiter="$_FBSEP" \
            --with-nth=1 \
            --accept-nth=2 \
            --header="$header" \
            --preview="$preview_cmd" \
            --multi \
            --bind="ctrl-a:select-all" \
            --color="header:red:italic"
    )

    if [[ -z "$selected_ids" ]]; then
        return 0
    fi

    # fzf --multi returns one payload per line; join for `but hunk discard`.
    local ids
    ids=$(echo "$selected_ids" | paste -sd ',' -)

    if [[ -z "$ids" ]]; then
        _forbut_warn "No items selected."
        return 0
    fi

    # Destructive operation — confirmation unless explicitly suppressed.
    if [[ -z "${FORBUT_DISCARD_NO_CONFIRM:-}" ]]; then
        local count
        count=$(echo "$selected_ids" | wc -l | tr -d ' ')
        printf '%sDiscard %s item(s)? This cannot be undone. [y/N]:%s ' \
            "$FORBUT_COLOR_RED" "$count" "$FORBUT_COLOR_RESET" >&2
        local confirm
        read -r confirm
        case "$confirm" in
            [yY]|[yY][eE][sS]) ;;
            *)
                _forbut_info "Cancelled."
                return 0
                ;;
        esac
    fi

    _forbut_info "Discarding: $ids"
    # Prefer but hunk discard (GitButler) with fallback to git checkout.
    if but hunk discard "$ids" 2>/dev/null; then
        _forbut_info "Changes discarded."
        return 0
    fi

    # Pure-git fallback: treat payloads as file paths.
    local rc=0
    local file
    echo "$selected_ids" | while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        git checkout -- "$file" 2>/dev/null || rc=1
    done
    if [[ $rc -eq 0 ]]; then
        _forbut_info "Changes discarded."
    else
        _forbut_error "Failed to discard one or more items."
    fi
    return $rc
}

# ---------------------------------------------------------------------------
# Preview: show what would be discarded (CLI ID or file path)
# ---------------------------------------------------------------------------
_forbut_preview_discard_item() {
    local item_ref="$1"
    [[ -z "$item_ref" ]] && return

    local preview_pager
    preview_pager=$(_forbut_get_pager diff)

    local but_output
    but_output=$(but diff "$item_ref" 2>/dev/null)
    if [[ -n "$but_output" ]]; then
        echo "$but_output" | eval "$preview_pager"
        return
    fi

    git diff --color=always -- "$item_ref" 2>/dev/null | eval "$preview_pager"
}
