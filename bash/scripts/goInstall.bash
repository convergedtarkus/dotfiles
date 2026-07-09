#!/usr/bin/env bash

# -e exits the script immediately when a command returns a nonzero status.
# -u treats use of an unset variable as an error and exits.
# -o pipefail makes a pipeline fail if any command in it fails, not just the last command.
set -euo pipefail # bash strict mode

installForAllGoVersions() {
	declare -r commandInstallString="$1"
	if [[ -z $commandInstallString ]]; then
		echo "No command passed to install"
		return 1
	fi

	if ! go install "$commandInstallString"; then
		echo "Failed to go install '$commandInstallString'"
		return 1
	fi
	echo "Installed '$commandInstallString' successfully for current go version"

	# Nothing more to do if asdf is not installed
	if ! command asdf >/dev/null; then
		return
	fi

	# Reshim to ensure the shim exists.
	asdf reshim golang

	declare -r asdfGoInstallsPath="${ASDF_DATA_DIR:-$HOME/.asdf}/installs/golang/"
	if [[ ! -d $asdfGoInstallsPath ]]; then
		echo "Cannot determine where asdf go installs are. Tried '$asdfGoInstallsPath'"
		return 1
	fi

	# Remove the @version suffix and any prefix slashes
	declare commandName="${commandInstallString%@*}"
	commandName="${commandName##*/}"
	readonly commandName

	declare commandLocation
	if ! commandLocation=$(asdf which "${commandName}") || [[ -z $commandLocation ]]; then
		echo "Cannot determine where program was installed to"
		return 1
	fi
	readonly commandLocation

	declare currentGoBinPath
	if ! currentGoBinPath=$(dirname "$commandLocation") || [[ ! -d $currentGoBinPath ]]; then
		echo "Bin directory for current go version does not exist"
		return 1
	fi
	readonly currentGoBinPath

	if ! currentGoInstallPath=$(asdf where golang) || [[ -z $currentGoInstallPath ]]; then
		echo "Cannot find current go install location"
	fi
	readonly currentGoInstallPath

	binPathExtension=${currentGoBinPath#"$currentGoInstallPath"}
	readonly binPathExtension

	for goInstall in "$asdfGoInstallsPath"*; do
		targetGoBin="$goInstall$binPathExtension"
		if [[ $targetGoBin == "$currentGoBinPath" ]]; then
			continue
		fi

		if [[ ! -d $targetGoBin ]]; then
			echo "Skipping '$goInstall' because bin path '$targetGoBin' does not exist"
		else
			echo "Copying binary for '$commandName' from '$commandLocation' to '$targetGoBin'"
			cp "$commandLocation" "$targetGoBin"
		fi
	done
}

