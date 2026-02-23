#!/usr/bin/env bash

if [[ -z "$MYDOTFILES" ]]; then
	return
fi

if [[ -d "$MYDOTFILES/bash/completions/" ]]; then
	# Iterate over all bash files in the completions directory and source them.
	for file in "$MYDOTFILES/bash/completions/"*.bash; do
		if [[ -f "$file" ]]; then
			# shellcheck source=/dev/null
			source "$file"
		fi
	done
fi
