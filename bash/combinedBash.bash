#!/bin/bash

# Get the scripts directory (https://stackoverflow.com/questions/59895/get-the-source-directory-of-a-bash-script-from-within-the-script-itself)
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# This allows working with the bare clone of this repo under .myconfig. See Readme for more.
alias myconfig='/usr/bin/git --git-dir=$HOME/.myconfig/ --work-tree=$HOME'

# Bash modifications
# shellcheck source=/dev/null
source "$scriptDir/parts/bashCompability.bash"

# Dartlang and pub
# shellcheck source=/dev/null
source "$scriptDir/parts/dartAndPub.bash"

# Docker
# shellcheck source=/dev/null
source "$scriptDir/parts/docker.bash"

# General aliases/functions
# shellcheck source=/dev/null
source "$scriptDir/parts/general.bash"

# Git
# shellcheck source=/dev/null
source "$scriptDir/parts/git.bash"

# Golang
# shellcheck source=/dev/null
source "$scriptDir/parts/go.bash"

# No support for linux yet, should at least not source this if on linux
# shellcheck source=/dev/null
source "$scriptDir/parts/osSpecific/osx.bash"

# This can be used to load a custom file in addition to these. Good for
# sensative things that should not be in a public repo. Set in your
# system bash profile (normally /etc/profile).
if [[ -n "$ADDITIONAL_BASH_PART" ]]; then
	# shellcheck source=/dev/null
	source "$ADDITIONAL_BASH_PART"
fi
