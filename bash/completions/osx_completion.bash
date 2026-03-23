#!/usr/bin/env bash

# Check if we're on Mac OS X before defining any of these aliases or functions.
if [[ "$(uname)" != "Darwin" ]]; then
	return
fi

_completeManagedPassword() {
	local currentWord=${COMP_WORDS[COMP_CWORD]}
	# Use compgen to filter the array and populate COMPREPLY
	# shellcheck disable=SC2154 # _managedPasswords is declared in osx.bash
	mapfile -t COMPREPLY < <(compgen -W "${_managedPasswords[*]}" -- "$currentWord")
}

complete -F _completeManagedPassword getGenericPassword doesGenericPasswordExist updateGenericPassword removeGenericPassword
