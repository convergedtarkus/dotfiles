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
	echo "Could not find main/master branch, aborting."
	exit 1
else
	currentBranch=$(git rev-parse --abbrev-ref HEAD)
	if [[ "$mainName" != "$currentBranch" ]]; then
		echo "This script only works when on the main/master branch"
		exit 1
	fi

	echo "Fetching $mainName"
	git fetch 2>/dev/null || (echo "Fetch failed" && exit 1)

	mainName=$(git rev-parse --symbolic-full-name --abbrev-ref "@{upstream}")
fi

# From https://stackoverflow.com/a/6127884
# Gets all branches that are merged excluding the current, other worktrees and master/main/dev
mergedBranches=$(git branch --merged "$mainName" | grep -Ev "(^\*|^\+|master|main|dev)")

# Trim leading and triling white space from https://unix.stackexchange.com/a/205854
mergedBranches=$(echo "$mergedBranches" | awk '{$1=$1};1')

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
