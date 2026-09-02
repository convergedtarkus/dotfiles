#!/usr/bin/env bash

# Get the scripts directory (https://stackoverflow.com/questions/59895/get-the-source-directory-of-a-bash-script-from-within-the-script-itself)
# This is use by the bash-it submodule to load the bash/combinedBash.bash
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
export MYDOTFILES="$scriptDir"

if [[ -f "$MYDOTFILES/bash/coreEnvironment.bash" ]]; then
	source "$MYDOTFILES/bash/coreEnvironment.bash"
else
	printf "%b%s%b\n" "\033[0;31m" "Cannot find core environment!" "\033[0m"
	echo ""
fi

if [[ -d "$HOME/.bash-it" && -f "$HOME/.bash-it/bash_it.sh" ]]; then
	# Path to the bash it configuration
	export BASH_IT="$HOME/.bash-it"

	# Ensure custom alias file is added.
	if [[ -f $MYDOTFILES/bash/bash-itCustom/custom.aliases.bash ]]; then
		# Check if there is already a custom alias file and only copy if they are different.
		if [[ ! -f $BASH_IT/aliases/available/custom.aliases.bash ]] ||
			! cmp -s "$BASH_IT/aliases/available/custom.aliases.bash" "$MYDOTFILES/bash/bash-itCustom/custom.aliases.bash"; then
			cp "$MYDOTFILES/bash/bash-itCustom/custom.aliases.bash" "$BASH_IT/aliases/available/"
		fi
	fi

	# Ensure custom completion file is added.
	if [[ -f $MYDOTFILES/bash/bash-itCustom/custom.completion.bash ]]; then
		# Check if there is already a custom completion file and only copy if they are different.
		if [[ ! -f $BASH_IT/completion/available/custom.completion.bash ]] ||
			! cmp -s "$BASH_IT/completion/available/custom.completion.bash" "$MYDOTFILES/bash/bash-itCustom/custom.completion.bash"; then
			cp "$MYDOTFILES/bash/bash-itCustom/custom.completion.bash" "$BASH_IT/completion/available/"
		fi
	fi

	# Lock and Load a custom theme file
	# location /.bash_it/themes/
	export BASH_IT_THEME='sexy'

	# Don't check mail when opening terminal.
	unset MAILCHECK

	# Set this to false to turn off version control status checking within the prompt for all themes
	export SCM_CHECK=true

	# Load Bash It (and don't care that shellcheck cannot check this file)
	# shellcheck source=/dev/null
	source "$BASH_IT"/bash_it.sh
else
	# Just use my base bash info
	# shellcheck source=/dev/null
	source "$MYDOTFILES/bash/combinedBash.bash"
	source "$MYDOTFILES/bash/combinedBashCompletions.bash"
fi

# Clean the path as the final action.
if command -v cleanPath >/dev/null; then
	cleanPath
fi
