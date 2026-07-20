#!/usr/bin/env bash

# -e exits the script immediately when a command returns a nonzero status.
# -u treats use of an unset variable as an error and exits.
# -o pipefail makes a pipeline fail if any command in it fails, not just the last command.
set -euo pipefail # bash strict mode

if ! SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || [[ -z $SCRIPT_DIR || ! -f "$SCRIPT_DIR/../parts/colorPrint.bash" ]]; then
	echo "Cannot find colorPrint.bash relative to script dir '$SCRIPT_DIR'"
	exit 1
fi
source "$SCRIPT_DIR/../parts/colorPrint.bash"

# Get the name of the main branch.
mainName=""
if git rev-parse --verify main 2>/dev/null; then
	mainName="main"
elif git rev-parse --verify master 2>/dev/null; then
	mainName="master"
fi

# Verify the current branch is main and fetch it.
if [[ -z $mainName ]]; then
	echoRed "Could not find main branch, aborting."
	exit 1
else
	currentBranch=$(git rev-parse --abbrev-ref HEAD)
	if [[ $mainName != "$currentBranch" ]]; then
		echoYellow "Script is being run while not on the main branch. This works but will not delete the current branch if it is merged."
	fi

	mainName=$(git rev-parse --symbolic-full-name --abbrev-ref "${mainName}@{upstream}")
	remoteName=$(echo "$mainName" | cut -d "/" -f 1)
	mainBranchMain=$(echo "$mainName" | cut -d "/" -f 2-)

	echoBlue "Fetching $remoteName $mainBranchMain"
	git fetch "$remoteName" "$mainBranchMain" 2>/dev/null || {
		echoRed "Fetch failed"
		exit 1
	}
fi

# From https://stackoverflow.com/a/6127884
# Gets all branches that are merged excluding the current, other worktrees and master/main/dev
mergedBranches=$(git branch --merged "$mainName" | grep -Ev "(^\+|master|main|dev)")

if [[ $mergedBranches == *"$currentBranch"* ]]; then
	echoYellow "The branch you are currently on, $currentBranch, is merged into $mainName. It will not be deleted."
	mergedBranches=$(echo "$mergedBranches" | grep -Ev "($currentBranch)")
fi

# Trim leading and trailing white space from https://unix.stackexchange.com/a/205854
mergedBranches=$(echo "$mergedBranches" | awk '{$1=$1};1')

if [[ $mergedBranches == "" ]]; then
	echoGreen "No branches to delete"
	exit 0
fi

echo
echo "Branches to delete:"
echo "$mergedBranches"

echo ""
echo "Should those branches be deleted (y/n)?"

read -r input_variable
if [[ $input_variable != "y" ]] && [[ $input_variable != "Y" ]]; then
	echoYellow "Aborting"
	exit 0
else
	echo "Deleting all requested branches"
	echo ""
fi

# Remove all newlines from https://unix.stackexchange.com/a/57129
mergedBranches=$(echo "$mergedBranches" | tr '\n' ' ')

# shellcheck disable=SC2086
# Word splitting is needed for mergedBranches or the output is all quoted as if it was a single branch
git branch -D $mergedBranches
