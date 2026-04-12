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
    [[ -n $FORBUT_VERSION ]]
}

@test "FORBUT_VERSION follows semver" {
    [[ $FORBUT_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------
@test "colour variables are defined" {
    [[ -n ${FORBUT_COLOR_RESET+set} ]]
    [[ -n ${FORBUT_COLOR_RED+set} ]]
    [[ -n ${FORBUT_COLOR_GREEN+set} ]]
    [[ -n ${FORBUT_COLOR_YELLOW+set} ]]
    [[ -n ${FORBUT_COLOR_BLUE+set} ]]
    [[ -n ${FORBUT_COLOR_CYAN+set} ]]
    [[ -n ${FORBUT_COLOR_BOLD+set} ]]
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
@test "_forbut_info writes to stderr" {
    run bash -c 'source "$FORBUT_INSTALL_DIR/lib/utils.sh"; _forbut_info "hello" 2>&1'
    [[ $output == *"hello"* ]]
    [[ $output == *"[forbut]"* ]]
}

@test "_forbut_warn writes to stderr" {
    run bash -c 'source "$FORBUT_INSTALL_DIR/lib/utils.sh"; _forbut_warn "warning msg" 2>&1'
    [[ $output == *"warning msg"* ]]
}

@test "_forbut_error writes to stderr" {
    run bash -c 'source "$FORBUT_INSTALL_DIR/lib/utils.sh"; _forbut_error "error msg" 2>&1'
    [[ $output == *"error msg"* ]]
}

@test "_forbut_die returns 1" {
    run _forbut_die "fatal"
    [[ $status -eq 1 ]]
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
@test "_forbut_get_pager core returns something" {
    local pager
    pager=$(_forbut_get_pager core)
    [[ -n $pager ]]
}

@test "_forbut_get_pager core respects FORBUT_PAGER override" {
    FORBUT_PAGER="less -R"
    local pager
    pager=$(_forbut_get_pager core)
    [[ $pager == "less -R" ]]
    unset FORBUT_PAGER
}

@test "_forbut_get_pager diff respects FORBUT_DIFF_PAGER override" {
    FORBUT_DIFF_PAGER="diff-so-fancy"
    local pager
    pager=$(_forbut_get_pager diff)
    [[ $pager == "diff-so-fancy" ]]
    unset FORBUT_DIFF_PAGER
}

@test "_forbut_get_pager enter returns LESS config" {
    local pager
    pager=$(_forbut_get_pager enter)
    [[ $pager == *"less"* ]]
}

# ---------------------------------------------------------------------------
# bat detection
# ---------------------------------------------------------------------------
@test "_forbut_bat_cmd returns bat, batcat, or cat" {
    local cmd
    cmd=$(_forbut_bat_cmd)
    [[ $cmd == "bat" || $cmd == "batcat" || $cmd == "cat" ]]
}

# ---------------------------------------------------------------------------
# fzf defaults (env var now, not a function)
# ---------------------------------------------------------------------------
@test "FORBUT_FZF_DEFAULT_OPTS includes ansi flag" {
    [[ $FORBUT_FZF_DEFAULT_OPTS == *"--ansi"* ]]
}

@test "FORBUT_FZF_DEFAULT_OPTS includes height" {
    [[ $FORBUT_FZF_DEFAULT_OPTS == *"--height"* ]]
}

@test "FORBUT_FZF_DEFAULT_OPTS includes user overrides" {
    FORBUT_FZF_DEFAULT_OPTS="--my-custom-flag" \
        bash -c 'source "$FORBUT_INSTALL_DIR/lib/utils.sh"; [[ "$FORBUT_FZF_DEFAULT_OPTS" == *"--my-custom-flag"* ]]'
}

# ---------------------------------------------------------------------------
# Display/payload separator (_fbsep) + text extraction helpers
# ---------------------------------------------------------------------------
@test "_fbsep is defined as 0x1f 0x1e" {
    [[ -n $_fbsep ]]
    local hex
    hex=$(printf '%s' "$_fbsep" | od -An -tx1 | tr -d ' \n')
    [[ $hex == "1f1e" ]]
}

@test "_forbut_strip_ansi removes colour codes" {
    local out
    out=$(printf '\e[33myellow\e[0m' | _forbut_strip_ansi)
    [[ $out == "yellow" ]]
}

@test "_forbut_extract_sha pulls first hash" {
    local out
    out=$(echo "deadbeef01 some commit message" | _forbut_extract_sha)
    [[ $out == "deadbeef01" ]]
}

@test "_forbut_extract_branch_name strips current marker" {
    local out
    out=$(echo "* feature/foo" | _forbut_extract_branch_name)
    [[ $out == "feature/foo" ]]
}

# ---------------------------------------------------------------------------
# Repo guard
# ---------------------------------------------------------------------------
@test "_forbut_require_repo succeeds in a git repo" {
    # This test file is inside the forbut repo, so it should pass
    _forbut_require_repo
}
