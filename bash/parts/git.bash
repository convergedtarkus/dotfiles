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
alias gbDPrev='git branch -D @{-1}' # Delete the previous branch you were on.

# git checkout
alias gco='git checkout'
alias gcom='git checkout master'
alias gcomb='git fetch $(getOriginRemote) master && git checkout $(getOriginRemote)/master -b' # Creates a new branch based on upstream/master (not your local master).
gcomup() { git checkout master ${1:+"$1"} && git pull; }                                       # $1 allows passing -f to dump current changes
alias gcob='git checkout -b'
gcoClean() { git checkout ${1:+"$1"} && git clean -fd ${1:+"$1"}; }

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
_fetchTarget() {
	fetchTarget=$(git rev-parse --symbolic-full-name --abbrev-ref "@{upstream}" | sed 's|/| |')
	if [[ -z "$fetchTarget" ]]; then
		echo "Cannot parse upstream"
		return 1
	fi
	echo "$fetchTarget"
	return 0
}

# gfc fetches just the current branch.
gfc() {
	fetchTarget=$(_fetchTarget)
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
# shellcheck disable=SC2120 # Disabled since arguments are optional.
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

# git rebase
alias gr='git rebase'
alias gra='git rebase --abort'
alias grc='git rebase --continue'

# git command shortcuts
alias gcp='git cherry-pick'
alias gm='git merge'
alias gs='git status'

# git push
alias gp='git push'
alias gpf='git push -f'
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
	gfm &>/dev/null # fetch origin so origin/master is up to date
	git merge-base "$(getOriginRemote)/master" HEAD
}

# Rebase the current branch based on its base against master. Good for cleaning/re-organizing commits
gRebaseBase() {
	git rebase -i "$(masterBase)"
}

# Merges upstream master into the given branch, pushes it up and deleted the local branch.
# Good for updating a remote branch with master that you don't need checked-out locally.
mergeMasterIntoBranch() {
	if [[ -z "$1" ]]; then
		echo "Must supply a branch name!"
		return 1
	fi
	gf       # Fetch everything (not tags though)
	gco "$1" # Checkout the passed in branch
	glum     # Merge master into the checked-out branch
	gp       # Push up the merge
	gco -    # Switch back to the previous branch
	gbd "$1" # Delete the branch that master was merged into
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

	gfm &>/dev/null # fetch origin so origin/master is up to date

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
	gfm &>/dev/null # fetch origin so origin/master is up to date
	git log "$(getOriginRemote)/master"..HEAD --first-parent ${*:+"$*"}
}

# produces the commit log of commits in this branch that are not in master
# uses 'merge-base' so only changes in this branch should be displayed
# allows passing extra arguments to the final `git log` command
# E.X. logAgainstMaster -n 1
logAgainstBase() {
	baseCommit=$(masterBase)
	git log "$baseCommit"..HEAD --first-parent ${*:+"$*"}
}

# produces a diff of code in this branch that is not in master
# remember, this shows all code differences so if this branch is behind master it will look messy
# consider using `diffAgainstBase` for cleaner diffs of only changes in this branch
# allows passing extra arguments to the final `git diff` command
# E.X. diffAgainstMaster --stat
diffAgainstMaster() {
	gfm &>/dev/null # fetch origin so origin/master is up to date
	git diff "$(getOriginRemote)/master"..HEAD ${*:+"$*"}
}

# produces a diff of code changed in this branch
# uses 'merge-base' so only changes in this branch should be displayed
# allows passing extra arguments to the final `git diff` command
# E.X. diffAgainstBase --stat
diffAgainstBase() {
	baseCommit=$(masterBase)
	git diff "$baseCommit"..HEAD ${*:+"$*"}
}

# produces a diff of code changed in this branch
# uses 'merge-base' so only changes in this branch should be displayed
# allows passing extra arguments to the final `git diff` command
# E.X. diffAgainstBase --stat
diffAgainstRemote() {
	gfc &>/dev/null # fetch the remote of this branch
	remote=$(_fetchTarget)
	remote=$(echo "$remote" | tr " " "/") # Replace the space between the remote name and branch name with a '/'.
	git diff "$remote"..HEAD ${*:+"$*"}
}

# shows new parent commits in master that are not in this branch
# allows passing extra arguments to the final `git log` command
# E.X. previewMasterMerge -n 1
previewMasterMerge() {
	gfm &>/dev/null # fetch origin so origin/master is up to date
	git log HEAD.."$(getOriginRemote)/master" --first-parent
}

# Takes piped in input and will highlight any changed files in the input.
highlightChangedFiles() {
	changedFiles=$(git diff HEAD --name-only | tr '\n' '|')
	# From https://stackoverflow.com/questions/981601/colorized-grep-viewing-the-entire-file-with-highlighted-matches
	grep --color -E "$changedFiles$" # grep --color -E 'blah|blah|$'
}

# Clone a repo using my personal ssh key setup.
# How to setup (from https://gist.github.com/jexchan/2351996/)
#  1. Make a new ssh key `ssh-keygen -t rsa -b 4096 -C <EMAIL>`
#     - Save it to ~/.ssh/id_rsa_personal
#  2. Add it to github (or other host) `pbcopy < ~/.ssh/id_rsa_personal.pub`
#  3. Add this to ~/.ssh/config
#     # Personal account
#     Host github.com-personal
#	HostName github.com
#	User git
#	IdentityFile ~/.ssh/id_rsa_personal
#       IdentitiesOnly yes
#  4. Clone repos using this command to clone with personal credentials.
# Takes in a single parameter, the repo to clone `user/repo`.
clonePersonalRepo() {
	git clone "git@github.com-personal:$1.git"
	path=${1##*/}
	cd "$path" || return
	git config user.name "convergedtarkus"
	git config user.email "38326544+convergedtarkus@users.noreply.github.com"
	installGitHooks
}

installGitHooks() {
	if [[ ! -d ./.git/hooks ]]; then
		echo "No .git/hooks under current location, aborting."
		return
	fi

	for file in "$MYDOTFILES"/githooks/*; do
		if [[ -e "$file" ]]; then
			echo "Copying '$file' to git hooks"
			cp "$file" ./.git/hooks
		fi
	done
}

# Opens a JIRA ticket in chrome.
# If an argument is pass in, that will be parsed for the ticket to open.
# Otherwise, the current git branch name will be parsed.
openTicket() {
	if [[ -z "$1" ]]; then
		# Get the ticket number from the current branch.
		parseTarget="$(gBranch)"
	else
		# Get the ticket number from the input.
		parseTarget="$1"
	fi

	ticket=$("$MYDOTFILES"/bash/scripts/parseTicket.bash "$parseTarget")

	if [[ -z "$ticket" ]]; then
		echo "No ticket found in branch name/input!"
		return 1
	fi

	open -a 'google chrome' "https://jira.atl.workiva.net/browse/$ticket"
}

# returns the remote host for the repo as a url.
getHostUrl() {
	remoteHost=$(g remote get-url "$(getOriginRemote)")
	if [[ -z "$remoteHost" ]]; then
		echo "No remote found"
		return 1
	fi

	echo "Raw remoteHost is '$remoteHost'"
	if [[ "$remoteHost" == $https* ]]; then
		echo "remoteHost is web address"
	fi

	remoteHost=${remoteHost%.git}
	echo "$remoteHost"
}

# ssh HOST -G | grep "^hostname"| sed 's/hostname //'
alias trackingBranch='git rev-parse --abbrev-ref --symbolic-full-name @{u}'
alias hostCommit='open "$(getHostUrl)/commit/$(gHeadHash)"'
alias hostBranchTag='open "$(getHostUrl)/tree/$(gBranch)"'
