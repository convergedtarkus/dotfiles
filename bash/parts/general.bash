#!/usr/bin/env bash

# Do not run homebrew clean up automatically. This will prevent old versions from being uninstalled.
export HOMEBREW_NO_INSTALL_CLEANUP=1

if [[ -d /opt/homebrew ]]; then
	# Add homebrew to path.
	# But homebrew first so that brew installed stuff takes priority over built versions.
	export PATH="/opt/homebrew/bin:$PATH"
fi

if [[ -d /opt/homebrew/opt/imagemagick@6/bin ]]; then
	# Add imagemagick to path, if it exists.
	export PATH="/opt/homebrew/opt/imagemagick@6/bin:$PATH"
fi

# Source the asdf script.
if [[ -f /usr/local/opt/asdf/asdf.sh ]]; then
	source /usr/local/opt/asdf/asdf.sh
elif [[ -f /opt/homebrew/opt/asdf/libexec/asdf.sh ]]; then
	source /opt/homebrew/opt/asdf/libexec/asdf.sh
fi

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

# Touch all time at a directory. Good for getting build tools to pick up changes.
touchFiles() {
	find "$1" -type f -exec touch {} +
}

# Takes piped in input and echos to stdout and copies to clipboard
copyEcho() {
	tee /dev/tty | pbcopy
}

# Runs a given command in bash with the x flag for debug output.
# This does not work if the command is a script (or calls one). Use
# bash -x path/to/script in that case.
debugBash() {
	set -x
	eval "$@"
	set +x
}

checkScript() {
	shfmt -w "$1" && shellcheck "$1"
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
		if [[ "$exitCode" == 0 ]]; then
			echo "top killed after waiting $secondsWaited seconds. Will wait $secondsToWait seconds more."
			# A top process was killed, reset the waited time.
			secondsWaited=0
		elif [[ "$exitCode" == 1 ]]; then
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
