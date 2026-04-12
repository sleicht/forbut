<h1 align="center">🧈 forbut</h1>
<p align="center">
    <em>Utility tool for using <a href="https://docs.gitbutler.com/cli">GitButler's <code>but</code> CLI</a> interactively. Powered by <a href="https://github.com/junegunn/fzf">junegunn/fzf</a>.</em>
</p>

<p align="center">
    <a href="LICENSE">
        <img src="https://img.shields.io/badge/License-MIT-brightgreen.svg"/>
    </a>
    <a href="https://img.shields.io/badge/Shell-Bash%20%7C%20Zsh%20%7C%20Fish-blue">
        <img src="https://img.shields.io/badge/Shell-Bash%20%7C%20Zsh%20%7C%20Fish-blue"/>
    </a>
    <a href="https://github.com/pre-commit/pre-commit">
        <img src="https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white" alt="pre-commit" />
</p>

This tool is designed to help you use [GitButler](https://gitbutler.com) more efficiently from the terminal.
It's **lightweight**, **easy to use**, and heavily inspired by [forgit](https://github.com/wfxr/forgit).

📝 Features
------------

The **killer feature** is `fba` — a two-step fuzzy workflow that lets you pick
uncommitted hunks and assign them to any virtual branch.

### Full Command List

| Command | Description                                                                  |
|---------|------------------------------------------------------------------------------|
| `fbs`   | Interactive virtual branch / stack switcher (`but apply` / `but unapply`)    |
| `fbl`   | Interactive `git log` viewer with diff preview                               |
| `fbd`   | Interactive `but diff` viewer across unassigned + staged + committed changes |
| `fba`   | Interactive hunk → stack assignment (`but stage` → `but commit`)             |
| `fbD`   | Interactive hunk / file discard with confirmation                            |
| `fbr`   | Interactive commit reorder within a stack *(v0.2 — planned)*                 |

📥 Installation
----------------

### Requirements

- [`but`](https://docs.gitbutler.com/cli) — GitButler CLI
- [`fzf`](https://github.com/junegunn/fzf) version `0.42.0` or higher
- [`jq`](https://github.com/jqlang/jq) — hard dependency (JSON is the primary contract with `but`)
- [`git`](https://git-scm.com) — the non-GitButler fallback path

### Quick install

```bash
git clone https://github.com/user/forbut.git ~/.forbut
~/.forbut/install.sh
```

Then add the following to your shell's config file:

```sh
# Bash (~/.bashrc) / Zsh (~/.zshrc):
[ -f $HOME/.local/share/forbut/forbut.sh ] && source $HOME/.local/share/forbut/forbut.sh
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

### Git Integration

You can use forbut as a sub-command of git by making `bin/git-forbut` available in `$PATH`:

```sh
PATH="$PATH:$FORBUT_INSTALL_DIR/bin"
```

Then any forbut command will work as:

```cmd
forbut switch
forbut log
forbut diff
```

🚀 Usage
---------

### Shell Aliases

You can change the default aliases by exporting these variables **before** sourcing the forbut shell plugin.
(To disable all aliases, set the `FORBUT_NO_ALIASES` flag.)

```bash
FORBUT_SWITCH_ALIAS=fbs
FORBUT_LOG_ALIAS=fbl
FORBUT_DIFF_ALIAS=fbd
FORBUT_ASSIGN_ALIAS=fba
FORBUT_DISCARD_ALIAS=fbD
FORBUT_REORDER_ALIAS=fbr
```

Shell functions (`forbut::switch`, `forbut::log`, …) are registered regardless
and can be called directly if you prefer.

⚙ Configuration
-----------------

Options can be set via environment variables. They have to be **exported** in
order to be recognized by forbut.

### Per-command Options

Each forbut command can be customized with a dedicated environment variable for
fzf options:

| Command | FZF Options               |
|---------|---------------------------|
| `fbs`   | `FORBUT_SWITCH_FZF_OPTS`  |
| `fbl`   | `FORBUT_LOG_FZF_OPTS`     |
| `fbd`   | `FORBUT_DIFF_FZF_OPTS`    |
| `fba`   | `FORBUT_ASSIGN_FZF_OPTS`  |
| `fbD`   | `FORBUT_DISCARD_FZF_OPTS` |

### Pagers

forbut resolves pagers from git's configuration, falling back through sensible
defaults. Each can be overridden via environment variable:

| Pager                  | Fallbacks to                                  |
|------------------------|-----------------------------------------------|
| `FORBUT_PAGER`         | `git config core.pager` _or_ `cat`            |
| `FORBUT_DIFF_PAGER`    | `git config pager.diff` _or_ `$FORBUT_PAGER`  |
| `FORBUT_SHOW_PAGER`    | `git config pager.show` _or_ `$FORBUT_PAGER`  |
| `FORBUT_BLAME_PAGER`   | `git config pager.blame` _or_ `$FORBUT_PAGER` |
| `FORBUT_PREVIEW_PAGER` | Normal pager resolution                       |

### FZF Options

You can add default fzf options for forbut, including keybindings, layout, etc.
(No need to repeat the options already defined in `FZF_DEFAULT_OPTS`.)

```bash
export FORBUT_FZF_DEFAULT_OPTS="
--exact
--border
--cycle
--reverse
--height=80%
"
```

Complete loading order of fzf options is:

1. `FZF_DEFAULT_OPTS` (fzf global)
2. `FORBUT_FZF_DEFAULT_OPTS` (forbut global)
3. `FORBUT_<CMD>_FZF_OPTS` (command specific)

### Other Options

| Option                      | Description                                | Default |
|-----------------------------|--------------------------------------------|---------|
| `FORBUT_DISCARD_NO_CONFIRM` | Skip the "are you sure?" prompt on discard | unset   |
| `FORBUT_NO_ALIASES`         | Disable all shell aliases                  | unset   |

### Schema Drift Log

forbut uses `but`'s JSON output as its primary data contract. When the JSON
schema changes upstream, forbut fails loudly and appends a structured record to:

```
${XDG_STATE_HOME:-$HOME/.local/state}/forbut/schema-drift.log
```

Each entry includes the `but` version, forbut version, missing field path,
command, and raw sample. When filing upstream issues with the GitButler team,
grab evidence from this log.

⌨ Keybindings
---------------

|              Key               | Action                                   |
|:------------------------------:|------------------------------------------|
|        <kbd>Enter</kbd>        | Accept / execute primary action          |
|         <kbd>Tab</kbd>         | Toggle selection (multi-select commands) |
| <kbd>Ctrl</kbd> - <kbd>A</kbd> | Select all (multi-select commands)       |
| <kbd>Ctrl</kbd> - <kbd>/</kbd> | Toggle preview pane                      |
| <kbd>Ctrl</kbd> - <kbd>D</kbd> | Scroll preview down                      |
| <kbd>Ctrl</kbd> - <kbd>U</kbd> | Scroll preview up                        |
| <kbd>Ctrl</kbd> - <kbd>Y</kbd> | Copy commit hash to clipboard (`fbl`)    |
| <kbd>Ctrl</kbd> - <kbd>X</kbd> | Unapply branch (`fbs`)                   |

📦 Optional dependencies
-------------------------

- [`delta`](https://github.com/dandavison/delta) / [`diff-so-fancy`](https://github.com/so-fancy/diff-so-fancy): For better human-readable diffs.
- [`bat`](https://github.com/sharkdp/bat): Syntax-highlighted file previews.

💡 Tips
--------

- `fbd` supports an optional target argument: `fbd <commit>` or `fbd <stack>` shows the file list for that specific diff target.
- `fbl` accepts a branch name: `fbl feature/alpha` scopes the log to that branch.
- forbut prefers `but`'s JSON output but transparently falls back to pure `git` in non-GitButler repositories — most commands work anywhere.

📁 Project Structure
---------------------

```
forbut/
├── forbut.sh          # Shell plugin loader (functions + aliases)
├── bin/
│   └── forbut         # Standalone CLI dispatcher
├── lib/
│   └── utils.sh       # Shared helpers (fzf wrapper, pagers, schema assert, ...)
├── cmds/
│   ├── switch.sh      # forbut::switch
│   ├── log.sh         # forbut::log
│   ├── diff.sh        # forbut::diff
│   ├── assign.sh      # forbut::assign
│   ├── discard.sh     # forbut::discard
│   └── reorder.sh     # forbut::reorder (v0.2 stub)
├── tests/             # bats-core tests (utils + fixture + integration)
│   └── fixtures/      # Captured `but` JSON samples for hermetic tests
├── docs/
│   └── mapping.md     # git → but → forbut concept mapping
├── install.sh
├── README.md
└── LICENSE
```

🛠 How It Works
---------------

forbut follows forgit's two-layer architecture:

- **`forbut.sh`** — thin shell plugin that registers functions (`forbut::switch`, etc.) and aliases (`fbs`, etc.), then delegates to `bin/git-forbut`.
- **`bin/git-forbut`** — standalone Bash script containing all logic. Sources `lib/utils.sh` and every `cmds/*.sh` file, then dispatches to the requested command.

### The `_fbsep` display/payload contract

Every fuzzy picker emits rows shaped as:

```
<ansi-coloured display>${_fbsep}<machine payload>
```

where `_fbsep=$'\x1f\x1e'` (ASCII Unit Separator + Record Separator). fzf is
invoked with `--delimiter=$_fbsep --with-nth=1 --accept-nth=2`, so it **shows**
field 1 but **returns** field 2 verbatim — no `awk '{print $N}'` on selection
output, no column drift, no marker/ANSI parsing bugs.

fzf previews use a **self-invocation** pattern: the `--preview` command calls
`forbut preview <func> {}`, which re-enters the script with all helpers
available.

🧪 Running Tests
----------------

Tests use [bats-core](https://github.com/bats-core/bats-core):

```bash
# Install bats (macOS)
brew install bats-core

# Run all tests
bats tests/
```

The suite is split into three layers:

| Suite                    | What it covers                                                 |
|--------------------------|----------------------------------------------------------------|
| `tests/utils.bats`       | `lib/utils.sh` primitives (pagers, `_fbsep`, schema assert, …) |
| `tests/commands.bats`    | Fixture-based command tests with a mock `but` shim on `$PATH`  |
| `tests/integration.bats` | End-to-end tests against a real `but setup` in a temp repo     |

Set `FORBUT_SKIP_INTEGRATION=1` to skip the integration layer (useful in CI
environments where writing to GitButler's app-support directory is undesirable).

🗺 Roadmap
-----------

### v0.1 (current)

- [x] `fbs` — fuzzy branch switching
- [x] `fbl` — commit log browser
- [x] `fbd` — changed files browser
- [x] `fba` — hunk → stack assignment
- [x] `fbD` — fuzzy discard with confirmation

### v0.2

- [ ] `fbr` — interactive commit reordering
- [ ] `fbsq` — fuzzy-select commits to squash
- [ ] `fbc` — browse conflicting virtual branches
- [ ] `fbS` — navigate and inspect a patch series
- [ ] Plugin manager support (oh-my-zsh, zinit, fisher)

⚒️ Contributing
---------------

Contributions are welcome. When filing issues involving schema mismatches with
`but`, please attach a recent entry from the schema drift log (see
[Schema Drift Log](#schema-drift-log) above).

📃 License
-----------

[MIT](LICENSE)
