#!/usr/bin/env bash

# Load after aliases so custom.aliases is loaded first.
# BASH_IT_LOAD_PRIORITY: 751

if [[ -n $LOG_DOTFILES_LOAD ]]; then echo "!!!! DOTFILES: Loading custom.completion.bash"; fi

if [[ -z $MYDOTFILES ]]; then
	return
fi

if [[ -f "$MYDOTFILES/bash/combinedBashCompletions.bash" ]]; then
	# shellcheck source=/dev/null
	source "$MYDOTFILES/bash/combinedBashCompletions.bash"
fi
