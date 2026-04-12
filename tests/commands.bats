#!/usr/bin/env bats
# tests/commands.bats — hermetic fixture-based tests for forbut commands.
#
# These tests never shell out to a real `but` or `fzf`. They:
#   1. Source lib/utils.sh + cmds/*.sh
#   2. Put a mock `but` shim on PATH that echoes fixture files based on argv
#   3. Call the _forbut_*_list helpers directly and assert on the
#      _fbsep-delimited row shape they produce.
#
# The goal is to lock in the JSON→row contract so that drift in the
# real `but` CLI shows up as a failing test here, with a clear diff
# of what changed. End-to-end tests against a live `but setup` live
# in tests/integration.bats.

setup() {
    export FORBUT_INSTALL_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export FORBUT="$FORBUT_INSTALL_DIR/bin/git-forbut"
    local fixtures="$FORBUT_INSTALL_DIR/tests/fixtures"
    local mock_bin="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$mock_bin"

    # Mock `but` — dispatches on the first two argv tokens.
    cat > "$mock_bin/but" <<EOF
#!/usr/bin/env bash
FIXTURES="$fixtures"
case "\$1 \$2" in
    "status -f")   cat "\$FIXTURES/status-seeded.json" ;;
    "branch list") cat "\$FIXTURES/branches.json" ;;
    "diff "*)
        # Canned diff body for any single target.
        printf 'diff --git a/file b/file\n+mock diff for target: %s\n' "\$2"
        ;;
    "--version"*)  echo "but 0.1.0-mock" ;;
    *)
        echo "mock but: unhandled args: \$*" >&2
        exit 2
        ;;
esac
EOF
    chmod +x "$mock_bin/but"
    PATH="$mock_bin:$PATH"

    source "$FORBUT_INSTALL_DIR/lib/utils.sh"
    for cmd_file in "$FORBUT_INSTALL_DIR"/cmds/*.sh; do
        source "$cmd_file"
    done
}

# ---------------------------------------------------------------------------
# Row-parsing helpers
# ---------------------------------------------------------------------------
count_delimited_rows() {
    awk -v FS="$_fbsep" 'NF >= 2 && length($2) > 0 { n++ } END { print n+0 }'
}

# ===========================================================================
# Function existence (quick sanity — richer tests exercise behaviour below)
# ===========================================================================
@test "all _forbut_* command functions are defined" {
    for fn in switch log diff assign discard reorder; do
        declare -f "_forbut_$fn" >/dev/null
    done
}

@test "all _forbut_*_preview functions are defined" {
    for fn in switch_preview log_preview diff_preview assign_preview discard_preview; do
        declare -f "_forbut_$fn" >/dev/null
    done
}

# ===========================================================================
# _forbut_unassigned_list — shared by assign/discard/diff
# ===========================================================================
@test "unassigned_list emits one row per unassigned change" {
    local count
    count=$(_forbut_unassigned_list | count_delimited_rows)
    [[ "$count" -eq 3 ]]
}

@test "unassigned_list payload is the cliId (pz/ro/wt in fixture)" {
    local out
    out=$(_forbut_unassigned_list)
    echo "$out" | grep -q "${_fbsep}pz"
    echo "$out" | grep -q "${_fbsep}ro"
    echo "$out" | grep -q "${_fbsep}wt"
}

@test "unassigned_list preserves filenames containing spaces" {
    _forbut_unassigned_list | grep -qF "changed file.txt"
}

@test "unassigned_list display marks 'added' files with [A]" {
    local added
    added=$(_forbut_unassigned_list | grep -cF '[A]')
    [[ "$added" -eq 3 ]]
}

# ===========================================================================
# _forbut_diff_file_list — unassigned + assigned + committed
# ===========================================================================
@test "diff_file_list emits unassigned + assigned + committed rows" {
    # Fixture: 3 unassigned + 1 assigned + 4 committed = 8 rows
    local count
    count=$(_forbut_diff_file_list | count_delimited_rows)
    [[ "$count" -eq 8 ]]
}

@test "diff_file_list labels unassigned rows" {
    _forbut_diff_file_list | grep -qF '(unassigned)'
}

@test "diff_file_list labels staged rows with arrow to stack" {
    _forbut_diff_file_list | grep -qF 'staged →'
}

@test "diff_file_list includes commit message in location tag" {
    _forbut_diff_file_list | grep -qF 'commit: alpha commit 1'
}

@test "diff_file_list committed payloads use commit-prefixed cliIds" {
    # Fixture commit cliIds are '35:rl', '35:zu', etc. — check format.
    local out
    out=$(_forbut_diff_file_list)
    echo "$out" | grep -qE "${_fbsep}35:[a-z]+$"
}

# ===========================================================================
# _forbut_switch_list — JSON path (real but branch list --all -j shape)
# ===========================================================================
@test "switch_list extracts applied branch from appliedStacks[].heads[]" {
    _forbut_switch_list | grep -q "${_fbsep}feature/alpha"
}

@test "switch_list display shows [applied] tag after ANSI strip" {
    _forbut_switch_list | _forbut_strip_ansi | grep -q '\[applied\] feature/alpha'
}

@test "switch_list payload exactly equals the branch name (no markers/ANSI)" {
    local payload
    payload=$(_forbut_switch_list | head -1 | awk -v FS="$_fbsep" '{print $2}')
    [[ "$payload" == "feature/alpha" ]]
}

# ===========================================================================
# _forbut_log_list — exercises the %x1f%x1e embedded separator
# ===========================================================================
@test "log_list emits rows with embedded _fbsep (from forbut's own git log)" {
    # log.sh uses git log, so it works inside any real git repo with commits.
    cd "$FORBUT_INSTALL_DIR"
    local count
    count=$(_forbut_log_list | count_delimited_rows)
    [[ "$count" -gt 0 ]]
}

@test "log_list first-row payload is a short git SHA" {
    cd "$FORBUT_INSTALL_DIR"
    local payload
    payload=$(_forbut_log_list | head -1 | awk -v FS="$_fbsep" '{print $2}')
    [[ "$payload" =~ ^[a-f0-9]{7,}$ ]]
}

# ===========================================================================
# Preview dispatcher
# ===========================================================================
@test "_forbut_preview dispatches to a named preview function" {
    _forbut_test_fn() { echo "called:$1"; }
    run _forbut_preview test_fn myarg
    [[ "$output" == "called:myarg" ]]
}

# ===========================================================================
# Schema drift tripwire
# ===========================================================================
@test "schema_assert fails when required field is missing" {
    run _forbut_schema_assert '{"unexpected":"shape"}' '.unassignedChanges | type == "array"' 'bats'
    [[ "$status" -ne 0 ]]
}

@test "schema_assert passes when field is present" {
    run _forbut_schema_assert '{"unassignedChanges":[]}' '.unassignedChanges | type == "array"' 'bats'
    [[ "$status" -eq 0 ]]
}

@test "schema_assert writes a drift record to the log on failure" {
    local log_dir="$BATS_TEST_TMPDIR/state/forbut"
    XDG_STATE_HOME="$BATS_TEST_TMPDIR/state" \
        _forbut_schema_assert '{"x":1}' '.missing.field' 'bats-test' 2>/dev/null || true
    [[ -f "$log_dir/schema-drift.log" ]]
    grep -q '"missing_path":".missing.field"' "$log_dir/schema-drift.log"
    grep -q '"command":"bats-test"' "$log_dir/schema-drift.log"
}

# ===========================================================================
# Reorder stub (unchanged from old suite)
# ===========================================================================
@test "reorder emits v0.2 stub message" {
    run _forbut_reorder
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"v0.2"* ]]
}
