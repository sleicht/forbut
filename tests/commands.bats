#!/usr/bin/env bats
# tests/commands.bats — integration tests for forbut commands
# These tests verify that command functions exist and have correct signatures.
# Full interactive testing requires but + fzf and is done manually.

setup() {
    export FORBUT_INSTALL_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export FORBUT="$FORBUT_INSTALL_DIR/bin/forbut"
    source "$FORBUT_INSTALL_DIR/lib/utils.sh"
    for cmd_file in "$FORBUT_INSTALL_DIR"/cmds/*.sh; do
        source "$cmd_file"
    done
}

# ---------------------------------------------------------------------------
# Function existence checks
# ---------------------------------------------------------------------------
@test "_forbut_cmd_switch is defined" {
    declare -f _forbut_cmd_switch >/dev/null
}

@test "_forbut_cmd_log is defined" {
    declare -f _forbut_cmd_log >/dev/null
}

@test "_forbut_cmd_diff is defined" {
    declare -f _forbut_cmd_diff >/dev/null
}

@test "_forbut_cmd_assign is defined" {
    declare -f _forbut_cmd_assign >/dev/null
}

@test "_forbut_cmd_discard is defined" {
    declare -f _forbut_cmd_discard >/dev/null
}

@test "_forbut_cmd_reorder is defined" {
    declare -f _forbut_cmd_reorder >/dev/null
}

# ---------------------------------------------------------------------------
# Preview function existence checks
# ---------------------------------------------------------------------------
@test "_forbut_preview_switch_branch is defined" {
    declare -f _forbut_preview_switch_branch >/dev/null
}

@test "_forbut_preview_log_commit is defined" {
    declare -f _forbut_preview_log_commit >/dev/null
}

@test "_forbut_preview_diff_file is defined" {
    declare -f _forbut_preview_diff_file >/dev/null
}

@test "_forbut_preview_assign_hunk is defined" {
    declare -f _forbut_preview_assign_hunk >/dev/null
}

@test "_forbut_preview_discard_item is defined" {
    declare -f _forbut_preview_discard_item >/dev/null
}

# ---------------------------------------------------------------------------
# Preview dispatcher
# ---------------------------------------------------------------------------
@test "_forbut_preview dispatches to named function" {
    # Create a mock preview function
    _forbut_preview_test_func() {
        echo "preview_called:$1"
    }
    run _forbut_preview test_func "myarg"
    [[ "$output" == "preview_called:myarg" ]]
}

# ---------------------------------------------------------------------------
# Diff file list helper
# ---------------------------------------------------------------------------
@test "_forbut_diff_file_list is defined" {
    declare -f _forbut_diff_file_list >/dev/null
}
