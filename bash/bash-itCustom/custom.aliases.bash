#!/usr/bin/env bash

if [[ -n $LOG_DOTFILES_LOAD ]]; then echo "!!!! DOTFILES: Loading custom.aliases.bash"; fi

if [[ -z $MYDOTFILES ]]; then
	return
fi

if [[ -f "$MYDOTFILES/bash/combinedBash.bash" ]]; then
	# shellcheck source=/dev/null
	source "$MYDOTFILES/bash/combinedBash.bash"
fi
