#!/usr/bin/env bash

if completionsDir="$(_dotFilesPath "./completions")" && [[ -d $completionsDir ]]; then
	# Iterate over all bash files in the completions directory and source them.
	for file in "$completionsDir/"*.bash; do
		if [[ -f $file ]]; then
			if [[ $file == "osx_completion.bash" && "$(uname)" != "Darwin" ]]; then
				continue
			fi

			# shellcheck source=/dev/null
			source "$file"
		fi
	done
fi
