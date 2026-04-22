#!/usr/bin/env bats
# tests/install.bats — installer coverage for runtime payload and installed artifacts.

setup() {
    export FORBUT_INSTALL_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export INSTALLER="$FORBUT_INSTALL_DIR/install.sh"
    export TEST_PREFIX="$BATS_TEST_TMPDIR/prefix"

    chmod +x "$INSTALLER"
}

assert_exists() {
    local path="$1"
    [[ -e "$path" ]]
}

assert_missing() {
    local path="$1"
    [[ ! -e "$path" ]]
}

@test "install.sh installs runtime payload, completions, and manpage into the prefix" {
    run "$INSTALLER" --prefix="$TEST_PREFIX"

    [[ $status -eq 0 ]]
    [[ $output == *"Installed shell completion files."* ]]
    [[ $output == *"Installed generated manpage"* ]]

    assert_exists "$TEST_PREFIX/share/forbut/forbut.sh"
    assert_exists "$TEST_PREFIX/share/forbut/lib/utils.sh"
    assert_exists "$TEST_PREFIX/share/forbut/cmds/assign.sh"
    assert_exists "$TEST_PREFIX/share/forbut/bin/git-forbut"
    assert_exists "$TEST_PREFIX/bin/git-forbut"
    assert_exists "$TEST_PREFIX/share/bash-completion/completions/git-forbut"
    assert_exists "$TEST_PREFIX/share/zsh/site-functions/_git-forbut"
    assert_exists "$TEST_PREFIX/share/fish/vendor_completions.d/git-forbut.fish"
    assert_exists "$TEST_PREFIX/share/man/man1/forbut.1"
}

@test "install.sh --symlink preserves symlink mode for runtime payload and completions" {
    run "$INSTALLER" --symlink --prefix="$TEST_PREFIX"

    [[ $status -eq 0 ]]
    [[ $output == *"Using symlinks (development mode)"* ]]

    [[ -L "$TEST_PREFIX/share/forbut/forbut.sh" ]]
    [[ -L "$TEST_PREFIX/share/forbut/lib" ]]
    [[ -L "$TEST_PREFIX/share/forbut/cmds" ]]
    [[ -L "$TEST_PREFIX/share/forbut/bin" ]]
    [[ -L "$TEST_PREFIX/share/bash-completion/completions/git-forbut" ]]
    [[ -L "$TEST_PREFIX/share/zsh/site-functions/_git-forbut" ]]
    [[ -L "$TEST_PREFIX/share/fish/vendor_completions.d/git-forbut.fish" ]]
    assert_exists "$TEST_PREFIX/share/man/man1/forbut.1"
}

@test "install.sh --uninstall removes runtime payload and installed artifacts" {
    "$INSTALLER" --prefix="$TEST_PREFIX" >/dev/null

    run "$INSTALLER" --uninstall --prefix="$TEST_PREFIX"

    [[ $status -eq 0 ]]
    assert_missing "$TEST_PREFIX/share/forbut"
    assert_missing "$TEST_PREFIX/bin/git-forbut"
    assert_missing "$TEST_PREFIX/share/bash-completion/completions/git-forbut"
    assert_missing "$TEST_PREFIX/share/zsh/site-functions/_git-forbut"
    assert_missing "$TEST_PREFIX/share/fish/vendor_completions.d/git-forbut.fish"
    assert_missing "$TEST_PREFIX/share/man/man1/forbut.1"
}

@test "install.sh still succeeds without usage and skips only the optional manpage" {
    run env PATH="/usr/bin:/bin:/usr/sbin:/sbin" HOME="$HOME" FORBUT_INSTALL_PREFIX="$TEST_PREFIX" bash "$INSTALLER"

    [[ $status -eq 0 ]]
    [[ $output == *"Skipping manpage generation because usage is unavailable."* ]]
    assert_exists "$TEST_PREFIX/share/forbut/bin/git-forbut"
    assert_exists "$TEST_PREFIX/share/bash-completion/completions/git-forbut"
    assert_missing "$TEST_PREFIX/share/man/man1/forbut.1"
}