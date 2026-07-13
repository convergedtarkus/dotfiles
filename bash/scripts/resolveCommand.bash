#!/usr/bin/env bash

# -e exits the script immediately when a command returns a nonzero status.
# -u treats use of an unset variable as an error and exits.
# -o pipefail makes a pipeline fail if any command in it fails, not just the last command.
set -euo pipefail # bash strict mode

declare verbose=""
declare alwaysOutputLine=""

# Returns 0 if a shim is found for the command.
# Echos the location of the shim.
# Looks at the shim directory directory, does not use asdf commands.
hasShimFor() {
	if ! command -v asdf >/dev/null || [[ -z $1 ]]; then
		return 1
	fi

	declare asdfShimPath="${ASDF_DATA_DIR:-$HOME/.asdf}/shims"
	if [[ -e "$asdfShimPath/$1" ]]; then
		echo "$asdfShimPath/$1"
		return 0
	fi

	return 1
}

resolveCommand() {
	declare commandToCheck="$1"
	declare commandLocation
	declare shimPath
	declare asdfCommandLocation

	if commandLocation=$(command -v "$commandToCheck"); then
		if ! shimPath=$(hasShimFor "$commandToCheck"); then
			if [[ -n $verbose ]]; then
				echo "'$commandToCheck' exists at '$commandLocation' and is not shimmed."
			else
				echo "$commandLocation"
			fi
			return
		fi

		if [[ $commandLocation == "$shimPath" ]]; then
			if asdfCommandLocation=$(asdf which "$commandToCheck"); then
				if [[ -n $verbose ]]; then
					echo "'$commandToCheck' exists at '$commandLocation' and is running as a shim at '$asdfCommandLocation'."
				else
					echo "$asdfCommandLocation"
				fi
			else
				if [[ -n $verbose ]]; then
					echo "'$commandToCheck' exists at '$commandLocation' and is running as a shim but is NOT valid. Error '$asdfCommandLocation'"
				elif [[ -n $alwaysOutputLine ]]; then
					echo
				fi
				return 1
			fi
		else
			if [[ -n $verbose ]]; then
				echo "'$commandToCheck' exists at '$commandLocation' and is not running as a shim (though a shim exists at '$shimPath')."
			else
				echo "$commandLocation"
			fi
		fi
	else
		if [[ -n $verbose ]]; then
			echo "'$commandToCheck' does not exist."
		elif [[ -n $alwaysOutputLine ]]; then
			echo
		fi
		return 1
	fi
}

# Look for a -v flag for verbose.
declare commandsToCheck=()
for curArg in "$@"; do
	if [[ $curArg == "-v" || $curArg == "--verbose" ]]; then
		verbose=1
	elif [[ $curArg == "-l" || $curArg == "--line" ]]; then
		alwaysOutputLine=1
	elif [[ $curArg == "--help" ]]; then
		echo "Resolve the path to the given command(s). Is aware of shims from asdf (if installed)."
		echo "--verbose, -v  Print verbose, human readable, output for how and where a command resolves to."
		echo "--line, -l     Print a line for each command given. Without this, non-existant or invalid commands output nothing."
		echo "--help         Show this help output."
		exit
	else
		commandsToCheck+=("$curArg")
	fi
done

if [[ ${#commandsToCheck[@]} -eq 0 ]]; then
	echo "No commands given"
	exit 1
fi

declare exitCode=0
for curCommandToCheck in "${commandsToCheck[@]}"; do
	resolveCommand "$curCommandToCheck" || exitCode=1
done

exit "$exitCode"
