#!/usr/bin/env bash

while [[ -n "$1" ]]; do
	if [[ "$1" == "--stale-only" ]]; then
		staleOnly="true"
	elif [[ "$1" == "--help" ]]; then
		echo "Searches all remote branches and finds any that are greater than $staleBranchAge years"
		echo "The stateBranchAge variable in the script can be updated to whatever value you'd like"
		echo "Arguments:"
		echo "--help: this page"
		echo "-simple: Only log stale branches and in a simple format of ref<TAB>UserName<TAB>UserEmail<TAB>yearsOld"
		echo "--stale-only: Only log out stale branches"
		echo "--remote: If you have multiple remotes, use this to specific the target (next parameter is the remote to use)"
		exit 1
	elif [[ "$1" == "-simple" ]]; then
		simpleOutput="true"
	elif [[ "$1" == "--remote" ]]; then
		shift
		targetRemote="$1"
	else
		echo "Unknown input parameter of '$1'"
		exit 1
	fi
	shift
done

# If a branch is >= this number of years, it is stale and should be deleted.
staleBranchAge=".5"

minute=60
hour=$((60 * minute))
day=$((hour * 24))
year=$((day * 365))

formatAge() {
	seconds="$1"
	echo "$(bc <<<"scale=2;$seconds/$year") years"
}

if [[ -z "$targetRemote" ]]; then
	numRemotes=$(git remote | wc -l | xargs)
	if ((numRemotes == 0)); then
		echo "You have no remotes, please add one"
		exit 1
	elif ((numRemotes > 1)); then
		echo "You have multiple remotes specific one with --remote"
		exit 1
	else
		targetRemote=$(git remote)
	fi
else
	remoteIsValid="false"
	while IFS= read -r curRemote; do
		if [[ "$curRemote" == "$targetRemote" ]]; then
			remoteIsValid="true"
		fi
	done <<<"$(git remote)"
	if [[ "$remoteIsValid" != "true" ]]; then
		echo "The remote you specificed ('$targetRemote') is not a valid one"
		exit 1
	fi
fi

# This will be used to determine the age of the branch.
curTime=$(date +%s)
numTotalBranches=0
numBranchesToDelete=0

originalIFS="$IFS"

allBranches=$(git for-each-ref "refs/remotes/$targetRemote/**" --format='%(objectname) %(refname)')

while IFS= read -r branch; do
	((numTotalBranches++))
	IFS=" "
	read -r -a branchData <<<"$branch"
	IFS="$originalIFS"

	# This is piping errors to be ignored. Might be dangerous or a sign too much work is happening.
	#   warning: inexact rename detection was skipped due to too many files.
	#   warning: you may want to set your diff.renameLimit variable to at least 2154 and retry the command.
	IFS=$'\n'
	mapfile -t branchHeadData <<<"$(git show --format='%at%n%an%n%ae' -s "${branchData[0]}" 2>/dev/null)"
	IFS="$originalIFS"
	branchHeadTime=${branchHeadData[0]}
	branchHeadAuthorName=${branchHeadData[1]}
	branchHeadAuthorEmail=${branchHeadData[2]}
	branchAgeSeconds=$((curTime - branchHeadTime))

	if ((branchAgeSeconds <= 0)); then
		printf "\033[1;31mBranch '%s' is invalid age of '%s'\033[0m\n" "${branchData[1]}" "$branchAgeSeconds}"
	else
		ageString=$(formatAge "$branchAgeSeconds")

		IFS=" "
		read -r -a ageData <<<"$ageString"
		IFS="$originalIFS"

		if [[ -z "$staleOnly" && -z "$simpleOutput" ]]; then
			echo "Head: '${branchData[0]}' ref: '${branchData[1]}' author: '$branchHeadAuthorName' ($branchHeadAuthorEmail) age: $branchAgeSeconds ($ageString)"
		fi
		if [[ "${ageData[1]}" == "years" ]]; then
			if (($(echo "${ageData[0]} > $staleBranchAge" | bc -l))); then
				((numBranchesToDelete++))
				if [[ -n "$simpleOutput" ]]; then
					printf "%s\t%s\t%s\t%s\n" "${branchData[1]}" "$branchHeadAuthorName" "$branchHeadAuthorEmail" "${ageData[0]}"
				else
					printf "\033[1;34mBranch '%s' should be deleted, it is %s years old!' Ask '%s' (%s) to do so!\033[0m\n" "${branchData[1]}" "${ageData[0]}" "$branchHeadAuthorName" "$branchHeadAuthorEmail"
				fi
			fi
		fi
	fi
done <<<"$allBranches"

echo "numTotalBranches: $numTotalBranches numBranchesToDelete: $numBranchesToDelete"
