#!/usr/bin/env bash

# This allows working with the bare clone of this repo under .myconfig. See Readme for more.
alias myconfig='git --git-dir=$HOME/.myconfig/ --work-tree=$HOME'

# Returns the path to a file in the current dotfiles repo.
# The given path should be relative to the directory this command is run in.
#
_dotFilesPath() {
	if [[ -z $1 ]]; then
		echoRed "No script name given"
		return 1
	fi

	local curDir
	if ! curDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || [[ -z $curDir ]]; then
		echoRed "Cannot resolve current directory to get path to dot files"
		return 1
	fi
	readonly curDir

	local targetPath="$curDir/$1"
	if ! targetPath="$(realpath "$targetPath" 2>/dev/null)" || [[ -z $targetPath ]]; then
		echoRed "Cannot resolve input relative path of '$1'"
		return 1
	fi

	if [[ -e $targetPath ]]; then
		echo "$targetPath"
	else
		echoRed "Cannot find '$1' script at current dir of '$curDir."
		return 1
	fi
}

# Runs the given file in the current dotfiles repo.
# First argument is the relative path to the script, any additional arguments are passed to the script.
# The given path should be relative to the directory this command is run in.
_runScript() {
	local -r relativeScriptPath="$1"
	if [[ -z $relativeScriptPath ]]; then
		echoRed "No script name given"
		return 1
	fi
	if scriptPath=$(_dotFilesPath "$relativeScriptPath"); then
		if [[ ! -f $scriptPath ]]; then
			echoRed "Script '$scriptPath' is not a file"
			return 1
		fi
		"$scriptPath" "${@:2}"
	else
		return 1
	fi
}

# Sources the given file in the current dotfiles repo.
# The given path should be relative to the directory this command is run in.
_sourceScript() {
	local -r relativeScriptPath="$1"
	if [[ -z $relativeScriptPath ]]; then
		echoRed "No script name given"
		return 1
	fi
	if scriptPath=$(_dotFilesPath "$relativeScriptPath"); then
		if [[ ! -f $scriptPath ]]; then
			echoRed "Script '$scriptPath' is not a file"
			return 1
		fi
		source "$scriptPath"
	else
		return 1
	fi
}

# Bash modifications
# shellcheck source=/dev/null
_sourceScript "/parts/bashCompability.bash"

# Color printing and echo for logging. Used by other scripts.
# shellcheck source=/dev/null
_sourceScript "/parts/colorPrint.bash"

# General aliases/functions. This also includes things shared by other scripts.
# shellcheck source=/dev/null
_sourceScript "/parts/general.bash"

# Docker
# shellcheck source=/dev/null
_sourceScript "/parts/docker.bash"

# Git
# shellcheck source=/dev/null
_sourceScript "/parts/git.bash"

# Dartlang and pub
# shellcheck source=/dev/null
_sourceScript "/parts/dartAndPub.bash"

# Golang
# shellcheck source=/dev/null
_sourceScript "/parts/go.bash"

# No support for linux yet, should at least not source this if on linux
# shellcheck source=/dev/null
if [[ "$(uname)" == "Darwin" ]]; then
	_sourceScript "/parts/osx.bash"
fi

# Find any custom files under ./custom (other than .keep) and source them
# This allows loading external files depending on the local machine.
if customDir="$(_dotFilesPath "../custom/")" && [[ -d $customDir ]]; then
	for file in "$customDir/"*; do
		if [[ -f $file ]]; then
			# shellcheck source=/dev/null
			source "$file"
		fi
	done
fi
