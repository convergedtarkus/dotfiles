# Replace this with the path to the bashrc repo, used for finding scripts
export MYDEVPROFILE=~/myProjects/bashrc

# Many of these were copied or inspired from bash-it general.aliases.bash and base.plugin.bash
# reload everything
alias reload="source ~/.bash_profile"

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
alias findNotHidden="find . -not -path '*/\.*'"

# Touch all time at a directory. Good for getting build tools to pick up changes.
function touchFiles() {
	find $1 -type f -exec touch {} +
}

# Takes piped in input and echos to stdout and copies to clipboard
function copyEcho() {
	read value
	echo "$value" | pbcopy
	echo "$value"
}
