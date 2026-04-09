# forbut

> forgit-style fuzzy UX for GitButler's `but` CLI

**forbut** wraps [GitButler's `but` CLI](https://docs.gitbutler.com/cli) in
[fzf](https://github.com/junegunn/fzf) to make hunk-level and stack-level
operations interactive, discoverable, and fast.
Inspired by [forgit](https://github.com/wfxr/forgit).

---

## Features

| Command | Alias | Description |
|---|---|---|
| `forbut::switch` | `fbs` | Fuzzy-switch between virtual branches/stacks |
| `forbut::log` | `fbl` | Browse commit log with diff preview |
| `forbut::diff` | `fbd` | Browse changed files with inline diff preview |
| `forbut::assign` | `fba` | Fuzzy-select uncommitted hunks and assign to a stack |
| `forbut::discard` | `fbD` | Fuzzy-select hunks/files to discard (with confirmation) |
| `forbut::reorder` | `fbr` | Reorder commits within a stack *(v0.2 — planned)* |

The **killer feature** is `forbut::assign` — a two-step fuzzy workflow that lets
you pick uncommitted hunks and assign them to any virtual branch.

## Dependencies

| Dependency | Required | Notes |
|---|---|---|
| [`but`](https://docs.gitbutler.com/cli) | Yes | GitButler CLI |
| [`fzf`](https://github.com/junegunn/fzf) >= 0.42.0 | Yes | Fuzzy finder |
| [`delta`](https://github.com/dandavison/delta) | No | Prettier diff previews (falls back to git pager) |
| [`bat`](https://github.com/sharkdp/bat) | No | Syntax-highlighted file previews |
| [`jq`](https://github.com/jqlang/jq) | No | JSON parsing for advanced features |

## Installation

### Quick install

```bash
git clone https://github.com/user/forbut.git ~/.forbut
~/.forbut/install.sh
```

Then add to your `.bashrc` or `.zshrc`:

```bash
source "$HOME/.local/share/forbut/forbut.sh"
```

### Development (symlink) install

```bash
git clone https://github.com/user/forbut.git ~/src/forbut
~/src/forbut/install.sh --symlink
```

### Custom prefix

```bash
./install.sh --prefix=/opt/forbut
```

### Uninstall

```bash
./install.sh --uninstall
```

## Usage

### Source the plugin (shell functions + aliases)

```bash
# .bashrc / .zshrc
[ -f ~/.local/share/forbut/forbut.sh ] && source ~/.local/share/forbut/forbut.sh
```

### Or use the standalone CLI

```bash
forbut switch
forbut log
forbut diff
forbut assign
forbut discard
```

### Aliases

Once sourced, short aliases are available:

```
fbs   →  forbut::switch
fbl   →  forbut::log
fbd   →  forbut::diff
fba   →  forbut::assign
fbD   →  forbut::discard
fbr   →  forbut::reorder
```

Disable all aliases:

```bash
export FORBUT_NO_ALIASES=1
source ~/.local/share/forbut/forbut.sh
```

Override individual alias names before sourcing:

```bash
export FORBUT_SWITCH_ALIAS=myswitch
export FORBUT_LOG_ALIAS=mylog
source ~/.local/share/forbut/forbut.sh
```

## Configuration

All configuration is via environment variables. Set them in your shell config
before sourcing `forbut.sh`.

### Pager

```bash
export FORBUT_PAGER="delta"              # diff pager (default: delta > git core.pager > cat)
export FORBUT_PREVIEW_PAGER="delta --width=80"  # fzf preview pane pager
```

### fzf options

```bash
# Extra fzf options applied to every forbut command
export FORBUT_FZF_DEFAULT_OPTS="--height=90%"

# Per-command fzf overrides
export FORBUT_SWITCH_FZF_OPTS="--preview-window=bottom:40%"
export FORBUT_LOG_FZF_OPTS="--no-sort"
export FORBUT_DIFF_FZF_OPTS=""
export FORBUT_ASSIGN_FZF_OPTS=""
export FORBUT_DISCARD_FZF_OPTS=""
```

fzf options are layered in this order (last wins):

1. `$FZF_DEFAULT_OPTS` — your global fzf config
2. forbut built-in defaults — ANSI, height, keybindings, preview layout
3. `$FORBUT_FZF_DEFAULT_OPTS` — your forbut-wide overrides
4. `$FORBUT_<CMD>_FZF_OPTS` — per-command overrides

### Other

```bash
export FORBUT_DISCARD_NO_CONFIRM=1   # skip the "are you sure?" prompt on discard
```

## Keybindings

Default keybindings inside fzf (consistent across all commands):

| Key | Action |
|---|---|
| `Enter` | Accept / execute primary action |
| `Tab` | Toggle selection (multi-select commands) |
| `Ctrl-A` | Select all (multi-select commands) |
| `Ctrl-/` | Toggle preview pane |
| `Ctrl-D` | Scroll preview down |
| `Ctrl-U` | Scroll preview up |
| `Ctrl-Y` | Copy hash to clipboard (log) |
| `Ctrl-X` | Unapply branch (switch) |

## Project Structure

```
forbut/
├── forbut.sh          # Shell plugin loader (functions + aliases)
├── bin/
│   └── forbut         # Standalone CLI (all logic lives here)
├── lib/
│   └── utils.sh       # Shared helpers (colours, fzf wrapper, dep checks, pager)
├── cmds/
│   ├── switch.sh      # forbut::switch
│   ├── log.sh         # forbut::log
│   ├── diff.sh        # forbut::diff
│   ├── assign.sh      # forbut::assign
│   ├── discard.sh     # forbut::discard
│   └── reorder.sh     # forbut::reorder (v0.2 stub)
├── tests/             # bats-core tests
├── docs/
│   └── mapping.md     # git → but → forbut concept mapping
├── install.sh
├── README.md
└── LICENSE
```

## How It Works

forbut follows [forgit's](https://github.com/wfxr/forgit) two-layer architecture:

- **`forbut.sh`** — thin shell plugin that registers functions (`forbut::switch`, etc.)
  and aliases (`fbs`, etc.), then delegates to `bin/forbut`.
- **`bin/forbut`** — standalone Bash script containing all logic. Sources `lib/utils.sh`
  and every `cmds/*.sh` file, then dispatches to the requested command function.

fzf previews use a **self-invocation** pattern: the `--preview` command calls
`forbut _preview <func> {}`, which re-enters the script with all helpers available
in the subprocess.

## Running Tests

Tests use [bats-core](https://github.com/bats-core/bats-core):

```bash
# Install bats (macOS)
brew install bats-core

# Run all tests
bats tests/
```

## Roadmap

### v0.1 (current)

- [x] `forbut::switch` — fuzzy branch switching
- [x] `forbut::log` — commit log browser
- [x] `forbut::diff` — changed files browser
- [x] `forbut::assign` — hunk → stack assignment
- [x] `forbut::discard` — fuzzy discard with confirmation

### v0.2

- [ ] `forbut::reorder` — interactive commit reordering
- [ ] `forbut::squash` — fuzzy-select commits to squash
- [ ] `forbut::conflicts` — browse conflicting virtual branches
- [ ] `forbut::series` — navigate and inspect a patch series
- [ ] Plugin manager support (oh-my-zsh, zinit, fisher)

## License

[MIT](LICENSE)
