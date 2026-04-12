#
# forbut completions for fish
#
# Place this file inside your <fish_config_dir>/completions/ directory.
# It's usually located at ~/.config/fish/completions/. The file is lazily
# sourced when git-forbut command or forbut subcommand of git is invoked.

function __fish_forbut_needs_subcommand
    for subcmd in assign diff discard log reorder switch
        if contains -- $subcmd (commandline -opc)
            return 1
        end
    end
    return 0
end

# Load helper functions in git completion file
not functions -q __fish_git && source $__fish_data_dir/completions/git.fish

# No file completion by default
complete -c git-forbut -x

complete -c git-forbut -n __fish_forbut_needs_subcommand -a assign  -d 'fuzzy-assign uncommitted hunks to a stack'
complete -c git-forbut -n __fish_forbut_needs_subcommand -a diff    -d 'browse changed files with diff preview'
complete -c git-forbut -n __fish_forbut_needs_subcommand -a discard -d 'fuzzy-discard hunks or files'
complete -c git-forbut -n __fish_forbut_needs_subcommand -a log     -d 'browse commit log across current stack'
complete -c git-forbut -n __fish_forbut_needs_subcommand -a reorder -d 'interactively reorder commits within a stack'
complete -c git-forbut -n __fish_forbut_needs_subcommand -a switch  -d 'fuzzy-switch between virtual branches'

complete -c git-forbut -n '__fish_seen_subcommand_from diff' -a "(complete -C 'git diff ')"
