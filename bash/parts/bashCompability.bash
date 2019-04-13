# Better bash completion for environment variables
# https://askubuntu.com/questions/41891/bash-auto-complete-for-environment-variables
if ((BASH_VERSINFO[0] >= 4)) && ((BASH_VERSINFO[1] >= 2)); then
	shopt -s direxpand
fi
