#!/usr/bin/env bash

set -euo pipefail

# Source pretty_print.sh from the script's own directory so this works regardless
# of where it is called from.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/pretty_print.sh"

export GO111MODULE=on

usage() {
	echo "Usage: $0 installString [-h | --help]"
	printf "\tInstall the given command using installString just as go install would normally be called.\n"
	printf "\tIf the command is already installed and at the correct version, it will not be installed again.\n"
	printf "\tThis script is aware of asdf shims and will reshim if needed to ensure the command is available.\n\n"
	printf "\t-h | --help        Show this information.\n"
	exit 0
}

# Runs go install and validates the binary exists afterwards.
# Reshims if the user is running Go via asdf and the shims may be stale.
goInstallCommand() {
	# Determine the go bin directory. Prefer GOBIN if set, otherwise GOPATH/bin.
	local goBin
	if ! goBin="$(go env GOBIN)"; then
		errcolorecho "Cannot determine GOBIN."
		exit 1
	fi
	if ! goBin="${goBin:-$(go env GOPATH)/bin}" || [[ ! -d $goBin ]]; then
		errcolorecho "Cannot determine GOBIN"
		exit 1
	fi
	readonly goBin

	echo "Installing $commandName to '$goBin' at version '$versionToInstall'."
	if ! go install "$installString"; then
		errcolorecho "go install '$installString' failed."
		exit 1
	fi
	if [[ ! -f "$goBin/$commandName" ]]; then
		errcolorecho "No binary found for '$commandName' at '$goBin' after go install."
		exit 1
	fi

	asdfReshim
}

asdfReshim() {
	# Reshim if the user is running Go via asdf and the shims may be stale.
	local -r asdfDir="${ASDF_DATA_DIR:-$HOME/.asdf}"
	if ! command -v asdf &>/dev/null || [[ ! -d $asdfDir || ! -d "$asdfDir/shims" ]]; then
		# No asdf installed. Nothing to do.
		return 0
	fi

	# command -v returns non-zero if the command has no shim yet; capture the result manually.
	local commandLoc
	commandLoc=$(command -v "$commandName") || commandLoc=""
	readonly commandLoc

	# Reshim if the command already has a shim, or if Go is from asdf and the command has no shim yet.
	if [[ $commandLoc == "$asdfDir/shims/$commandName" || ($goBin == "$asdfDir"/* && -z $commandLoc) ]]; then
		local goVersion
		if ! goVersion="$(go env GOVERSION | sed 's/^go//')" || [[ -z $goVersion ]]; then
			errcolorecho "Failed to resolve installed go version."
			exit 1
		fi
		readonly goVersion

		infocolorecho "Running 'asdf reshim golang $goVersion' to ensure command is available."
		if ! asdf reshim golang "$goVersion"; then
			errcolorecho "Failed to reshim for go '$goVersion'."
			exit 1
		fi
		if ! asdf shimversions "$commandName" | grep -q "\b$goVersion\b"; then
			errcolorecho "No shim exists for '$commandName' at Go '$goVersion' after reshim."
			exit 1
		fi
	fi
}

# Prints the absolute path to the named command on the user's system.
# Resolves asdf shims to their real binary path.
getCommandLocation() {
	# command -v returns non-zero if the command is not on PATH; capture the result manually.
	local commandLocation
	commandLocation=$(command -v "$commandName") || commandLocation=""
	if [[ -z $commandLocation ]]; then
		return 1
	fi

	# Check if the command is an asdf shim.
	local -r shimDir="${ASDF_DATA_DIR:-$HOME/.asdf}/shims"
	if ! command -v asdf &>/dev/null || [[ ! -d $shimDir || $commandLocation != *"$shimDir"* ]]; then
		echo "$commandLocation"
		return 0
	fi

	# Get the real binary path from asdf.
	if ! commandLocation="$(asdf which "$commandName")" || [[ -z $commandLocation ]]; then
		return 1
	fi

	echo "$commandLocation"
}

# Prints the module version embedded in the binary at the given path.
# For module-compliant packages, this is a semver string (e.g. v1.2.3).
# For non-module-compliant packages built from a commit, this is the short commit hash.
getInstalledCommandVersion() {
	local -r binaryPath="$1"

	local goVersionOutput
	if ! goVersionOutput=$(go version -m "$binaryPath" 2>/dev/null) || [[ -z $goVersionOutput ]]; then
		return 1
	fi
	readonly goVersionOutput

	local userVersion
	userVersion=$(echo "$goVersionOutput" | awk "\$1 == \"mod\" && \$2 == \"$modulePath\" { printf \"%s\", \$3; exit }")

	# For pseudo-versions (vX.Y.Z-timestamp-hash), strip everything up to the last dash to
	# get the short commit hash. For regular semver tags (e.g. v1.2.3), this is a no-op.
	echo "${userVersion##*-}"
}

# Resolves and prints the version that will be installed.
# For explicit semver tags, the semver portion is returned directly without any network call.
# For fuzzy versions (@latest, @main, etc.) or no @version, go list is used to resolve
# to a concrete version.
getTargetVersion() {
	# Explicit semver-like tag — return it directly without a network call.
	if [[ $installStringVersion =~ ^@(v[0-9]+\.[0-9]+\.[0-9]+) ]]; then
		echo "${BASH_REMATCH[1]}"
		return 0
	fi

	# Version is empty or not a semver tag (@latest, branch name, etc.) — use go
	# list to resolve to a concrete version.
	local targetVersion
	if ! targetVersion=$(go list -mod=readonly -m -f '{{.Version}}' "${modulePath}${installStringVersion}") || [[ -z $targetVersion ]]; then
		errcolorecho "Failed to resolve version '$installStringVersion' for '$commandName'."
		exit 1
	fi

	# For pseudo-versions (vX.Y.Z-timestamp-hash), strip everything up to the last dash to
	# get the short commit hash. For regular semver tags (e.g. v1.2.3), this is a no-op.
	echo "${targetVersion##*-}"
}

# Returns 0 if the command is installed at the correct version, 1 otherwise.
# mode must be 'pre' or 'post':
#   pre  – quiet on mismatch; used to decide whether to install
#   post – logs an error on mismatch; used to validate after install
isInstalledAtCorrectVersion() {
	local -r mode="$1"
	if [[ $mode != "pre" && $mode != "post" ]]; then
		errcolorecho "Invalid mode '$mode' passed to isInstalledAtCorrectVersion."
		exit 1
	fi

	local commandLocation
	if ! commandLocation=$(getCommandLocation) || [[ -z $commandLocation ]]; then
		if [[ $mode == "pre" ]]; then
			infocolorecho "$commandName is not installed. It will be installed at version '$versionToInstall'."
		else
			errcolorecho "$commandName could not be found after install. Ensure your Go bin or asdf shims are on your PATH."
		fi
		return 1
	fi
	readonly commandLocation

	local userVersion
	if ! userVersion=$(getInstalledCommandVersion "$commandLocation") || [[ -z $userVersion ]]; then
		if [[ $mode == "post" ]]; then
			errcolorecho "Could not determine the installed version of '$commandName' at '$commandLocation'."
		fi
		return 1
	fi
	readonly userVersion

	# Determine what version string to compare against. For module-compliant packages, both
	# versionToInstall and userVersion are semver and compare directly.
	#
	# For non-module-compliant packages, the binary embeds a pseudo-version with
	# a commit hash so the versionToInstall (a semver tag) must be resolved to a commit.
	local versionToCheckAgainst="$versionToInstall"
	if [[ $versionToInstall =~ ^v[0-9] && ! $userVersion =~ ^v[0-9] ]]; then
		local remoteURL
		remoteURL="https://$(echo "$modulePath" | awk -F'/' '{OFS="/"; print $1, $2, $3}')"
		readonly remoteURL

		local -r gitTag="${installStringVersion#@}"
		if ! versionToCheckAgainst=$(git ls-remote --tags "$remoteURL" "refs/tags/$gitTag" | awk '{print $1}') || [[ -z $versionToCheckAgainst ]]; then
			errcolorecho "Failed to resolve tag '$gitTag' to a commit hash from '$remoteURL'."
			return 1
		fi
		# Go pseudo-versions embed a 12-character commit hash. Truncate to match.
		versionToCheckAgainst="${versionToCheckAgainst:0:12}"
	fi
	readonly versionToCheckAgainst

	local versionOutput="$versionToInstall"
	if [[ $versionToInstall != "$versionToCheckAgainst" ]]; then
		versionOutput="$versionOutput ($versionToCheckAgainst)"
	fi
	readonly versionOutput

	if [[ $userVersion != "$versionToCheckAgainst" ]]; then
		if [[ $mode == "pre" ]]; then
			infocolorecho "Wrong version of '$commandName' installed ($userVersion). Expected '$versionOutput'. A new version will be installed."
		else
			errcolorecho "Wrong version of '$commandName' at '$commandLocation'. Have '$userVersion', expected '$versionOutput'."
		fi
		return 1
	fi

	successcolorecho "'$commandName' is at the correct version $versionOutput ($commandLocation). $([[ $mode == "pre" ]] && echo "Skipping install")"
	return 0
}

# Parse the input arguments.
declare installString=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		usage
		;;
	-*)
		echo "Unknown option: $1"
		usage
		;;
	*)
		if [[ -n $installString ]]; then
			echo "Unexpected argument: $1"
			usage
		fi
		installString="$1"
		shift
		;;
	esac
done
readonly installString

if [[ -z $installString ]]; then
	errcolorecho "No package path provided. Please provide one just as you would to go install."
	exit 1
fi

# commandName is the name the resulting binary will be.
# modulePath is the full package (including any submodule)
declare commandName="${installString%@*}"  # Strip the @version suffix
declare modulePath="${commandName%/cmd/*}" # Strip /cmd/... to get the module path
commandName="${commandName##*/}"           # Keep only the final path component (the binary name)
readonly commandName modulePath

# The lateral @version value from the install string (if one exists).
installStringVersion=""
if [[ $installString =~ .*@(.*) ]]; then
	installStringVersion="@${BASH_REMATCH[1]##*/}" # Remove any path in the version.
fi
readonly installStringVersion

# Resolve the target version.
declare versionToInstall
versionToInstall="$(getTargetVersion)"
readonly versionToInstall

if isInstalledAtCorrectVersion "pre"; then
	exit 0
fi

goInstallCommand

if ! isInstalledAtCorrectVersion "post"; then
	exit 1
fi
