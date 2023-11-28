#!/usr/bin/env bash

# Get the scripts directory (https://stackoverflow.com/questions/59895/get-the-source-directory-of-a-bash-script-from-within-the-script-itself)
# This is use by the bash-it submodule to load the bash/combinedBash.bash
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
export MYDOTFILES="$scriptDir"

if [ -d "$HOME/.bash-it" ]; then
	# Path to the bash it configuration
	export BASH_IT="$HOME/.bash-it"

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
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
