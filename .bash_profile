#!/usr/bin/env bash

if [[ -n $LOG_DOTFILES_LOAD ]]; then echo "!!!! DOTFILES: Loading .bash_profile"; fi

# This (.bash_profile) is run for all login shells while .bashrc is
# used for non-login shells (in MacOS basically all shells are login
# sells). This means launching a terminal from vim (`term`) uses .bashrc
# but it doesn't get sourced on vim startup (so no startup time impact).
if [[ -n $PS1 && -f "$HOME/.bashrc" ]]; then
	# shellcheck source=/dev/null
	source "$HOME/.bashrc"
fi
