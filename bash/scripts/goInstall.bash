#!/usr/bin/env bash

# -e exits the script immediately when a command returns a nonzero status.
# -u treats use of an unset variable as an error and exits.
# -o pipefail makes a pipeline fail if any command in it fails, not just the last command.
set -euo pipefail # bash strict mode

if ! SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || [[ -z $SCRIPT_DIR || ! -f "$SCRIPT_DIR/../parts/colorPrint.bash" ]]; then
	echo "Cannot find colorPrint.bash script dir '$SCRIPT_DIR"
	exit 1
fi
source "$SCRIPT_DIR/../parts/colorPrint.bash"

# Argument variables.
declare smartInstall=""
declare installForAll=""

# Handles installing via a custom command.
customInstallCommand() {
	declare -r commandInstallString="$1"
	if [[ $commandInstallString != "--customInstall='"*"'" ]]; then
		echoRed "Invalid custom install of '$commandInstallString"
		return 1
	fi

	# Isolate the command by removing the --customInstall=' and trailing '
	declare installCommand="${commandInstallString#--customInstall=\'}"
	installCommand="${installCommand%\'}"
	readonly installCommand
	if [[ -z $installCommand ]]; then
		echoRed "Custom install command is empty"
		return 1
	fi

	echoBlue "Running custom install command '$installCommand'"
	if ! eval "$installCommand"; then
		echoRed "Failed to install '$commandInstallString'"
		return 1
	fi
}

# Handles installing the given program. Handles --customInstall as well.
installCommand() {
	declare commandInstallString="$1"
	if [[ $commandInstallString == "--customInstall"* ]]; then
		customInstallCommand "$commandInstallString"
		return
	fi

	declare installCommand="go install"
	if [[ -n $smartInstall ]]; then
		# Strip off the @version when using smartGoInstall
		commandInstallString="${commandInstallString%@*}"
		if [[ $commandInstallString != "$1" ]]; then
			echoBlue "Ignoring @version when using smart go install"
		fi
		installCommand="smartGoInstall"
	else
		# Ensure the commandInstallString has a version if needed.
		commandInstallString=$(ensureVersion "$1")
		if [[ $commandInstallString != "$1" ]]; then
			echoBlue "Added @latest version to the install command"
		fi
	fi
	readonly commandInstallString
	readonly installCommand

	echo "Running '$installCommand $commandInstallString'"
	if ! eval "$installCommand $commandInstallString"; then
		echoRed "Failed to install '$commandInstallString'"
		return 1
	fi
}

# Ensures the command to install has a version (or one is not needed).
# Echos the updated command to install string.
ensureVersion() {
	declare -r commandInstallString="$1"
	if [[ $commandInstallString == *@* ]]; then
		# There is a version, all is well.
		echo "$commandInstallString"
		return
	fi

	# No version, this is fine if in a module, but otherwise a version is required.
	if ! goMod=$(go env GOMOD); then
		echoRed "Cannot resolve GOMOD"
		return 1
	fi

	case "$goMod" in
	"" | '\n' | /dev/null)
		# No go module, a version is required. Put on @latest for ease.
		echo "$commandInstallString@latest"
		;;
	*)
		# No version while in a go module is fine, it will use the version from the go.mod
		echo "$commandInstallString"
		;;
	esac
}

installForAllGoVersions() {
	declare commandInstallString="$1"
	if [[ -z $1 ]]; then
		echoRed "No command passed to install"
		return 1
	fi

	installCommand "$commandInstallString"
	# Second argument is used with customInstall to get the command name.
	if [[ -n $2 ]]; then
		commandInstallString="$2"
	fi
	readonly commandInstallString
	echo "Installed '$commandInstallString' successfully for current go version"

	# Nothing more to do if asdf is not installed or not installing for all.
	if [[ -z $installForAll ]] || ! command asdf >/dev/null; then
		return
	fi

	# Reshim to ensure the shim exists.
	asdf reshim golang

	declare -r asdfGoInstallsPath="${ASDF_DATA_DIR:-$HOME/.asdf}/installs/golang/"
	if [[ ! -d $asdfGoInstallsPath ]]; then
		echoRed "Cannot determine where asdf go installs are. Tried '$asdfGoInstallsPath'"
		return 1
	fi

	# Remove the @version suffix and any prefix slashes
	declare commandName="${commandInstallString%@*}"
	commandName="${commandName##*/}"
	readonly commandName

	declare commandLocation
	if ! commandLocation=$(asdf which "${commandName}") || [[ -z $commandLocation ]]; then
		echoRed "Cannot determine where program '$commandName' was installed to"
		return 1
	fi
	readonly commandLocation

	declare currentGoBinPath
	if ! currentGoBinPath=$(dirname "$commandLocation") || [[ ! -d $currentGoBinPath ]]; then
		echoRed "Bin directory for current go version does not exist"
		return 1
	fi
	readonly currentGoBinPath

	if ! currentGoInstallPath=$(asdf where golang) || [[ -z $currentGoInstallPath ]]; then
		echoRed "Cannot find current go install location"
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
			echoYellow "Skipping '$goInstall' because bin path '$targetGoBin' does not exist"
		else
			echo "Copying binary for '$commandName' from '$commandLocation' to '$targetGoBin'"
			cp "$commandLocation" "$targetGoBin"
		fi
	done
}

programsToInstall=()
for arg in "$@"; do
	case "$arg" in
	"--help" | "-help")
		echo "Help"
		;;
	"-a" | "--all" | "-all")
		installForAll=1
		;;
	"-s" | "--smart" | "-smart")
		# Make sure the command exists and works.
		if ! command -v smartGoInstall >/dev/null; then
			echoYellow "Smart argument provided but cannot find smartGoInstall. Falling back to normal go install."
		elif ! smartGoInstall --help &>/dev/null; then
			echoYellow "Smart argument provided but smartGoInstall failed to run. Falling back to normal go install."
		else
			smartInstall=1
		fi
		;;
	*)
		programsToInstall+=("$arg")
		;;
	esac
done

for toInstall in "${programsToInstall[@]}"; do
	# Support some shortcut common installs.
	declare commandName=""
	case "$toInstall" in
	shfmt)
		toInstall="mvdan.cc/sh/v3/cmd/shfmt"
		;;
	golangci-lint)
		toInstall="github.com/golangci/golangci-lint/v2/cmd/golangci-lint"
		;;
	frugal)
		toInstall="github.com/Workiva/frugal"
		;;
	gopherjs)
		toInstall="github.com/gopherjs/gopherjs"
		;;
	smartGoInstall)
		toInstall="--customInstall='(cd $SCRIPT_DIR/../../tools/smartGoInstall/ && go install .)'"
		commandName="smartGoInstall"
		;;
	esac
	installForAllGoVersions "$toInstall" "$commandName"
done
