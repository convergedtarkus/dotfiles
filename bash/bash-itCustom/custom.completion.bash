#!/usr/bin/env bash

if [[ -z $MYDOTFILES ]]; then
	return
fi

if [[ -f "$MYDOTFILES/bash/combinedBashCompletions.bash" ]]; then
	# shellcheck source=/dev/null
	source "$MYDOTFILES/bash/combinedBashCompletions.bash"
fi
