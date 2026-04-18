#!/usr/bin/env bash
# cmds/reorder.sh — forbut::reorder (v0.2 stub)
# Interactively reorder commits within a stack.
#
# Maps to: but move
# Forgit equivalent: forgit::rebase (loosely — see forgit/cmds/rebase.sh)
#
# This command is planned for v0.2 and is currently a stub.
#
# Function ordering: stub only. When implemented in v0.2 it will follow
# the forgit/cmds/rebase.sh layout — single _forbut_reorder entry, with
# any helpers (e.g. _forbut_reorder_preview) placed above it.

_forbut_reorder() {
    _forbut_warn "forbut::reorder is planned for v0.2 and is not yet implemented."
    _forbut_info "In the meantime, use 'but move' directly to reorder commits."
    _forbut_info "See: but move --help"
    return 1
}
