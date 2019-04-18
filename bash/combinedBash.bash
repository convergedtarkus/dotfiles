#!/usr/bin/env bash

# This allows working with the bare clone of this repo under .myconfig. See Readme for more.
alias myconfig='git --git-dir=$HOME/.myconfig/ --work-tree=$HOME'

# Bash modifications
# shellcheck source=/dev/null
source "$MYDOTFILES/bash/parts/bashCompability.bash"

# Dartlang and pub
# shellcheck source=/dev/null
source "$MYDOTFILES/bash/parts/dartAndPub.bash"

# Docker
# shellcheck source=/dev/null
source "$MYDOTFILES/bash/parts/docker.bash"

# General aliases/functions
# shellcheck source=/dev/null
source "$MYDOTFILES/bash/parts/general.bash"

# Git
# shellcheck source=/dev/null
source "$MYDOTFILES/bash/parts/git.bash"

# Golang
# shellcheck source=/dev/null
source "$MYDOTFILES/bash/parts/go.bash"

# No support for linux yet, should at least not source this if on linux
# shellcheck source=/dev/null
source "$MYDOTFILES/bash/parts/osSpecific/osx.bash"

# Find any custom files under ./custom (other than .keep) and source them
customFiles=$(find "$MYDOTFILES/custom" ! -type d ! -name "*.keep")
while read -r customFile; do
	# shellcheck source=/dev/null
	source "$customFile"
done <<<"$customFiles"
