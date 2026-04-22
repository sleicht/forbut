#!/usr/bin/env bats
# tests/usage.bats — tests for the lightweight `usage` + `mise` integration.

setup() {
    export FORBUT_INSTALL_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

    if ! command -v mise >/dev/null 2>&1; then
        skip "mise is required for usage integration tests"
    fi
}

@test "usage spec lints via mise" {
    run mise exec usage -- usage lint "$FORBUT_INSTALL_DIR/forbut.usage.kdl"

    [[ $status -eq 0 ]]
    [[ $output == *"Found 0 error(s), 0 warning(s), 1 info(s)"* ]]
    [[ $output == *"missing-cmd-help"* ]]
}

@test "installer usage spec lints via mise" {
    run mise exec usage -- usage lint "$FORBUT_INSTALL_DIR/install.usage.kdl"

    [[ $status -eq 0 ]]
    [[ $output == *"Found 0 error(s), 0 warning(s), 1 info(s)"* ]]
    [[ $output == *"missing-cmd-help"* ]]
}

@test "usage markdown generation produces forbut command docs" {
    local out_file
    out_file="$BATS_TEST_TMPDIR/forbut.usage.md"

    run mise exec usage -- usage generate markdown -f "$FORBUT_INSTALL_DIR/forbut.usage.kdl" --out-file "$out_file"

    [[ $status -eq 0 ]]
    [[ -f "$out_file" ]]

    run grep -F "# `forbut`" "$out_file"
    [[ $status -eq 0 ]]

    run grep -F '## `forbut switch`' "$out_file"
    [[ $status -eq 0 ]]

    run grep -F '## `forbut discard`' "$out_file"
    [[ $status -eq 0 ]]
}

@test "installer usage markdown generation documents installer flags" {
    local out_file
    out_file="$BATS_TEST_TMPDIR/install.usage.md"

    run mise exec usage -- usage generate markdown -f "$FORBUT_INSTALL_DIR/install.usage.kdl" --out-file "$out_file"

    [[ $status -eq 0 ]]
    [[ -f "$out_file" ]]

    run grep -F '# `forbut-install`' "$out_file"
    [[ $status -eq 0 ]]

    run grep -F -- '--prefix' "$out_file"
    [[ $status -eq 0 ]]

    run grep -F -- '--symlink' "$out_file"
    [[ $status -eq 0 ]]
}