#!/usr/bin/env bash

# Do not run homebrew clean up automatically. This will prevent old versions from being uninstalled.
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Source the asdf script.
source /usr/local/opt/asdf/asdf.sh

# For whatever reason, Sophos keeps overwritting permissions for man8, so this quickly reclaims permissions.
# This command was taken directly from the brew help message.
alias ownMan8='sudo chown -R $(whoami) /usr/local/share/man/man8'

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
