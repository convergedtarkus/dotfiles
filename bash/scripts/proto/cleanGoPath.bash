#!/usr/bin/env bash

# Produces a string to remove any packages in your $GOPATH
# The variables `cleanGoPathDomainProtected` and `cleanGoPathGithubUserProtected` can be
# populated with inputs to a find command to ignore certain paths for deletion.

# Usage
# Just run the script, no parameters are needed by default. See --help for parameter details.
# Make sure to populate `cleanGoPathDomainProtected` and `cleanGoPathGithubUserProtected` with
# protected paths.
# By default the command to delete pacakges is copied to the clipboard and logged to stdout.
# --no-copy and -a changes this behavior (see --help).

# TODOs
# Better ignore handling
#   Have only one variable and parse it to ignore any paths
#   Make it not need to care about the underlying command used
# Walk the whole $GOPATH better
#   Current setup is too specific to my current setup, make it more generic
# Handle copy on Linux (and non-Mac in general)

### Arg bash stuff starts here
#
# This is a rather minimal example Argbash potential
# Example taken from http://argbash.readthedocs.io/en/stable/example.html
#
# ARG_OPTIONAL_BOOLEAN([autorun],[a],[If supplied, run the delete command automatically, otherwise it will just be logged/copied.])
# ARG_OPTIONAL_BOOLEAN([copy],[c],[If supplied, the delete command will not be copied to the clipboard.],[on])
# ARG_OPTIONAL_BOOLEAN([force],[f],[If supplied, the delete command will be run with -f (rm -rf).],[on])
# ARG_HELP([The general script's help msg])
# ARGBASH_GO()
# needed because of Argbash --> m4_ignore([
### START OF CODE GENERATED BY Argbash v2.6.1 one line above ###
# Argbash is a bash code generator used to get arguments parsing right.
# Argbash is FREE SOFTWARE, see https://argbash.io for more info
# Generated online by https://argbash.io/generate

die() {
	local _ret=$2
	test -n "$_ret" || _ret=1
	test "$_PRINT_HELP" = yes && print_help >&2
	echo "$1" >&2
	exit ${_ret}
}

begins_with_short_option() {
	local first_option all_short_options
	all_short_options='acfh'
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# THE DEFAULTS INITIALIZATION - OPTIONALS
_arg_autorun="off"
_arg_copy="on"
_arg_force="on"

print_help() {
	printf '%s\n' "The general script's help msg"
	printf 'Usage: %s [-a|--(no-)autorun] [-c|--(no-)copy] [-f|--(no-)force] [-h|--help]\n' "$0"
	printf '\t%s\n' "-a,--autorun,--no-autorun: If supplied, run the delete command automatically, otherwise it will just be logged/copied. (off by default)"
	printf '\t%s\n' "-c,--copy,--no-copy: If supplied, the delete command will not be copied to the clipboard. (on by default)"
	printf '\t%s\n' "-f,--force,--no-force: If supplied, the delete command will be run with -f (rm -rf). (on by default)"
	printf '\t%s\n' "-h,--help: Prints help"
}

parse_commandline() {
	while test $# -gt 0; do
		_key="$1"
		case "$_key" in
		-a | --no-autorun | --autorun)
			_arg_autorun="on"
			test "${1:0:5}" = "--no-" && _arg_autorun="off"
			;;
		-a*)
			_arg_autorun="on"
			_next="${_key##-a}"
			if test -n "$_next" -a "$_next" != "$_key"; then
				begins_with_short_option "$_next" && shift && set -- "-a" "-${_next}" "$@" || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
			fi
			;;
		-c | --no-copy | --copy)
			_arg_copy="on"
			test "${1:0:5}" = "--no-" && _arg_copy="off"
			;;
		-c*)
			_arg_copy="on"
			_next="${_key##-c}"
			if test -n "$_next" -a "$_next" != "$_key"; then
				begins_with_short_option "$_next" && shift && set -- "-c" "-${_next}" "$@" || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
			fi
			;;
		-f | --no-force | --force)
			_arg_force="on"
			test "${1:0:5}" = "--no-" && _arg_force="off"
			;;
		-f*)
			_arg_force="on"
			_next="${_key##-f}"
			if test -n "$_next" -a "$_next" != "$_key"; then
				begins_with_short_option "$_next" && shift && set -- "-f" "-${_next}" "$@" || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
			fi
			;;
		-h | --help)
			print_help
			exit 0
			;;
		-h*)
			print_help
			exit 0
			;;
		*)
			_PRINT_HELP=yes die "FATAL ERROR: Got an unexpected argument '$1'" 1
			;;
		esac
		shift
	done
}

parse_commandline "$@"

# OTHER STUFF GENERATED BY Argbash

### Script logic starts here

_allPackagesProto() {
	protected="github.com/convergedtarkus github.com/Workiva github.com/gopherjs"
	protected="${protected// /$'\n'}" 	

	pathsToRemove=$(eval "find $GOPATH/src -type d -mindepth 3 -maxdepth 3 ! -path '*/\.*'")

	while read -r protectedPath; do
		# '\#' defines '#' as the separator. Delete lines matching $protectedPath
		pathsToRemove=$(echo "$pathsToRemove" | sed "\#^$GOPATH/src/$protectedPath.*#d")
	done <<<"$protected"

	echo "Paths to remove are:"
	echo "$pathsToRemove"
	echo
}


# Takes an input of newline separated paths and echos them out one by one indented once each.
_logToRemove() {
	toRemove="$1"
	prettyToRemove=$'\n'
	while read -r line; do
		prettyToRemove+=$'\t'
		prettyToRemove+=$(_prettyPrintGoPackagePath "$line")
		prettyToRemove="$prettyToRemove"$'\n'
	done <<<"$toRemove"

	echo "$prettyToRemove"
}

# Removes $GOPATH/sec/ from a path inside GOPATH.
_prettyPrintGoPackagePath() {
	echo "$1" | sed "s|$GOPATH/src/||g"
}

echo "$(_allPackagesProto)"
echo

domainFoldersToRemove=$(eval "find $GOPATH/src -type d -mindepth 1 -maxdepth 1 $cleanGoPathDomainProtected")

githubUsersToRemove=$(eval "find $GOPATH/src/github.com -type d -mindepth 1 -maxdepth 1 $cleanGoPathGithubUserProtected")

removalString=""
if [[ "$domainFoldersToRemove" != "" ]]; then
	echo "Domain folders to remove: $(_logToRemove "$domainFoldersToRemove")"
	# Replace newlines with spaces for the removal string
	domainFoldersToRemove=$(echo "$domainFoldersToRemove" | tr '\n' ' ')
	removalString=$(printf "%s%s" "$removalString" "$domainFoldersToRemove")
else
	echo "No domain folders would be removed"
fi
echo

if [[ "$githubUsersToRemove" != "" ]]; then
	echo "Github user folders to remove: $(_logToRemove "$githubUsersToRemove")"
	# Replace newlines with spaces for the removal string
	githubUsersToRemove=$(echo "$githubUsersToRemove" | tr '\n' ' ')
	removalString=$(printf "%s%s" "$removalString" "$githubUsersToRemove")
else
	echo "No github user folders would be removed"
fi
echo

if [[ "$removalString" != "" ]]; then
	removalString=$(echo "$removalString" | tr '\n' ' ')
	cleanCommand="rm -r"
	if [[ $_arg_force == "on" ]]; then
		cleanCommand="${cleanCommand}f"
	fi
	cleanCommand="$cleanCommand $removalString"

	echo
	if [[ $_arg_autorun == "on" ]]; then
		echo "Auto running command to clean go path, will log command next"
		echo "'$cleanCommand'"
		eval "$cleanCommand"
	else
		copyMessage=""
		if [[ $_arg_copy == "on" ]]; then
			copyMessage=" (copied to clipboard)"
			echo "$cleanCommand" | tr -d '\n' | pbcopy
		fi
		echo "Run this command to delete clean your go path $copyMessage"
		echo "$cleanCommand"
	fi

else
	echo "Go path is already clean!"
	exit 0
fi
