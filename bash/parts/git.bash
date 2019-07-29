#!/usr/bin/env bash

# Function to define the "upstream" repo alias name. Needs to be first for use below
# Uses the first matching remote in git config upstream > origin
# Can define a custom _getOriginRemotePreHook for using a non-standard alias
getOriginRemote() {
	customAlias=$(_getOriginRemotePreHook)
	if [[ $customAlias != "" ]]; then
		echo "$customAlias"
		return
	fi

	# this just checks the git config, there is no guarantee the remote exists
	if git config remote.upstream.url >/dev/null; then
		echo "upstream"
		return
	fi

	# assume an origin remote is setup
	echo "origin"
}

# Called at the start of getOriginRemote
# Can be used to return a custom origin remote alias
_getOriginRemotePreHook() { :; }

# git shortcut
alias g='git'

# git add
alias ga='git add'
alias gall='git add -A' # add everything

# git branch
alias gb='git branch'
alias gba='git branch -a'
alias gbt='git branch --track'
alias gbm='git branch -m'
alias gbd='git branch -d'
alias gbD='git branch -D'

# git checkout
alias gco='git checkout'
alias gcom='git checkout master'
gcomup() { git checkout master ${1:+"$1"} && git pull; } # $1 allows passing -f to dump current changes
alias gcob='git checkout -b'

# git commit
alias gc='git commit -v'
alias gca='git commit -v -a' # commit all
alias gcm='git commit -v -m'
alias gcam='git commit -v -am'
alias gcaa='git commit -a --amend -C HEAD' # Add uncommitted and unstaged changes to the last commit
alias gcAmend='git commit --amend -C HEAD' # like gcaa, but only add staged changes

# git diff
alias gd='git diff'
gdv() { git diff -w "$@" | vim -R -; } # git diff, ignore whitespace, in vim

# git fetch
alias gf='git fetch --all --prune'
alias gft='git fetch --all --prune --tags'
alias gfm='git fetch "$(getOriginRemote)" master' # fetch remote master
# gfc fetches just the current branch.
gfc() {
	fetchTarget=$(git rev-parse --symbolic-full-name --abbrev-ref "@{upstream}" | sed 's|/| |')
	echo "Fetch target is '$fetchTarget'"
	if [[ -z "$fetchTarget" ]]; then
		echo "Cannot parse upstream"
		return 1
	fi
	eval git fetch "$fetchTarget"
}

# git pull
alias gl='git pull'
# glum must be a function. If its an alias, the $(getOriginRemote) is evaluated right away, defeating the purpose of the _getOriginRemotePreHook
glum() { git pull "$(getOriginRemote)" master --no-edit ${1:+"$1"}; } # pull in upstream master, $1 allows passing extra args to the pull (like -r)

# git stash
alias gst='git stash'
alias gstd='git stash drop'
alias gstl='git stash list'
alias gsta='git stash apply'
alias gstp='git stash pop'
alias gsts='git stash save'

# git reset
alias gus='git reset'
alias gUndoLastCommit='git reset --soft HEAD~ && git reset' # Will basically undo the last commit, putting all the changes back in the working tree.
alias gResetToRemote='gfc && git reset --hard @{u}'         # Fetches this branch and then resets to the head of the remote.

# git command shortcuts
alias gcp='git cherry-pick'
alias gm='git merge'
alias gs='git status'

# git push
alias gp='git push'
gpu() { git push -u "$(getOriginRemote)" ${1:+"$1"}; } # push (and track) to upstream

# git grep and helpers
alias gitGrep='git grep -I -n --break' # skip binary files, add line numbers and a break between files

# helpers for use with gitGrep
export ggNoVendor=':!/vendor' # gitGrep "blah" -- $ggNoVendor to ignore matches in ./vendor (for go projects)

# Show commits since last pull
alias gnew='git log HEAD@{1}..HEAD@{0}'

# Quick ways to get the head commit.
alias gHead='git log -1'
alias gHeadHash='git rev-parse HEAD'

# Quick way to get the current branch
alias gBranch='git rev-parse --abbrev-ref HEAD'

# Clean commands
alias safeClean='git clean -xdf -e .idea -e "*.iml" -e .atom -e .vscode' # will remove ignored files and untracked files (git add anything you want to keep). Keeps IDE files/settings.
alias testSafeClean='safeClean -n'                                       # safeClean but only list what would be removed (do not delete anything).
alias gpristine='git reset --hard && safeClean'                          # safeClean + reset to HEAD

# Get the base commit between the current branch and master.
masterBase() {
	git fetch "$(getOriginRemote)" master &>/dev/null # fetch origin so origin/master is up to date
	git merge-base "$(getOriginRemote)/master" HEAD
}

# Rebase the current branch based on its base against master. Good for cleaning/re-organizing commits
gRebaseBase() {
	git rebase -i "$(masterBase)"
}

# List all tags. Use tags pulled down, consider running a fetch with tags before hand.
# A numeric value can be passed in to limit the number of returned tags to the number.
listTags() {
	if [[ "$1" == "" ]]; then
		git tag -l --sort=-v:refname
		return 0
	fi

	git tag -l --sort=-v:refname | head -n "$1"
}

# Merges master and produces a string to say when the merge was done. Produce the same format of string if up to date with master.
qaMasterMerge() {
	startingHeadHash=$(git rev-parse HEAD)

	git pull "$(getOriginRemote)" master &>/dev/null

	endingHeadHash=$(git rev-parse HEAD)

	logString=""
	if [[ "$startingHeadHash" != "$endingHeadHash" ]]; then
		logString="Pulled in master at '$(git log -1 -s --format="%cd")'"
	else
		logString="Up to date with master as of '$(date '+%c %z')'"
	fi

	git fetch "$(getOriginRemote)" master &>/dev/null # fetch origin so origin/master is up to date

	echo "$logString, master commit: $(masterBase), head commit: $(git rev-parse HEAD)"
}

# Add a remote to the current repo. `addRemote someone`. Fetches after to ensure everything is up to date.
addRemote() {
	remoteName=$1
	reproName=$(basename "$(git rev-parse --show-toplevel)")

	if [[ "$remoteName" == "" ]]; then
		echo "Must supply a remote name"
		return 0
	fi

	echo "Adding remote $remoteName"

	git remote add "$remoteName" "git@github.com:$remoteName/$reproName.git"

	git fetch "$remoteName" --tags # fetch the new remote
}

# Echos true if the file or directory is tracked or false otherwise.
isGitTracked() {
	if git ls-files "$1" --error-unmatch &>/dev/null; then
		echo true
		return 0
	fi

	echo false
}

# produces the commit log of commits in this branch that are not in master
# allows passing extra arguments to the final `git log` command
# E.X. logAgainstMaster -n 1
logAgainstMaster() {
	git fetch "$(getOriginRemote)" master &>/dev/null # fetch origin so origin/master is up to date
	git log "$(getOriginRemote)/master"..HEAD --first-parent ${1:+"$1"}
}

# produces the commit log of commits in this branch that are not in master
# uses 'merge-base' so only changes in this branch should be displayed
# allows passing extra arguments to the final `git log` command
# E.X. logAgainstMaster -n 1
logAgainstBase() {
	git fetch "$(getOriginRemote)" master &>/dev/null # fetch origin so origin/master is up to date
	baseCommit=$(git merge-base "$(getOriginRemote)"/master HEAD)
	git log "$baseCommit"..HEAD --first-parent ${1:+"$1"}
}

# produces a diff of code in this branch that is not in master
# remember, this shows all code differences so if this branch is behind master it will look messy
# consider using `diffAgainstBase` for cleaner diffs of only changes in this branch
# allows passing extra arguments to the final `git diff` command
# E.X. diffAgainstMaster --stat
diffAgainstMaster() {
	git fetch "$(getOriginRemote)" master &>/dev/null # fetch origin so origin/master is up to date
	git diff "$(getOriginRemote)/master"..HEAD ${1:+"$1"}
}

# produces a diff of code changed in this branch
# uses 'merge-base' so only changes in this branch should be displayed
# allows passing extra arguments to the final `git diff` command
# E.X. diffAgainstBase --stat
diffAgainstBase() {
	git fetch "$(getOriginRemote)" master &>/dev/null # fetch origin so origin/master is up to date
	baseCommit=$(git merge-base "$(getOriginRemote)"/master HEAD)
	git diff "$baseCommit"..HEAD ${1:+"$1"}
}

# shows new parent commits in master that are not in this branch
# allows passing extra arguments to the final `git log` command
# E.X. previewMasterMerge -n 1
previewMasterMerge() {
	git fetch "$(getOriginRemote)" master &>/dev/null # fetch origin so origin/master is up to date
	git log HEAD.."$(getOriginRemote)/master" --first-parent
}

# Takes piped in input and will highlight any changed files in the input.
highlightChangedFiles() {
	changedFiles=$(git diff HEAD --name-only | tr '\n' '|')
	# From https://stackoverflow.com/questions/981601/colorized-grep-viewing-the-entire-file-with-highlighted-matches
	grep --color -E "$changedFiles$" # grep --color -E 'blah|blah|$'
}
