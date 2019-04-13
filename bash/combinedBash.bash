# Get the scripts directory (https://stackoverflow.com/questions/59895/get-the-source-directory-of-a-bash-script-from-within-the-script-itself)
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# This allows working with the bare clone of this repo under .myconfig. See Readme for more.
alias myconfig="/usr/bin/git --git-dir=$HOME/.myconfig/ --work-tree=$HOME"

# Bash modifications
source "$scriptDir/parts/bashCompability.bash"

# Dartlang and pub
source "$scriptDir/parts/dartAndPub.bash"

# Docker
source "$scriptDir/parts/docker.bash"

# General aliases/functions
source "$scriptDir/parts/general.bash"

# Git
source "$scriptDir/parts/git.bash"

# Golang
source "$scriptDir/parts/go.bash"

# No support for linux yet, should at least not source this if on linux
source "$scriptDir/parts/osSpecific/osx.bash"

# This can be used to load a custom file in addition to these. Good for
# sensative things that should not be in a public repo. Set in your
# system bash profile (normally /etc/profile).
if [[ ! -z "$ADDITIONAL_BASH_PART" ]]; then
	source "$ADDITIONAL_BASH_PART"
fi
