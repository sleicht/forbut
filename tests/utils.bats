#!/usr/bin/env bats
# tests/utils.bats — tests for lib/utils.sh

setup() {
    export FORBUT_INSTALL_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "$FORBUT_INSTALL_DIR/lib/utils.sh"
}

# ---------------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------------
@test "FORBUT_VERSION is set" {
    [[ -n "$FORBUT_VERSION" ]]
}

@test "FORBUT_VERSION follows semver" {
    [[ "$FORBUT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------
@test "colour variables are defined" {
    [[ -n "${FORBUT_COLOR_RESET+set}" ]]
    [[ -n "${FORBUT_COLOR_RED+set}" ]]
    [[ -n "${FORBUT_COLOR_GREEN+set}" ]]
    [[ -n "${FORBUT_COLOR_YELLOW+set}" ]]
    [[ -n "${FORBUT_COLOR_BLUE+set}" ]]
    [[ -n "${FORBUT_COLOR_CYAN+set}" ]]
    [[ -n "${FORBUT_COLOR_BOLD+set}" ]]
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
@test "_forbut_info writes to stderr" {
    run bash -c 'source "$FORBUT_INSTALL_DIR/lib/utils.sh"; _forbut_info "hello" 2>&1'
    [[ "$output" == *"hello"* ]]
    [[ "$output" == *"[forbut]"* ]]
}

@test "_forbut_warn writes to stderr" {
    run bash -c 'source "$FORBUT_INSTALL_DIR/lib/utils.sh"; _forbut_warn "warning msg" 2>&1'
    [[ "$output" == *"warning msg"* ]]
}

@test "_forbut_error writes to stderr" {
    run bash -c 'source "$FORBUT_INSTALL_DIR/lib/utils.sh"; _forbut_error "error msg" 2>&1'
    [[ "$output" == *"error msg"* ]]
}

@test "_forbut_die returns 1" {
    run _forbut_die "fatal"
    [[ "$status" -eq 1 ]]
}

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
@test "_forbut_check_cmd finds bash" {
    _forbut_check_cmd bash
}

@test "_forbut_check_cmd fails for nonexistent command" {
    ! _forbut_check_cmd __nonexistent_command_xyz__
}

# ---------------------------------------------------------------------------
# Pager resolution
# ---------------------------------------------------------------------------
@test "_forbut_pager returns something" {
    local pager
    pager=$(_forbut_pager)
    [[ -n "$pager" ]]
}

@test "_forbut_pager respects FORBUT_PAGER override" {
    FORBUT_PAGER="less -R"
    local pager
    pager=$(_forbut_pager)
    [[ "$pager" == "less -R" ]]
    unset FORBUT_PAGER
}

@test "_forbut_preview_pager returns something" {
    local pager
    pager=$(_forbut_preview_pager)
    [[ -n "$pager" ]]
}

@test "_forbut_preview_pager respects FORBUT_PREVIEW_PAGER override" {
    FORBUT_PREVIEW_PAGER="cat"
    local pager
    pager=$(_forbut_preview_pager)
    [[ "$pager" == "cat" ]]
    unset FORBUT_PREVIEW_PAGER
}

# ---------------------------------------------------------------------------
# bat detection
# ---------------------------------------------------------------------------
@test "_forbut_bat_cmd returns bat, batcat, or cat" {
    local cmd
    cmd=$(_forbut_bat_cmd)
    [[ "$cmd" == "bat" || "$cmd" == "batcat" || "$cmd" == "cat" ]]
}

# ---------------------------------------------------------------------------
# fzf defaults
# ---------------------------------------------------------------------------
@test "_forbut_fzf_defaults includes ansi flag" {
    local defaults
    defaults=$(_forbut_fzf_defaults)
    [[ "$defaults" == *"--ansi"* ]]
}

@test "_forbut_fzf_defaults includes height" {
    local defaults
    defaults=$(_forbut_fzf_defaults)
    [[ "$defaults" == *"--height"* ]]
}

@test "_forbut_fzf_defaults includes user overrides" {
    FORBUT_FZF_DEFAULT_OPTS="--my-custom-flag"
    local defaults
    defaults=$(_forbut_fzf_defaults)
    [[ "$defaults" == *"--my-custom-flag"* ]]
    unset FORBUT_FZF_DEFAULT_OPTS
}

# ---------------------------------------------------------------------------
# Separator helpers
# ---------------------------------------------------------------------------
@test "FORBUT_SEP is defined" {
    [[ -n "$FORBUT_SEP" ]]
}

@test "_forbut_extract_payload extracts right side" {
    local input="display${FORBUT_SEP}payload"
    local result
    result=$(_forbut_extract_payload "$input")
    [[ "$result" == "payload" ]]
}

@test "_forbut_extract_display extracts left side" {
    local input="display${FORBUT_SEP}payload"
    local result
    result=$(_forbut_extract_display "$input")
    [[ "$result" == "display" ]]
}

# ---------------------------------------------------------------------------
# Repo guard
# ---------------------------------------------------------------------------
@test "_forbut_require_repo succeeds in a git repo" {
    # This test file is inside the forbut repo, so it should pass
    _forbut_require_repo
}
