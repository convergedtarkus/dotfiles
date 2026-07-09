#!/usr/bin/env bash

# Do not run homebrew clean up automatically. This will prevent old versions from being uninstalled.
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Add .local/bin which is used for claude code.
if [[ -d "$HOME/.local/bin" ]]; then
	export PATH="$HOME/.local/bin:$PATH"
fi

# Enable completions for github CLI
if command -v gh >/dev/null; then
	eval "$(gh completion -s bash)"
fi

# Stop direnv from logging when starting a terminal, changing directories etc.
export DIRENV_LOG_FORMAT=""

# Many of these were copied or inspired from bash-it general.aliases.bash and base.plugin.bash
# reload everything
alias reload='source ~/.bash_profile'

# Compact view, show colors, display symbols for ls.
alias ls='ls -GF'

# Helpers for ls.
alias l='ls -a'   # show hidden
alias ll='ls -al' # show hidden and list in long form

# Colored grep.
alias grep='grep --color=auto'
export GREP_COLOR='1;33'

# Quick navigation helpers.
alias ..='cd ..'         # Go up one directory
alias ...='cd ../..'     # Go up two directories
alias ....='cd ../../..' # Go up three directories
alias -- -='cd -'        # Go back

# Helper to find files that are not hidden.
alias findNotHidden='find . -not -path "*/\.*"'

# Taken from the bash-it man plugin but modified so search results are more readable.
# Colorize `man` output by setting `less` terminal capabilities for bold/underline/standout text,
# then force `less` to pass through ANSI escape sequences so those colors render correctly.
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[7;1m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'
export LESS="--RAW-CONTROL-CHARS"

# Redirect man to _findManPage
alias man="_findManPage"

# Routes to man or help for shell built-in commands.
_findManPage() {
	if [[ -z $1 ]]; then
		# Matches the behavior of calling man with no arguments.
		return
	fi

	# See if a man page exists and if it does not point to shell builtins.
	if manPage=$(command man -w "$1" 2>/dev/null) && [[ -n $manPage && $manPage != *builtin* ]]; then
		command man "$1"
		return
	fi

	if help "$1" &>/dev/null; then
		# Reroute to the shell help page for this command.
		help "$1" | less
	else
		echo "Cannot find a man or help page for '$1'"
	fi
}

# Takes piped in input and echos to stdout and copies to clipboard
copyEcho() {
	tee /dev/tty | pbcopy
}

# Use a more aggressive shellcheck.
# SC1090 = Can't follow non-constant source. Use a directive to specify location
#     Generally this is just noise that I have to add a directive to ignore, so ignore it by default.
# SC1091 = Not following: (error message here)
#     Same as above.
# Pipe to sed to convert the line number format so IDEs can link to the file and line number.
# This will run the shellcheck alias above.
# --color=always is needed to preserve the colors when piping to sed.
shellcheck() {
	# command causes shellcheck to be run literally rather than calling this function again.
	command shellcheck \
		-e SC1090,SC1091 \
		-o avoid-negated-conditions,avoid-nullary-conditions,check-set-e-suppressed,deprecate-which,require-double-brackets,useless-use-of-cat \
		--color=always \
		"$@" |
		sed -E 's#In (.\/)?(.*) line ([0-9]+):#In ./\2:\3:#'
}

# Format and check a script with shfmt and shellcheck.
checkScript() {
	if ! command -v shfmt >/dev/null || ! shfmt --help &>/dev/null; then
		if command -v installShfmt; then
			installShfmt
		fi
		if ! command -v shfmt >/dev/null || ! shfmt --help &>/dev/null; then
			printf "\033[31mshfmt is not installed!\033[0m\n"
			return 1
		fi
	fi

	if ! command -v shellcheck >/dev/null; then
		printf "\033[31mshellcheck is not installed!\033[0m\n"
		return 1
	fi

	# Iterate over arguments and verify a file is found.
	local foundFiles=()
	for arg in "$@"; do
		if [[ $arg != ^- ]]; then
			foundFiles+=("$arg")
		fi
	done

	if [[ ${#foundFiles[@]} -eq 0 ]]; then
		echo "No files found to check."
		return 1
	fi

	local returnCode
	for file in "${foundFiles[@]}"; do
		if [[ ! -f $file ]]; then
			echo "'$file' cannot be found."
			returnCode=1
		fi
	done

	if [[ -n $returnCode ]]; then
		return "$returnCode"
	fi

	# Write and simplify.
	shfmt -w -s "$@"
	shellcheck "$@"
}

checkInternet() {
	ping -i 2 8.8.8.8 --apple-time
}

# Resolves the path to a command. Takes asdf into account.
# Commands that do not resolve echo nothing (not even a newline)
resolveCommand() {
	local commandToCheck
	for commandToCheck in "$@"; do
		if asdfPath=$(asdfPath "$commandToCheck"); then
			echo "$asdfPath"
		else
			command -v "$commandToCheck"
		fi
	done
}

# Deletes the given commands. Will remove all asdf shim versions.
deleteAllCommand() {
	deleteAsdfCommand "$@"
	deleteCommand "$@"
}

# Returns the path to a command if it is installed via asdf.
# Will return a non-zero exit code for either a command not installed through asdf
# or a command installed through asdf but with no version set.
# Commands that do not resolve echo nothing (not even a newline)
asdfPath() {
	if ! command -v asdf >/dev/null; then
		# asdf does not exist
		return
	fi

	local commandToCheck
	for commandToCheck in "$@"; do
		# Reroute standard error to null so only the path is echoed, not the error.
		asdf which "$commandToCheck" 2>/dev/null
	done
}

# Deletes all the versions of the given command that are in asdf installed tools.
# For example `deleteAsdfCommand goimports` would delete all versions of goimports
# for all go versions installed by asdf as well as the main shim binary.
# Note, this uses asdf commands to find what to delete so if shims are out of date,
# not all binaries will be removed.
deleteAsdfCommand() {
	if ! command -v asdf >/dev/null; then
		# asdf does not exist, nothing to do.
		return
	fi

	asdfShimPath="${ASDF_DATA_DIR:-$HOME/.asdf}/shims"
	if [[ ! -d $asdfShimPath ]]; then
		echo "Cannot find asdf shim path"
		return
	fi

	for commandToDelete in "$@"; do
		local commandPath
		if ! commandPath=$(command -v "$commandToDelete") || [[ -z $commandPath ]] || [[ $(type -t "$commandToDelete") != "file" ]]; then
			continue
		fi

		if [[ ! $commandPath =~ $asdfShimPath ]]; then
			continue
		fi

		if ! shimVersions=$(asdf shimversions "$commandToDelete"); then
			echo "Cannot determine shim versions for '$commandToDelete"
			continue
		fi

		# Try to determine if the command to delete is a core plugin command.
		if ! plugins=$(asdf plugin list); then
			echo "Command '$commandToDelete' cannot resolve plugin names"
			continue
		fi

		if echo "$plugins" | grep -q "^$(_asdfCommandNameToPluginName "$commandToDelete")$"; then
			echo "Command '$commandToDelete' is a core plugin command. It will not be deleted from the plugin bin."
			continue
		fi

		while IFS= read -r shimLine; do
			if ! toolPath=$(eval "asdf where $shimLine") || [[ ! -d $toolPath ]]; then
				echo "For command '$commandToDelete' from '$shimLine', cannot determine tool path for shim version"
				continue
			fi

			toolBin="$toolPath/bin"
			if [[ ! -d $toolBin ]]; then
				echo "For command '$commandToDelete' from '$shimLine', cannot find tool bin for shim version"
			fi

			deletePath="$toolBin/$commandToDelete"
			if [[ -f $deletePath ]]; then
				echo "For command '$commandToDelete' from '$shimLine', deleting command from bin at '$deletePath'"
				rm "$deletePath"
			fi
		done <<<"$shimVersions"

		if [[ -f $commandPath ]]; then
			echo "For command '$commandToDelete', deleting root shim command at '$commandPath'"
			rm "$commandPath"
		fi
	done
}

# Takes in a command name and attempts to determine the plugin name.
# Echos the input if no conversion is found or known.
_asdfCommandNameToPluginName() {
	case "$1" in
	"go")
		echo "golang"
		;;
	"mvn")
		echo "maven"
		;;
	"node")
		echo "nodejs"
		;;
	*)
		echo "$1"
		;;
	esac
}

# Removes the given command. Takes asdf into account.
# Will echo information about the command being removed (if removing, if not found, if protected etc)
deleteCommand() {
	for commandToDelete in "$@"; do
		_deleteNormalCommand "$commandToDelete"

		local asdfCommandPath
		if asdfCommandPath="$(asdfPath "$commandToDelete")" && [[ -n $asdfCommandPath && -f $asdfCommandPath ]]; then
			echo "Removing command '$commandToDelete' installed through asdf at '$asdfCommandPath'"
			rm "$asdfCommandPath"
		fi

	done
}

# Removes the given command. Does not account for asdf. Protects system directories and brew.
# Will echo information about the command being removed (if removing, if not found, if protected etc)
_deleteNormalCommand() {
	local -r commandToDelete="$1"
	local commandPath
	if ! commandPath="$(command -v "$commandToDelete")" || [[ -z $commandPath || ! -f $commandPath || $(type -t "$commandToDelete") != "file" ]]; then
		return
	fi

	local commandDir
	if ! commandDir=$(dirname "$commandPath") || [[ ! -d $commandDir ]]; then
		echo "Not removing command '$commandToDelete' at '$commandPath' as command directory cannot be resolved."
		return
	fi

	local brewLocation
	if command -v brew >/dev/null; then
		brewLocation=$(brew --prefix)
	fi

	case "$commandDir" in
	"$brewLocation"*)
		echo "Not removing command '$commandToDelete' at '$commandPath' as command is installed through homebrew."
		;;
	"/usr"* | "/bin"* | "/sbin"* | "/System"* | "/Applications"* | "/opt"* | "/var"*)
		# Technically, /usr/local/bin might be safe to remove from but protect it for now.
		echo "Not removing command '$commandToDelete' at '$commandPath' as command is a system command."
		;;
	"$HOME/"*)
		echo "Removing command '$commandToDelete' at '$commandPath'"
		rm "$commandPath"
		;;
	*)
		echo "Not removing command '$commandToDelete' at '$commandPath' as it is in an unknown location."
		;;
	esac
}

# Removes duplicate and nonexistent entries in the user's PATH. Maintains order.
# For duplicate entries, the first is kept.
cleanPath() {
	declare newPath=()
	declare -A uniquePaths

	while IFS= read -r pathLine; do
		if [[ -v uniquePaths[$pathLine] ]]; then
			# Skip duplicate entries
			continue
		fi

		# Only put in paths that exist.
		if [[ -e $pathLine ]]; then
			uniquePaths[pathLine]="true"
			newPath+=("$pathLine")
		fi
	done <<<"$(echo "$PATH" | tr ':' '\n')"

	# Convert the newPath into a PATH string (separated by :)
	declare updatedPath
	updatedPath=$(
		IFS=':'
		echo "${newPath[*]}"
	)
	export PATH="$updatedPath"
}
