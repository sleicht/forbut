#!/usr/bin/env bash
# cmds/discard.sh — forbut::discard
# Fuzzy-select hunks/files to discard (remove changes).
#
# Uses `but status -j` (JSON) to get unassigned changes with CLI IDs,
# then `but diff <cli_id>` for previews, and `but discard` to remove.
#
# Maps to: but discard <target>
# Forgit equivalent: forgit::clean

_forbut_cmd_discard() {
    local header
    header="${FORBUT_COLOR_BOLD}Discard changes${FORBUT_COLOR_RESET}  "
    header+="${FORBUT_COLOR_RED}WARNING: this is destructive!${FORBUT_COLOR_RESET}  "
    header+="${FORBUT_COLOR_DIM}tab${FORBUT_COLOR_RESET}=select  "
    header+="${FORBUT_COLOR_DIM}enter${FORBUT_COLOR_RESET}=discard selected  "
    header+="${FORBUT_COLOR_DIM}ctrl-/${FORBUT_COLOR_RESET}=toggle preview"

    local preview_cmd="$FORBUT _preview discard_item {1}"

    # Show uncommitted/unassigned changes for selection
    local selected
    selected=$(
        _forbut_unassigned_file_list |
        _forbut_fzf FORBUT_DISCARD_FZF_OPTS \
            --header="$header" \
            --preview="$preview_cmd" \
            --multi \
            --bind="ctrl-a:select-all" \
            --color="header:red:italic"
    ) || return 0

    if [[ -z "$selected" ]]; then
        return 0
    fi

    # Extract CLI IDs from selection (first field)
    local ids
    ids=$(echo "$selected" | awk '{print $1}' | paste -sd ',' -)

    if [[ -z "$ids" ]]; then
        _forbut_warn "No items selected."
        return 0
    fi

    # Confirmation prompt (destructive operation)
    if [[ -z "${FORBUT_DISCARD_NO_CONFIRM:-}" ]]; then
        local count
        count=$(echo "$selected" | wc -l | tr -d ' ')
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

    # Execute discard
    _forbut_info "Discarding: $ids"
    but discard "$ids"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        _forbut_info "Changes discarded."
    else
        _forbut_error "Failed to discard (exit code: $exit_code)."
    fi

    return $exit_code
}

# ---------------------------------------------------------------------------
# Preview: show what would be discarded
# ---------------------------------------------------------------------------
_forbut_preview_discard_item() {
    local item_ref="$1"
    [[ -z "$item_ref" ]] && return

    local preview_pager
    preview_pager=$(_forbut_preview_pager)

    # Use but diff with CLI ID for preview
    local but_output
    but_output=$(but diff "$item_ref" 2>/dev/null)
    if [[ -n "$but_output" ]]; then
        echo "$but_output" | eval "$preview_pager"
        return
    fi

    # Fallback to git diff
    git diff --color=always -- "$item_ref" 2>/dev/null | eval "$preview_pager"
}
