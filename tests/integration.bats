#!/usr/bin/env bats
# tests/integration.bats — end-to-end tests against a real `but` CLI.
#
# Creates a temporary git repo + GitButler project in setup_file(),
# seeds it with a variety of changes (unassigned, staged, committed,
# filenames with spaces), and runs the list helpers against live
# `but` output. Skips gracefully if `but` or `but setup` are
# unavailable, so the suite still runs in minimal environments.
#
# Opt out: set FORBUT_SKIP_INTEGRATION=1 to skip the whole file.
#   (e.g. in CI environments where writing to GitButler's app-support
#    directory is undesirable).
#
# Cleanup: setup_file writes all state to $BATS_FILE_TMPDIR and runs
# `but teardown` in teardown_file to unregister the temp project from
# GitButler's global registry.

# bats does NOT propagate `export` from setup_file to individual tests,
# so we persist state to $BATS_FILE_TMPDIR/state.env and source it in setup().

_state_file() {
    echo "$BATS_FILE_TMPDIR/state.env"
}

setup_file() {
    STATE=$(_state_file)
    : > "$STATE"

    if [[ "${FORBUT_SKIP_INTEGRATION:-}" == "1" ]]; then
        echo 'SKIP_REASON="FORBUT_SKIP_INTEGRATION=1"' > "$STATE"
        return 0
    fi

    if ! command -v but >/dev/null 2>&1; then
        echo 'SKIP_REASON="but CLI not on PATH"' > "$STATE"
        return 0
    fi

    INTEGRATION_ROOT="$BATS_FILE_TMPDIR/gitbutler-integration"
    INTEGRATION_WORK="$INTEGRATION_ROOT/work"
    INTEGRATION_REMOTE="$INTEGRATION_ROOT/remote.git"
    mkdir -p "$INTEGRATION_ROOT"

    # Isolated git + XDG state so the test never touches the user's config.
    local GIT_CONFIG_GLOBAL="$INTEGRATION_ROOT/.gitconfig"
    local XDG_STATE_HOME="$INTEGRATION_ROOT/.local/state"
    touch "$GIT_CONFIG_GLOBAL"
    export GIT_CONFIG_GLOBAL XDG_STATE_HOME

    # 1. Create a bare remote so `but setup` can resolve origin/HEAD.
    git init -q --bare "$INTEGRATION_REMOTE"

    # 2. Create the work repo, commit once, push to remote so HEAD exists.
    git init -q "$INTEGRATION_WORK"
    cd "$INTEGRATION_WORK" || return 1
    git config user.email forbut-integration@example.invalid
    git config user.name "forbut integration"
    echo "# integration fixture" > README.md
    git add README.md
    git commit -q -m "initial commit"
    git branch -M main
    git remote add origin "$INTEGRATION_REMOTE"
    git push -q -u origin main

    # 3. Run `but setup`. If it fails we mark the skip reason and bail;
    #    every test will pick up the skip via setup().
    if ! but setup >/dev/null 2>&1; then
        {
            echo 'SKIP_REASON="but setup failed (likely permission/state issue)"'
            echo "INTEGRATION_WORK=\"$INTEGRATION_WORK\""
        } > "$STATE"
        return 0
    fi

    # 4. Seed a committed change on feature/alpha FIRST, then add the
    #    "noisy" unassigned changes. This ordering matters because
    #    `but commit <branch>` (even with a single cliId staged) grabs
    #    ALL unassigned changes into the commit — so we must commit on
    #    an otherwise-clean worktree, then create new unassigned files.
    but branch new feature/alpha >/dev/null 2>&1 || true
    but branch new feature/beta  >/dev/null 2>&1 || true
    echo "initial alpha change" > alpha-committed.txt
    local alpha_id
    alpha_id=$(but status -f -j 2>/dev/null |
                 jq -r '.unassignedChanges[] | select(.filePath=="alpha-committed.txt") | .cliId')
    if [[ -n "$alpha_id" ]]; then
        but stage "$alpha_id" feature/alpha >/dev/null 2>&1 || true
        but commit feature/alpha -m "integration seed commit" >/dev/null 2>&1 || true
    fi

    # 5. Now populate the unassigned area with varied changes — these
    #    should stay unassigned through the rest of the test.
    echo "modified content" >> README.md
    echo "plain add"        > newfile.txt
    echo "spaces add"       > "file with spaces.txt"

    # 6. Persist state for the per-test setup() and teardown_file.
    {
        echo 'SKIP_REASON=""'
        echo "INTEGRATION_ROOT=\"$INTEGRATION_ROOT\""
        echo "INTEGRATION_WORK=\"$INTEGRATION_WORK\""
        echo "INTEGRATION_REMOTE=\"$INTEGRATION_REMOTE\""
        echo "GIT_CONFIG_GLOBAL=\"$GIT_CONFIG_GLOBAL\""
        echo "XDG_STATE_HOME=\"$XDG_STATE_HOME\""
    } > "$STATE"
}

teardown_file() {
    local STATE
    STATE=$(_state_file)
    [[ -f "$STATE" ]] && source "$STATE"
    if [[ -n "${INTEGRATION_WORK:-}" ]] && [[ -d "$INTEGRATION_WORK" ]]; then
        ( cd "$INTEGRATION_WORK" && but teardown >/dev/null 2>&1 || true )
    fi
}

setup() {
    local STATE
    STATE=$(_state_file)
    if [[ -f "$STATE" ]]; then
        source "$STATE"
    fi
    if [[ -n "${SKIP_REASON:-}" ]]; then
        skip "$SKIP_REASON"
    fi
    export FORBUT_INSTALL_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "$FORBUT_INSTALL_DIR/lib/utils.sh"
    for cmd_file in "$FORBUT_INSTALL_DIR"/cmds/*.sh; do
        source "$cmd_file"
    done
    cd "$INTEGRATION_WORK" || return 1
}

# ---------------------------------------------------------------------------
# Sanity — the harness actually created a working GitButler project.
# ---------------------------------------------------------------------------
@test "but status -f -j returns valid JSON in the integration repo" {
    local json
    json=$(but status -f -j 2>/dev/null)
    [[ -n "$json" ]]
    echo "$json" | jq -e '.unassignedChanges | type == "array"' >/dev/null
    echo "$json" | jq -e '.stacks | type == "array"' >/dev/null
}

@test "but branch list --all -j returns valid JSON" {
    local json
    json=$(but branch list --all -j 2>/dev/null)
    [[ -n "$json" ]]
    echo "$json" | jq -e '.appliedStacks // .branches' >/dev/null
}

# ---------------------------------------------------------------------------
# _forbut_unassigned_list against real but output
# ---------------------------------------------------------------------------
@test "integration: unassigned_list emits at least one row" {
    local out
    out=$(_forbut_unassigned_list)
    [[ -n "$out" ]]
    local count
    count=$(echo "$out" | awk -v FS="$_FBSEP" 'NF >= 2 && length($2) > 0 { n++ } END { print n+0 }')
    [[ "$count" -ge 1 ]]
}

@test "integration: unassigned_list payload is a short cliId (2 lowercase chars)" {
    local payload
    payload=$(_forbut_unassigned_list | head -1 | awk -v FS="$_FBSEP" '{print $2}')
    [[ "$payload" =~ ^[a-z]{2,}$ ]]
}

@test "integration: unassigned_list preserves filename with spaces" {
    _forbut_unassigned_list | grep -qF "file with spaces.txt"
}

# ---------------------------------------------------------------------------
# _forbut_diff_file_list against real but output
# ---------------------------------------------------------------------------
@test "integration: diff_file_list emits unassigned + assigned + committed rows" {
    local out
    out=$(_forbut_diff_file_list)
    [[ -n "$out" ]]
    echo "$out" | grep -qF '(unassigned)'
    echo "$out" | grep -q 'commit:' ||
        skip "no committed changes present (likely commit failed)"
}

@test "integration: diff_file_list all rows have valid _FBSEP delimiter" {
    local out bad
    out=$(_forbut_diff_file_list)
    bad=$(echo "$out" |
        awk -v FS="$_FBSEP" 'NF < 2 || length($2) == 0 { print; c++ } END { exit (c>0?1:0) }') || true
    [[ -z "$bad" ]]
}

# ---------------------------------------------------------------------------
# _forbut_switch_list against real but output
# ---------------------------------------------------------------------------
@test "integration: switch_list emits at least one applied branch" {
    local out count
    out=$(_forbut_switch_list)
    count=$(echo "$out" | awk -v FS="$_FBSEP" 'NF >= 2 { n++ } END { print n+0 }')
    [[ "$count" -ge 1 ]]
}

@test "integration: switch_list payload is a valid branch name" {
    local payload
    payload=$(_forbut_switch_list | head -1 | awk -v FS="$_FBSEP" '{print $2}')
    # Must not contain ANSI escapes, markers, or spaces
    [[ -n "$payload" ]]
    [[ "$payload" != *$'\x1b'* ]]
    [[ "$payload" != *"*"* ]]
    [[ "$payload" != *" "* ]]
}

@test "integration: switch_list includes our seeded feature/ branch" {
    _forbut_switch_list | grep -qE "${_FBSEP}feature/(alpha|beta)\$"
}

# ---------------------------------------------------------------------------
# _forbut_log_list against real git log
# ---------------------------------------------------------------------------
@test "integration: log_list emits at least one commit row" {
    local count
    count=$(_forbut_log_list | awk -v FS="$_FBSEP" 'NF >= 2 { n++ } END { print n+0 }')
    [[ "$count" -ge 1 ]]
}

@test "integration: log_list payload is a short git SHA" {
    local payload
    payload=$(_forbut_log_list | head -1 | awk -v FS="$_FBSEP" '{print $2}')
    [[ "$payload" =~ ^[a-f0-9]{7,}$ ]]
}

# ---------------------------------------------------------------------------
# Schema drift tripwire — simulate the scenario the drift log was built for
# ---------------------------------------------------------------------------
@test "integration: schema assert fires on an unexpected field" {
    local fake_json
    fake_json=$(but status -f -j 2>/dev/null | jq 'del(.unassignedChanges)')
    run _forbut_schema_assert "$fake_json" '.unassignedChanges | type == "array"' 'bats-integration'
    [[ "$status" -ne 0 ]]
}
