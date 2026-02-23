#!/usr/bin/env bash

# This allows working with the bare clone of this repo under .myconfig. See Readme for more.
alias myconfig='git --git-dir=$HOME/.myconfig/ --work-tree=$HOME'

# Bash modifications
# shellcheck source=/dev/null
source "$MYDOTFILES/bash/parts/bashCompability.bash"

# Docker
# shellcheck source=/dev/null
source "$MYDOTFILES/bash/parts/docker.bash"

# General aliases/functions
# shellcheck source=/dev/null
source "$MYDOTFILES/bash/parts/general.bash"

# Git
# shellcheck source=/dev/null
source "$MYDOTFILES/bash/parts/git.bash"
source "$MYDOTFILES/bash/completions/git_completion.bash"

# Dartlang and pub
# shellcheck source=/dev/null
source "$MYDOTFILES/bash/parts/dartAndPub.bash"
source "$MYDOTFILES/bash/completions/dartAndPub_completion.bash"

# Golang
# shellcheck source=/dev/null
source "$MYDOTFILES/bash/parts/go.bash"
source "$MYDOTFILES/bash/completions/go_completion.bash"

# No support for linux yet, should at least not source this if on linux
# shellcheck source=/dev/null
source "$MYDOTFILES/bash/parts/osSpecific/osx.bash"

# Find any custom files under ./custom (other than .keep) and source them
# This allows loading external files depending on the local machine.
if [[ -d "$MYDOTFILES/custom" ]]; then
	for file in "$MYDOTFILES"/custom/*; do
		if [[ -e "$file" ]]; then
			# shellcheck source=/dev/null
			source "$file"
		fi
	done
fi
