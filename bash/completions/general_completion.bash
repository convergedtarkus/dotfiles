#!/usr/bin/env bash

# Completes helper command arguments using Bash's list of known commands.
_completeKnownCommand() {
	local currentWord=${COMP_WORDS[COMP_CWORD]}

	# Do not override completion for the helper command name itself.
	if ((COMP_CWORD == 0)); then
		COMPREPLY=()
		return 0
	fi

	# `compgen -c` generates command-name completions from Bash's known commands.
	# `--` ends option parsing so the current word is always treated as completion input.
	mapfile -t COMPREPLY < <(compgen -c -- "$currentWord")
}

# `complete -F` tells Bash to call the named function to generate completions.
complete -F _completeKnownCommand resolveCommand _deleteNormalCommand asdfPath deleteAllCommand deleteAsdfCommand deleteCommand
