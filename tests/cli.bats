#!/usr/bin/env bats
# tests/cli.bats — tests for bin/git-forbut CLI dispatch

setup() {
    export FORBUT_INSTALL_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export FORBUT="$FORBUT_INSTALL_DIR/bin/git-forbut"
    chmod +x "$FORBUT"
}

# ---------------------------------------------------------------------------
# Help & version
# ---------------------------------------------------------------------------
@test "forbut --help shows usage" {
    run "$FORBUT" --help
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"forbut"* ]]
    [[ "$output" == *"USAGE"* ]]
}

@test "forbut help shows usage" {
    run "$FORBUT" help
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"USAGE"* ]]
}

@test "forbut with no args shows usage" {
    run "$FORBUT"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"USAGE"* ]]
}

@test "forbut --version shows version" {
    run "$FORBUT" --version
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"forbut"* ]]
    [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "forbut -v shows version" {
    run "$FORBUT" -v
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

# ---------------------------------------------------------------------------
# Unknown command
# ---------------------------------------------------------------------------
@test "forbut unknown-command fails with error" {
    run "$FORBUT" unknown-command
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Unknown command"* ]]
}

# ---------------------------------------------------------------------------
# Command sourcing
# ---------------------------------------------------------------------------
@test "all command files are valid bash" {
    for f in "$FORBUT_INSTALL_DIR"/cmds/*.sh; do
        run bash -n "$f"
        [[ "$status" -eq 0 ]]
    done
}

@test "utils.sh is valid bash" {
    run bash -n "$FORBUT_INSTALL_DIR/lib/utils.sh"
    [[ "$status" -eq 0 ]]
}

@test "bin/git-forbut is valid bash" {
    run bash -n "$FORBUT"
    [[ "$status" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# Reorder stub
# ---------------------------------------------------------------------------
@test "forbut reorder shows v0.2 message" {
    # Skip prerequisite checks by sourcing directly
    source "$FORBUT_INSTALL_DIR/lib/utils.sh"
    for cmd_file in "$FORBUT_INSTALL_DIR"/cmds/*.sh; do
        source "$cmd_file"
    done
    run _forbut_reorder
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"v0.2"* ]]
}
