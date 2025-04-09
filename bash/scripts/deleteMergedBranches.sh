#!/usr/bin/env bash

# Get the name of the main branch.
mainName=""
if [ "$(git rev-parse --verify main 2>/dev/null)" ]; then
	mainName="main"

fi

if [ "$(git rev-parse --verify master 2>/dev/null)" ]; then
	mainName="master"
fi

# Verify the current branch is main and fetch it.
if [[ -z "$mainName" ]]; then
	echo "Could not find main branch, aborting."
	exit 1
else
	currentBranch=$(git rev-parse --abbrev-ref HEAD)
	if [[ "$mainName" != "$currentBranch" ]]; then
		echo -e "\033[0;33mScript is being run while not on the main branch. This works but will not delete the current branch if it is merged.\033[0m"
	fi

	mainName=$(git rev-parse --symbolic-full-name --abbrev-ref ${mainName}"@{upstream}")
	remoteName=$(echo "$mainName" | cut -d "/" -f 1)
	mainBranchMain=$(echo "$mainName" | cut -d "/" -f 2-)

	echo "Fetching $remoteName $mainBranchMain"
	git fetch "$remoteName" "$mainBranchMain" 2>/dev/null || {
		echo -e "\033[0;31mFetch failed\033[0m"
		exit 1
	}
fi

# From https://stackoverflow.com/a/6127884
# Gets all branches that are merged excluding the current, other worktrees and master/main/dev
mergedBranches=$(git branch --merged "$mainName" | grep -Ev "(^\+|master|main|dev)")

if [[ "$mergedBranches" == *"$currentBranch"* ]]; then
	echo -e "\033[0;33mThe branch you are currently on, $currentBranch, is merged into $mainName. It will not be deleted.\033[0m"
	mergedBranches=$(echo "$mergedBranches" | grep -Ev "($currentBranch)")
fi

# Trim leading and trailing white space from https://unix.stackexchange.com/a/205854
mergedBranches=$(echo "$mergedBranches" | awk '{$1=$1};1')

if [[ "$mergedBranches" == "" ]]; then
	echo "No branches to delete"
	exit 0
fi

echo
echo "Branches to delete:"
echo "$mergedBranches"

echo ""
echo "Should those branches be deleted (y/n)?"

read -r input_variable
if [ "$input_variable" != "y" ] && [ "$input_variable" != "Y" ]; then
	echo "Aborting"
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
