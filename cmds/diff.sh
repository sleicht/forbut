#!/usr/bin/env bash
# cmds/diff.sh — forbut::diff
# Browse changed files with inline diff preview.
#
# JSON-first: `but status -f -j` → jq → _fbsep-delimited rows.
# Fallback: pure-git porcelain for non-GitButler repos.
#
# Row shape: <coloured display>${_fbsep}<cli_id-or-path>
#   display  — shown in fzf (status, file path, location tag)
#   payload  — returned by fzf via --accept-nth=2. Either a but CLI ID
#              (e.g. "ur", "ae", "sv:ae") or a git file path.
#
# Maps to: but diff <target>
# Forgit equivalent: forgit::diff

_forbut_diff() {
    local target="${1:-}"

    local header
    header="${FORBUT_COLOR_BOLD}Changed files${FORBUT_COLOR_RESET}  "
    header+="${FORBUT_COLOR_DIM}enter${FORBUT_COLOR_RESET}=full diff  "
    header+="${FORBUT_COLOR_DIM}ctrl-/${FORBUT_COLOR_RESET}=toggle preview"

    local pager
    pager=$(_forbut_get_pager diff)

    local preview_cmd="$FORBUT preview diff_preview {}"

    # fzf returns only the payload (field 2), so enter-bind runs against {}.
    # Use but diff first, fall back to git diff if the payload is a file path.
    local selected
    selected=$(
        _forbut_diff_file_list "$target" |
        _forbut_fzf FORBUT_DIFF_FZF_OPTS \
            --delimiter="$_fbsep" \
            --with-nth=1 \
            --accept-nth=2 \
            --header="$header" \
            --preview="$preview_cmd" \
            --bind="enter:execute($FORBUT enter diff_enter {})" \
            --no-sort
    )
    # selected holds the clean payload; discarded on empty/cancel.
}

# ---------------------------------------------------------------------------
# Unified list helper — emits _fbsep rows from either JSON or git
# ---------------------------------------------------------------------------
_forbut_diff_file_list() {
    local target="${1:-}"

    # Target mode: show the file list for a specific diff target (commit/stack).
    if [[ -n "$target" ]]; then
        _forbut_diff_target_file_list "$target"
        return
    fi

    # Try but status -f -j (JSON) first.
    local json
    json=$(_forbut_but status -f -j)
    if [[ -n "$json" ]] && echo "$json" | jq -e '.stacks // .unassignedChanges' >/dev/null 2>&1; then
        # Assert the fields we depend on. Schema drift tripwire.
        if ! _forbut_schema_assert "$json" '.unassignedChanges // [] | type == "array"' 'diff'; then
            return 1
        fi
        _forbut_diff_rows_from_json "$json"
        return
    fi

    # Non-GitButler fallback: porcelain with _fbsep already embedded.
    _forbut_worktree_changes
}

# Build _fbsep-delimited rows for a specific but diff target.
_forbut_diff_target_file_list() {
    local target="$1"
    local json
    json=$(_forbut_but diff "$target" -j)
    if [[ -n "$json" ]] && echo "$json" | jq -e '.changes // empty' >/dev/null 2>&1; then
        if ! _forbut_schema_assert "$json" '.changes | type == "array"' 'diff-target'; then
            return 1
        fi
        echo "$json" | jq -r --arg sep "$_fbsep" '
            .changes // [] | .[] |
            (.status // "modified") as $s |
            (if   $s == "modified" then "\u001b[33m[M]\u001b[0m"
             elif $s == "added"    then "\u001b[32m[A]\u001b[0m"
             elif $s == "removed"  then "\u001b[31m[D]\u001b[0m"
             elif $s == "renamed"  then "\u001b[35m[R]\u001b[0m"
             else "[?]" end) as $marker |
            "\($marker)  \(.path // .filePath // "unknown")\($sep)\(.id // .cliId // .path)"
        ' 2>/dev/null
        return
    fi

    # Non-JSON fallback: raw diff text.
    _forbut_but diff --no-tui "$target"
}

# Emit rows for unassigned + staged + committed changes from but status JSON.
# Note on jq scoping: `.[] as $x` binds $x but does NOT change `.` — we must
# reference `$x.<field>` explicitly when descending into a bound value.
# Real but status JSON shape (verified via fixture):
#   .stacks[].cliId
#   .stacks[].assignedChanges[].{cliId, filePath, changeType}
#   .stacks[].branches[].name          (stack name lives on branches[0].name)
#   .stacks[].branches[].commits[].{cliId, commitId, message, changes[]}
#   .stacks[].branches[].commits[].changes[].{cliId, filePath, changeType}
_forbut_diff_rows_from_json() {
    local json="$1"
    echo "$json" | jq -r --arg sep "$_fbsep" '
        def marker:
            if   . == "modified" then "\u001b[33m[M]\u001b[0m"
            elif . == "added"    then "\u001b[32m[A]\u001b[0m"
            elif . == "removed"  then "\u001b[31m[D]\u001b[0m"
            elif . == "renamed"  then "\u001b[35m[R]\u001b[0m"
            else "\u001b[2m[?]\u001b[0m" end;

        def row($loc):
            "\(.changeType | marker)  \(.filePath)  \u001b[2m(\($loc))\u001b[0m\($sep)\(.cliId)";

        # Unassigned (worktree) changes
        (.unassignedChanges // [] | .[] | row("unassigned")),

        # Assigned (staged-to-stack) changes — stack name comes from its
        # first branch head.
        (.stacks // [] | .[] |
            . as $stack |
            ($stack.branches // [] | .[0].name // $stack.cliId // "stack") as $stackname |
            $stack.assignedChanges // [] | .[] |
            row("staged → \($stackname)")),

        # Committed changes — descend stacks → branches → commits → changes,
        # binding $commit so its message is still reachable once we iterate
        # the innermost changes array.
        (.stacks // [] | .[] |
            .branches // [] | .[] |
            .commits // [] | .[] |
            . as $commit |
            $commit.changes // [] | .[] |
            row("commit: \($commit.message // "commit" | .[0:40])"))
    ' 2>/dev/null
}

# ---------------------------------------------------------------------------
# Preview: render the diff for a payload (CLI ID or file path)
# ---------------------------------------------------------------------------
_forbut_diff_preview() {
    # fzf {} gives the full original line; extract the payload (field 2 after _fbsep).
    local ref
    if [[ "$1" == *"$_fbsep"* ]]; then
        ref="${1#*"$_fbsep"}"
    else
        ref="$1"
    fi
    [[ -z "$ref" ]] && return

    local preview_pager
    preview_pager=$(_forbut_get_pager diff)

    # Resolve file path via but diff -j for coloured git diff.
    # Note: but diff -j embeds literal newlines in JSON strings (jq rejects it),
    # so use grep/sed to extract the path from the first "path": line.
    local filepath output
    filepath=$(_forbut_but diff "$ref" -j | grep -m1 '"path":' | sed 's/.*"path":[[:space:]]*"\([^"]*\)".*/\1/')

    # 1. Coloured git diff — best for worktree (unassigned) changes.
    if [[ -n "$filepath" ]]; then
        output=$(git diff --color=always -- "$filepath" 2>/dev/null)
        [[ -z "$output" ]] && output=$(git diff --cached --color=always -- "$filepath" 2>/dev/null)
        if [[ -n "$output" ]]; then
            echo "$output" | eval "$preview_pager"
            return
        fi
    fi

    # 2. but diff --no-tui — works for committed changes; add ANSI colour.
    output=$(_forbut_but diff --no-tui "$ref")
    if [[ -n "$output" ]]; then
        echo "$output" | _forbut_colorize_but_diff | eval "$preview_pager"
        return
    fi

    # 3. Last resort: plain git diff with ref as path (non-GitButler repos).
    git diff --color=always -- "$ref" 2>/dev/null | eval "$preview_pager"
}

# ---------------------------------------------------------------------------
# Enter: open full-screen interactive diff (TUI) for the selected item
# ---------------------------------------------------------------------------
_forbut_diff_enter() {
    # fzf {} gives the full original line; extract the payload (field 2 after _fbsep).
    local ref
    if [[ "$1" == *"$_fbsep"* ]]; then
        ref="${1#*"$_fbsep"}"
    else
        ref="$1"
    fi
    [[ -z "$ref" ]] && return

    local enter_pager
    enter_pager=$(_forbut_get_pager enter)

    # Same fallback chain as preview but with the interactive enter pager.
    local filepath output
    filepath=$(_forbut_but diff "$ref" -j | grep -m1 '"path":' | sed 's/.*"path":[[:space:]]*"\([^"]*\)".*/\1/')

    if [[ -n "$filepath" ]]; then
        output=$(git diff --color=always -- "$filepath" 2>/dev/null)
        [[ -z "$output" ]] && output=$(git diff --cached --color=always -- "$filepath" 2>/dev/null)
        if [[ -n "$output" ]]; then
            echo "$output" | eval "$enter_pager"
            return
        fi
    fi

    output=$(_forbut_but diff --no-tui "$ref")
    if [[ -n "$output" ]]; then
        echo "$output" | _forbut_colorize_but_diff | eval "$enter_pager"
        return
    fi

    git diff --color=always -- "$ref" 2>/dev/null | eval "$enter_pager"
}
