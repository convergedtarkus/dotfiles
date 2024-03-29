#!/usr/bin/env bash

# Finds a dependency inside the vendor folder by the repro name, removes its vendor and symlinks to to a local copy of that dependency.
# If the dependency doesn't exit in vendor, has multiple possible options or a copy doesn't exist in the $GOPATH then nothing will happen
# Note that the search string is case sensitive
# Usage
# E.X. 'symlinkVendorPackage testify' would find 'vendor/github.com/stretchr/testify', remove it from vendor, and symlink to $GOPATH/src/github.com/stretchr/testify
# Large file paths may also be used and can help avoid the case where there are multiple options
# E.X. 'symlinkVendorPackage stretchr/testify' (or even 'symlinkVendorPackage github.com/stretchr/testify') would work even if there was another 'testify' directory under './vendor'

# TODO
#  - Detect existing symlink
#  - Dry run flag
#  - Break logic into functions

### Argbash code starts here, jump to 'ACTUAL SCRIPT STARTS HERE' to skip
#
# ARG_POSITIONAL_SINGLE([symlink-package],[The package to symlink into current project],[""])
# ARG_OPTIONAL_BOOLEAN([dual-dev],[],[Uses a different symlink approach that allows deving in both the current project and the project being symlinked in.])
# ARG_OPTIONAL_BOOLEAN([version],[v],[Print the scripts version])
# ARG_HELP([The general script's help msg])
# ARGBASH_GO()
# needed because of Argbash --> m4_ignore([
### START OF CODE GENERATED BY Argbash v2.8.1 one line above ###
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
	local first_option all_short_options='vh'
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# THE DEFAULTS INITIALIZATION - POSITIONALS
_positionals=()
_arg_symlink_package=""
# THE DEFAULTS INITIALIZATION - OPTIONALS
_arg_dual_dev="off"
_arg_version="off"

print_help() {
	printf '%s\n' "The general script's help msg"
	printf 'Usage: %s [--(no-)dual-dev] [-v|--(no-)version] [-h|--help] [<symlink-package>]\n' "$0"
	printf '\t%s\n' "<symlink-package>: The package to symlink into current project. Can be an absolute path, full import package name or a unique search string to find the package in GOPATH."
	printf '\t%s\n' "--dual-dev, --no-dual-dev: Uses a different symlink approach that allows deving in both the current project and the project being symlinked in. (off by default)"
	printf '\t%s\n' "-v, --version, --no-version: Print the scripts version (off by default)"
	printf '\t%s\n' "-h, --help: Prints help"
}

parse_commandline() {
	_positionals_count=0
	while test $# -gt 0; do
		_key="$1"
		case "$_key" in
		--no-dual-dev | --dual-dev)
			_arg_dual_dev="on"
			test "${1:0:5}" = "--no-" && _arg_dual_dev="off"
			;;
		-v | --no-version | --version)
			_arg_version="on"
			test "${1:0:5}" = "--no-" && _arg_version="off"
			;;
		-v*)
			_arg_version="on"
			_next="${_key##-v}"
			if test -n "$_next" -a "$_next" != "$_key"; then
				{ begins_with_short_option "$_next" && shift && set -- "-v" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
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
			_last_positional="$1"
			_positionals+=("$_last_positional")
			_positionals_count=$((_positionals_count + 1))
			;;
		esac
		shift
	done
}

handle_passed_args_count() {
	test "${_positionals_count}" -le 1 || _PRINT_HELP=yes die "FATAL ERROR: There were spurious positional arguments --- we expect between 0 and 1, but got ${_positionals_count} (the last one was: '${_last_positional}')." 1
}

assign_positional_args() {
	local _positional_name _shift_for=$1
	_positional_names="_arg_symlink_package "

	shift "$_shift_for"
	for _positional_name in ${_positional_names}; do
		test $# -gt 0 || break
		eval "$_positional_name=\${1}" || die "Error during argument parsing, possibly an Argbash bug." 1
		shift
	done
}

parse_commandline "$@"
handle_passed_args_count
assign_positional_args 1 "${_positionals[@]}"

# OTHER STUFF GENERATED BY Argbash
### END OF CODE GENERATED BY Argbash (sortof) ### ])
# [ <-- needed because of Argbash
# ] <-- needed because of Argbash
### ACTUAL SCRIPT STARTS HERE

# echos the number of lines in the input, treats an empty string as zero lines
# $1 is the input to check
_countLines() {
	if [[ $localDependencyPath == "" ]]; then
		echo "0"
	else
		echo "$localDependencyPath" | wc -l
	fi
}

# $1 = path to the vendor directory that needs to be backed up
_backupVendor() {
	vendorPath="$1"
	if [[ -d "$vendorPath"_bak ]]; then
		vendorNum=2
		while [[ -d "$vendorPath"_bak"$vendorNum" ]]; do
			((vendorNum++))
		done
	fi

	if [[ -n "$vendorNum" ]]; then
		echo "The vendor_bak directory already exists, backing up vendor to vendor_bak${vendorNum}"
	else
		echo "Moving the nested vendor directory to 'vendor_bak'"
	fi

	mv "$vendorPath" "${vendorPath}_bak${vendorNum}"
}

if [[ $_arg_version == "on" ]]; then
	echo "Version 6.2.0"
	exit
fi

# shellcheck disable=SC2154
# This is defined using some bash magic (I think, blame Argbash), but this variable is assigned.
if [[ -z $_arg_symlink_package ]]; then
	echo "FAILURE: No input for target package, please provide a package to symlink"
	exit 1
fi

if [[ ! -d vendor ]]; then
	echo "FAILURE: No vendor directory at current location, aborting"
	exit 1
fi

if [[ "$_arg_dual_dev" == "on" ]]; then
	echo "Using dual dev approach"
	echo
fi

# Remove trailing slash from input as that would fail to find anything.
_arg_symlink_package=${_arg_symlink_package%/}

# Look for the dependency in GOPATH first, this supports adding a new dependency into vendor if its not already in vendor.
# The maxdepth is since go packages should follow the pattern '$GOPATH/src/domain/user/repo' so only search down three directories to limit results.
# Setting mindepth prevents a case like 'github.com' from finding $GOPATH/src/github.com where it should find nothing.
localDependencyPath=$(find "$GOPATH/src" -mindepth 3 -maxdepth 3 -d -path "*$_arg_symlink_package" | grep -v /vendor/)

numResults=$(_countLines "$localDependencyPath")

if ((numResults == 0)); then
	echo "FAILURE: Package '$_arg_symlink_package' does not exist in GOPATH, aborting"
	exit 1
elif ((numResults != 1)); then
	echo "FAILURE: Found $numResults possible dependency hits in GOPATH, aborting"
	echo "Possible dependencies:"
	echo "$localDependencyPath"
	exit 1
fi

echo "Found package '$_arg_symlink_package' inside GOPATH at '$localDependencyPath'"

expectedVendorPath="./vendor"${localDependencyPath#$GOPATH/src}

# path matches against the whole path name
if [ ! -d "$expectedVendorPath" ]; then
	echo "Package '$_arg_symlink_package' does not currently exist in vendor, will symlink using path $expectedVendorPath"
else
	if [[ -L $expectedVendorPath ]]; then
		echo "Package '$_arg_symlink_package' is in vendor and appears to already be a symlink"
	else
		echo "Package '$_arg_symlink_package' is in vendor at $expectedVendorPath"
	fi
fi

echo
echo "Preparing to symlink '$_arg_symlink_package' into vendor from GOPATH"

if [[ "$_arg_dual_dev" == "on" ]]; then
	echo "ATTENTION: If you add or remove a file/directory at the root level of the package being symlinked in, you will need to re-run the symlink script!"
else
	if [ -d "$localDependencyPath/vendor" ]; then
		echo
		echo "Package '$_arg_symlink_package' has a vendor directory. This must be moved for builds in the current package to run."
		echo "This will likely make you unable to build in '$_arg_symlink_package'. If you need to build in both, use the --dual-dev flag."

		_backupVendor "$localDependencyPath/vendor"

	else
		echo
		echo "No need to move vendor directory from '$_arg_symlink_package' as it does not have a vendor directory. Your build should be fine!"
	fi
fi

if [ -d "$expectedVendorPath" ]; then
	rm -rf "$expectedVendorPath"
	if [[ "$_arg_dual_dev" == "on" ]]; then
		# Need to make the directory in order to symlink under it.
		mkdir "$expectedVendorPath"
	fi
fi

if [[ "$_arg_dual_dev" == "on" ]]; then
	# Loop over all files/directories under the root of the package and symlink them one by one (minus vendor).
	# This solves the problem of nested vendor directories and also does not require deleting/renaming the vendor
	# directory of the package being symlinked in.
	for filename in "$localDependencyPath/"*; do
		# Skip not-existing files and the vendor directory.
		if [[ ! -e "$filename" || "$filename" == *vendor ]]; then
			continue
		fi
		ln -s "$filename" "${expectedVendorPath%/$_arg_symlink_package/}"
	done
else
	ln -s "$localDependencyPath" "${expectedVendorPath%/$_arg_symlink_package}"
fi

# touch all files in the symlinked package to ensure gopherJS and other tools see the changes correctly
if [[ "$_arg_dual_dev" == "on" ]]; then
	touch "$expectedVendorPath"
	find "$expectedVendorPath" -exec touch {} +
else
	find "$expectedVendorPath" -type f -name "*.go" -exec touch {} +
fi

# Get the go package name (domain/user/repo) for the package that is receiving the symlink.
curDirectory=$(pwd)
targetPackageName=${curDirectory#"$GOPATH/src/"}

# Need to delete build assets to ensure rebuilds correctly recognize the symlink. I'm guessing since this symlink
# strategy is not really supported, it breaks the build cache somehow.
echo
echo "Deleting cached builds for $targetPackageName receiving the symlink to ensure rebuilds work correctly."
find "$GOPATH/pkg" \( -name mod -o -name vendor \) -prune -o -path "*$targetPackageName" -exec rm -rf {} +

if command -v goSymlinkVendorPostOpHook &>/dev/null; then
	echo
	echo "Running post operation hook function."
	goSymlinkVendorPostOpHook "$expectedVendorPath/$_arg_symlink_package" "${localDependencyPath#$GOPATH/src/}" "$_arg_dual_dev"
else
	echo
	echo "Post operation hook does not exist, skipping it."
fi

echo
echo "Success! Package '$_arg_symlink_package' was symlinked into vendor from GOPATH correctly!"
