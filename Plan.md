# forbut — Project Plan

> forgit-style fuzzy UX for GitButler's `but` CLI

## Motivation

[forgit](https://github.com/wfxr/forgit) has proven that wrapping git commands in
[fzf](https://github.com/junegunn/fzf) dramatically improves ergonomics. GitButler's
`but` CLI is powerful but has no interactive/fuzzy layer. `forbut` fills that gap.

The end goal is a community-maintained shell plugin that can be pitched to the GitButler
team as a companion tool — not part of core GitButler, but endorsed and informed by them
(particularly around stable CLI output formats).

---

## Dependencies

- [`but`](https://github.com/gitbutlerapp/gitbutler) — GitButler CLI
- [`fzf`](https://github.com/junegunn/fzf) — fuzzy finder
- [`delta`](https://github.com/dandavison/delta) *(optional)* — prettier diff previews
- [`bat`](https://github.com/sharkdp/bat) *(optional)* — syntax-highlighted file previews
- Standard POSIX shell utilities (`awk`, `sed`, `grep`)

---

## Repo Structure

```
forbut/
├── forbut.sh          # main entry point / loader
├── bin/
│   └── forbut         # optional standalone executable
├── lib/
│   └── utils.sh       # shared helpers (colour, fzf defaults, output parsing)
├── cmds/
│   ├── log.sh
│   ├── switch.sh
│   ├── diff.sh
│   ├── assign.sh      # core feature — hunk → stack assignment
│   ├── discard.sh
│   └── reorder.sh
├── tests/             # bats or shellspec
├── docs/
│   └── mapping.md     # git → but → forbut concept mapping
├── install.sh
├── README.md
└── LICENSE            # MIT
```

---

## Concept Mapping

| git / forgit | forgit command | but equivalent | forbut command |
|---|---|---|---|
| `git add` (hunk) | `forgit::add` | `but hunk assign` | `forbut::assign` |
| `git diff` | `forgit::diff` | `but diff` / `but show` | `forbut::diff` |
| `git log` | `forgit::log` | `but log` | `forbut::log` |
| `git checkout <branch>` | `forgit::checkout_branch` | `but branch switch` | `forbut::switch` |
| `git clean` | `forgit::clean` | `but hunk discard` | `forbut::discard` |
| `git rebase -i` | `forgit::rebase` | `but stack reorder` | `forbut::reorder` |
| `git stash` | `forgit::stash` | *(replaced by virtual branches)* | — |
| `git cherry-pick` | `forgit::cherry_pick` | *(handled via stack reordering)* | — |

### Net-new concepts (no forgit equivalent)

- **Fuzzy hunk → stack assignment** — pick a hunk and assign it to a virtual branch
- **Fuzzy stack/series navigation** — browse stacks and their commits with preview
- **Fuzzy commit reordering** — reorder commits within a stack interactively
- **Fuzzy conflict inspection** — see which virtual branches conflict and why

---

## MVP — v0.1

Implement these first. Highest value, lowest complexity.

| Command | Alias | Description |
|---|---|---|
| `forbut::switch` | `fbs` | Fuzzy-switch between virtual branches/stacks |
| `forbut::log` | `fbl` | Browse commit log across current stack with diff preview |
| `forbut::diff` | `fbd` | Browse changed files with inline diff preview |
| `forbut::assign` | `fba` | Fuzzy-select uncommitted hunks and assign to a stack |
| `forbut::discard` | `fbD` | Fuzzy-select hunks/files to discard |

Start with `forbut::switch` — it's the simplest and validates the overall pattern
end-to-end before tackling hunk-level interaction.

---

## v0.2+

| Command | Alias | Description |
|---|---|---|
| `forbut::reorder` | `fbr` | Interactively reorder commits within a stack |
| `forbut::squash` | `fbsq` | Fuzzy-select commits to squash |
| `forbut::conflicts` | `fbc` | Browse conflicting virtual branches |
| `forbut::series` | `fbse` | Navigate and inspect a patch series |

---

## Shell Integration

Users opt into short aliases by sourcing `forbut.sh`:

```bash
# .zshrc / .bashrc
[ -f ~/path/to/forbut/forbut.sh ] && source ~/path/to/forbut/forbut.sh
```

Aliases are defined in `forbut.sh` and can be overridden before sourcing:

```bash
FORBUT_SWITCH_ALIAS=fbs
FORBUT_LOG_ALIAS=fbl
# etc.
```

Plugin manager support (oh-my-zsh, zinit, fisher) to be added once the API stabilises.

---

## Implementation Notes

- Model the shell architecture directly on forgit — one function per file in `cmds/`,
  loaded by `forbut.sh`
- All `fzf` calls should go through a central helper in `lib/utils.sh` so defaults
  (colours, keybindings, preview window layout) are consistent and user-overridable via
  environment variables
- `but`'s CLI output format is not yet stable — add a version guard early and fail
  loudly with a clear message if the detected `but` version is unsupported
- Use `delta` for diff previews when available, fall back to `git diff --color`
- Write tests with [bats-core](https://github.com/bats-core/bats-core)

---

## Build Order

1. Initialise repo, add `LICENSE` (MIT), stub `README.md`
2. Add `docs/mapping.md` (the concept table above, expanded)
3. Implement `lib/utils.sh` — fzf wrapper, colour helpers, dependency checks
4. Implement `forbut::switch` end-to-end, including alias wiring
5. Implement `forbut::log` and `forbut::diff`
6. Implement `forbut::assign` — the core/killer feature
7. Implement `forbut::discard`
8. Add bats tests for each command
9. Write full `README.md`
10. Open GitButler discussion linking the repo

---

## GitButler Pitch (for the discussion post)

**Problem**: `but` CLI is powerful but has no interactive/fuzzy layer, making
hunk-level and stack-level operations keyboard-heavy and hard to discover.

**Prior art**: forgit has proven this pattern works extremely well for git — it has
thousands of stars and is widely used.

**What forbut is**: A community-maintained shell plugin, not part of core GitButler.
Thin fzf wrappers around `but` subcommands, following forgit's architecture.

**Ask from the GitButler team**:
- Confirm which `but` output formats are considered stable and safe to parse
- Flag any planned CLI changes that would affect output parsing
- Optionally, link from the GitButler docs/README once the tool is stable

**Where to post**:
- [GitButler Discussions](https://github.com/gitbutlerapp/gitbutler/discussions)
- GitButler Discord — for faster back-and-forth with maintainers