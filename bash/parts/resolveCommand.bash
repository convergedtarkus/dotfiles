#!/usr/bin/env bash

# Resolves the path to a command. Takes asdf into account.
# Commands that do not resolve echo nothing (not even a newline)
resolveCommand() {
	_runScript "./scripts/resolveCommand.bash" "$@"
}

# Deletes the given commands. Will remove all asdf shim versions.
deleteAllCommand() {
	if [[ ${#@} == 0 ]]; then
		echoRed "No commands given to deleteAllCommand"
		return 1
	fi
	deleteAsdfCommand "$@"
	deleteCommand "$@"
}

# Deletes all the versions of the given command that are in asdf installed tools.
# For example `deleteAsdfCommand goimports` would delete all versions of goimports
# for all go versions installed by asdf as well as the main shim binary.
# Note, this uses asdf commands to find what to delete so if shims are out of date,
# not all binaries will be removed.
deleteAsdfCommand() {
	if [[ ${#@} == 0 ]]; then
		echoRed "No commands given to deleteAsdfCommand"
		return 1
	fi
	if ! command -v asdf >/dev/null; then
		# asdf does not exist, nothing to do.
		return
	fi

	for commandToDelete in "$@"; do
		# Delete the command using asdf tooling.
		_deleteSingleAsdfCommand "$commandToDelete"

		# Do a brute force look up as well to look for missing commands.
		_bruteDeleteAsdfCommand "$commandToDelete"
	done
}

# Takes in a command to delete, and deletes it from asdf.
# Will attempt to remove both the shim, and all installed versions of the command
# in the tools asdf has.
_deleteSingleAsdfCommand() {
	local -r commandToDelete="$1"
	if [[ -z $commandToDelete ]]; then
		return 0
	fi

	asdfShimPath="${ASDF_DATA_DIR:-$HOME/.asdf}/shims"
	if [[ ! -d $asdfShimPath ]]; then
		echoRed "Cannot find asdf shim path"
		return
	fi

	# Determine where the command is and make sure it is a shim.What?
	local commandPath
	if ! commandPath=$(command -v "$commandToDelete") || [[ -z $commandPath || $(type -t "$commandToDelete") != "file" || ! $commandPath =~ $asdfShimPath ]]; then
		return 0
	fi
	readonly commandPath

	# Determine what versions have this command installed.
	if ! shimVersions=$(asdf shimversions "$commandToDelete"); then
		# This really shouldn't happen since we verified there is a shim.
		echoRed "Cannot determine shim versions for '$commandToDelete'"
		return 0
	fi

	# Try to determine if the command to delete is a core plugin command.
	if ! plugins=$(asdf plugin list); then
		echoRed "Command '$commandToDelete' cannot resolve plugin names"
		return 0
	fi

	if echo "$plugins" | grep -q "^$(_asdfCommandNameToPluginName "$commandToDelete")$"; then
		echoYellow "Command '$commandToDelete' is a core plugin command. It will not be deleted from the plugin bin."
		return 0
	fi

	while IFS= read -r shimLine; do
		if ! toolPath=$(eval "asdf where $shimLine") || [[ ! -d $toolPath ]]; then
			echoRed "For command '$commandToDelete' from '$shimLine', cannot determine tool path"
			return 0
		fi

		deletePath="$toolPath/bin/$commandToDelete"
		if [[ -f $deletePath ]]; then
			echo "For command '$commandToDelete' from '$shimLine', deleting command from bin at '$deletePath'"
			rm "$deletePath" || echoRed "Failed to delete '$deletePath'"
		fi
	done <<<"$shimVersions"

	# Finally, delete the shim.
	if [[ -f $commandPath ]]; then
		echo "For command '$commandToDelete', deleting root shim command at '$commandPath'"
		rm "$commandPath"
	fi
}

# Similar to deleteAsdfCommand but rather than using asdf tooling, it searches asdf
# for the program in a bin directory.
# Works when the shim has already been deleted.
_bruteDeleteAsdfCommand() {
	local -r commandToDelete="$1"
	if [[ -z $commandToDelete ]]; then
		return 0
	fi

	declare -r asdfInstallsPath="${ASDF_DATA_DIR:-$HOME/.asdf}/installs"
	if ! command -v asdf >/dev/null || [[ ! -d $asdfInstallsPath ]]; then
		# No asdf found.
		return 0
	fi

	# Searching the entire asdf installs directory can be slow, so only look for
	# the base bin directory, not nested one.
	find "$asdfInstallsPath" -mindepth 4 -maxdepth 4 -type f -path "*bin/$commandToDelete" \
		-exec echo "For command '$commandToDelete', deleting command from bin at '{}'" \; \
		-exec rm {} \;
}

# Takes in a command name and attempts to determine the plugin name.
# Echos the input if no conversion is found or known.
_asdfCommandNameToPluginName() {
	case "$1" in
	"go")
		echo "golang"
		;;
	"mvn")
		echo "maven"
		;;
	"node")
		echo "nodejs"
		;;
	*)
		echo "$1"
		;;
	esac
}

# Removes the given command. Takes asdf into account.
# Will echo information about the command being removed (if removing, if not found, if protected etc)
deleteCommand() {
	if [[ ${#@} == 0 ]]; then
		echoRed "No commands given to deleteCommand"
		return 1
	fi
	for commandToDelete in "$@"; do
		_deleteNormalCommand "$commandToDelete"
	done
}

# Removes the given command. Does not account for asdf. Protects system directories and brew.
# Will echo information about the command being removed (if removing, if not found, if protected etc)
_deleteNormalCommand() {
	local -r commandToDelete="$1"
	local commandPath
	if ! commandPath="$(command -v "$commandToDelete")" || [[ -z $commandPath || ! -f $commandPath || $(type -t "$commandToDelete") != "file" ]]; then
		return
	fi

	local commandDir
	if ! commandDir=$(dirname "$commandPath") || [[ ! -d $commandDir ]]; then
		echoRed "Not removing command '$commandToDelete' at '$commandPath' as command directory cannot be resolved."
		return
	fi

	local brewLocation
	if command -v brew >/dev/null; then
		brewLocation=$(brew --prefix)
	fi

	case "$commandDir" in
	"$brewLocation"*)
		echoYellow "Not removing command '$commandToDelete' at '$commandPath' as command is installed through homebrew."
		;;
	"/usr"* | "/bin"* | "/sbin"* | "/System"* | "/Applications"* | "/opt"* | "/var"*)
		# Technically, /usr/local/bin might be safe to remove from but protect it for now.
		echoYellow "Not removing command '$commandToDelete' at '$commandPath' as command is a system command."
		;;
	"$HOME/"*)
		echo "Removing command '$commandToDelete' at '$commandPath'"
		rm "$commandPath"
		;;
	*)
		echoYellow "Not removing command '$commandToDelete' at '$commandPath' as it is in an unknown location."
		;;
	esac
}
