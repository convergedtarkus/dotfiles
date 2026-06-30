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

# Clear terminal lines.
alias c='clear'

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
alias man="\
LESS_TERMCAP_mb=$'\e[1;32m' \
LESS_TERMCAP_md=$'\e[1;32m' LESS_TERMCAP_me=$'\e[0m' \
LESS_TERMCAP_se=$'\e[0m'    LESS_TERMCAP_so=$'\e[7;1m' \
LESS_TERMCAP_ue=$'\e[0m'    LESS_TERMCAP_us=$'\e[1;4;31m' \
LESS=--RAW-CONTROL-CHARS \man"

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

# Removes the given command. Takes asdf into account.
# Will echo information about the command being removed (if removing, if not found, if protected etc)
deleteCommand() {
	for commandToDelete in "$@"; do
		_deleteNormalCommand "$commandToDelete"

		local asdfCommandPath
		if asdfCommandPath="$(asdfPath "$commandToDelete")" && [[ -n $asdfCommandPath ]]; then
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
	if ! commandPath="$(command -v "$commandToDelete")" || [[ -z $commandPath ]]; then
		echo "Not deleting $commandToDelete as it does not exist."
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

# Touch all time at a directory. Good for getting build tools to pick up changes.
touchFiles() {
	find "$1" -type f -exec touch {} +
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

killTop() {
	sudo killall top
}

murderTop() {
	secondsWaited=0
	secondsToWait=10

	while ((secondsWaited < secondsToWait)); do
		killTop &>/dev/null
		exitCode="$?"
		if [[ $exitCode == 0 ]]; then
			echo "top killed after waiting $secondsWaited seconds. Will wait $secondsToWait seconds more."
			# A top process was killed, reset the waited time.
			secondsWaited=0
		elif [[ $exitCode == 1 ]]; then
			# No top process was found, increment the waited time and wait one second.
			((secondsWaited++))
			sleep 1
		else
			# Unknown exit code, abort.
			echo "killall returned an unknown exit code of '$exitCode'"
			return 1
		fi
	done

	echo "No top process has run in $secondsWaited seconds. Ending murder process."
}
