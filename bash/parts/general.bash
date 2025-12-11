#!/usr/bin/env bash

# Do not run homebrew clean up automatically. This will prevent old versions from being uninstalled.
export HOMEBREW_NO_INSTALL_CLEANUP=1

if [[ -d /opt/homebrew ]]; then
	# Eval this to get brew environment variables and completions working.
	# From https://apple.stackexchange.com/a/413207
	# Must be before adding homebrew bin/sbin as once those are added, this command will output nothing.
	eval $(/opt/homebrew/bin/brew shellenv)

	# Add homebrew to path.
	# But homebrew first so that brew installed stuff takes priority over built versions.
	export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
fi

if [[ -d /opt/homebrew/opt/imagemagick@6/bin ]]; then
	# Add imagemagick to path, if it exists.
	export PATH="/opt/homebrew/opt/imagemagick@6/bin:$PATH"
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

# Touch all time at a directory. Good for getting build tools to pick up changes.
touchFiles() {
	find "$1" -type f -exec touch {} +
}

# Takes piped in input and echos to stdout and copies to clipboard
copyEcho() {
	tee /dev/tty | pbcopy
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
