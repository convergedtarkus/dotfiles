#!/usr/bin/env bash

# Do not run homebrew clean up automatically. This will prevent old versions from being uninstalled.
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Add .local/bin which is used for cursor.
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
		echoYellow "Cannot find a man or help page for '$1'"
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
		-o avoid-negated-conditions,avoid-nullary-conditions,deprecate-which,require-double-brackets,useless-use-of-cat \
		--color=always \
		"$@" |
		sed -E 's#In (.\/)?(.*) line ([0-9]+):#In ./\2:\3:#'
}

# Format and check a script with shfmt and shellcheck.
checkScript() {
	# Iterate over arguments and verify a file is found.
	local returnCode
	local foundFile
	for arg in "$@"; do
		if [[ $arg == ^- ]]; then
			continue
		fi
		if [[ ! -f $arg ]]; then
			echoYellow "'$arg' cannot be found."
			returnCode=1
		else
			foundFile="yes"
		fi
	done

	if [[ -z $foundFile || -n $returnCode ]]; then
		echoRed "No valid files passed in."
		return 1
	fi

	if ! command -v shfmt >/dev/null || ! shfmt --help &>/dev/null; then
		if command -v installShfmt; then
			installShfmt
		fi
		if ! command -v shfmt >/dev/null || ! shfmt --help &>/dev/null; then
			echoRed "shfmt is not installed!"
			return 1
		fi
	fi

	if ! command -v shellcheck >/dev/null; then
		echoRed "shellcheck is not installed!"
		return 1
	fi

	# Write and simplify.
	shfmt -w -s "$@"
	shellcheck "$@"
}

checkInternet() {
	ping -i 2 8.8.8.8 --apple-time
}

# Echo the PATH with each entry on a line.
echoPATH() {
	echo "$PATH" | tr ':' '\n'
}

# Removes duplicate and nonexistent entries in the user's PATH. Maintains order.
# For duplicate entries, the first is kept.
cleanPath() {
	# Add the dotfilesbin to the PATH. It is added as the last option so it is the
	# fallback option. Adding it in cleanPath ensures it is always last.
	if [[ -d "$HOME/dotfilesbin/" ]]; then
		export PATH="$PATH:"$HOME/dotfilesbin/""
	fi

	declare newPath=()

	while IFS= read -r pathLine; do
		# Only put in paths that exist.
		if [[ -e $pathLine ]]; then
			newPath+=("$pathLine")
		fi
	done <<<"$(echo "$PATH" | tr ':' '\n' | uniq)"

	# Convert the newPath into a PATH string (separated by :)
	declare updatedPath
	updatedPath=$(
		IFS=':'
		echo "${newPath[*]}"
	)
	export PATH="$updatedPath"
}
