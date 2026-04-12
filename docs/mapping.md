# Concept Mapping: git / forgit -> but -> forbut

This document maps familiar git concepts (and their forgit equivalents) to
GitButler's `but` CLI and the corresponding `forbut` interactive wrappers.

## Core Command Mapping

| git / forgit                           | forgit command             | but equivalent                   | forbut command    | Status |
|----------------------------------------|----------------------------|----------------------------------|-------------------|--------|
| `git add` (hunk)                       | `forgit::add`              | `but stage <hunks> <branch>`     | `forbut::assign`  | v0.1   |
| `git diff`                             | `forgit::diff`             | `but diff [target]`              | `forbut::diff`    | v0.1   |
| `git log`                              | `forgit::log`              | `but branch show <branch>`       | `forbut::log`     | v0.1   |
| `git checkout <branch>`                | `forgit::checkout::branch` | `but apply` / `but unapply`      | `forbut::switch`  | v0.1   |
| `git clean` / `git checkout -- <file>` | `forgit::clean`            | `but discard`                    | `forbut::discard` | v0.1   |
| `git rebase -i`                        | `forgit::rebase`           | `but move`                       | `forbut::reorder` | v0.2   |
| `git stash`                            | `forgit::stash::show`      | *(replaced by virtual branches)* | --                | N/A    |
| `git cherry-pick`                      | `forgit::cherry::pick`     | `but pick`                       | --                | --     |

## Net-new Concepts (no forgit equivalent)

These features have no direct parallel in forgit because they are unique to
GitButler's virtual branch model:

### Fuzzy hunk → stack assignment (`forbut::assign`)

The killer feature. In forgit, `forgit::add` stages hunks to the single
working index. In GitButler, uncommitted changes can be assigned to different
virtual branches ("stacks"). `forbut::assign` presents a two-step workflow:

1. **Select hunks** — fzf multi-select from uncommitted changes with diff preview
2. **Select target branch** — pick which virtual branch receives the hunks

Under the hood: `but stage <hunk_ids> <branch_name>`

### Fuzzy stack/series navigation

Browse stacks and their commits with a preview. GitButler's virtual branches
mean you can have multiple active branches simultaneously — `forbut::switch`
applies/unapplies branches from the workspace.

### Fuzzy commit reordering (`forbut::reorder`, v0.2)

Interactive reordering of commits within a stack. Maps to `but move`.

### Fuzzy conflict inspection (planned)

See which virtual branches conflict and why.

## but CLI ID System

The `but` CLI uses a unique short-code identifier system where every actionable
entity gets a 2-character alphanumeric code:

| Code pattern     | Entity                               |
|------------------|--------------------------------------|
| `zz`             | Unstaged changes area                |
| `g0`, `h0`, `i0` | Individual file changes              |
| `bo`, `ch`, `us` | Branch short codes                   |
| `85:0`, `fd:1`   | File changes within specific commits |

These IDs are used as arguments to `but diff`, `but stage`, `but discard`, etc.
forbut extracts and passes these IDs transparently.

## Key Differences from git

1. **No staging area** — `but stage` assigns changes directly to branches
2. **Multiple active branches** — `but apply`/`but unapply` instead of `git checkout`
3. **Virtual branches** — branches are lightweight views, not HEAD pointers
4. **JSON output** — `but --json` / `but -j` for all commands (used for parsing)
5. **CLI IDs** — short codes for fast keyboard-driven workflows
