#!/usr/bin/env bash

if [[ -z $MYDOTFILES ]]; then
	return
fi

if [[ -f "$MYDOTFILES/bash/combinedBash.bash" ]]; then
	# shellcheck source=/dev/null
	source "$MYDOTFILES/bash/combinedBash.bash"
fi
