#!/usr/bin/env bash

# This file is loaded almost immediately from .bashrc.
# Put core environment configuration elements in here.

# Add the dotfilesbin to the PATH. It is added as the last option so it is the
# fallback option. The final cleanPath call will ensure it is the last entry
# in the path, even if other things get added after it during the loading process.
if [[ -d "$HOME/dotfilesbin/" ]]; then
	export PATH="$PATH:"$HOME/dotfilesbin/""
fi

# Need to load this right away as bash-it will try to use brew for bash completion (and potentially other things).
if [[ -f /opt/homebrew/bin/brew ]]; then
	# Eval this to get brew environment variables and completions working.
	# From https://apple.stackexchange.com/a/413207
	# Must be before adding homebrew bin/sbin as once those are added, this command will output nothing.
	# This handles adding homebrew to the PATH
	eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Add asdf shims directroy to path
if [[ -d ${ASDF_DATA_DIR:-$HOME/.asdf} ]]; then
	export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
	# Add asdf completions
	. <(asdf completion bash)
fi
