# forbut completions for bash

# When using forbut as a subcommand of git, put this file in one of the
# following places and it will be loaded automatically on tab completion of
# 'git forbut' or any configured git aliases of it:
#
#   /usr/share/bash-completion/completions
#   ~/.local/share/bash-completion/completions
#
# When using forbut via the shell plugin, source this file explicitly after
# forbut.sh to enable tab completion for shell functions and aliases.

# Completion for git-forbut
# This includes git aliases, e.g. "alias.fb=forbut diff" will correctly
# complete available diff targets on "git fb".
_git_forbut()
{
    local subcommand cword cur prev cmds

    subcommand="${COMP_WORDS[1]}"
    if [[ "$subcommand" != "forbut" ]]
    then
        # Forbut is called via a git alias. Get the original aliased subcommand
        # and proceed as if it was the previous word.
        prev=$(git config --get "alias.$subcommand" | cut -d' ' -f 2)
        cword=$((${COMP_CWORD} + 1))
    else
        cword=${COMP_CWORD}
        prev=${COMP_WORDS[COMP_CWORD-1]}
    fi

    cur=${COMP_WORDS[COMP_CWORD]}

    cmds="
        assign
        diff
        discard
        log
        reorder
        switch
    "

    case ${cword} in
        2)
            COMPREPLY=($(compgen -W "${cmds}" -- ${cur}))
            ;;
        3)
            case ${prev} in
                assign) ;;
                diff) _git_diff ;;
                discard) ;;
                log) ;;
                reorder) ;;
                switch) ;;
            esac
            ;;
        *)
            COMPREPLY=()
            ;;
    esac
}

# Check if forbut plugin is loaded
if [[ $(type -t forbut::switch) == function ]]
then
    # We're reusing existing git completion functions, so load those first
    # and check if completion function exists afterwards.
    _completion_loader git
    [[ $(type -t __git_complete) == function ]] || return 1

    # Completion for forbut plugin shell functions
    # Only diff takes a meaningful argument (optional diff target).
    __git_complete forbut::diff _git_diff

    # Completion for forbut plugin shell aliases
    if [[ -z "$FORBUT_NO_ALIASES" ]]; then
        __git_complete "${FORBUT_DIFF_ALIAS}" _git_diff
    fi
fi
