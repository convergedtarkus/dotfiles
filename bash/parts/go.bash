#!/usr/bin/env bash

# Wrapper to use the latest version of a given go version.
# E.X. useGoVersion 1.18
useGoVersion() {
	if asdf global golang latest:"$1"; then
		echo "New go version '$(go version)'"
	else
		echo "Failed to switch go version. Version is '$(go version)'"
	fi
}

# Alias for easily generating or removing vendor folder.
alias gmv='go mod vendor'
alias gmvr='rm -rf ./vendor'

# clear go test cache
alias goClearTestCache='go clean -testcache'

# run go test with count=1 (which bypasses all test caching)
alias goTestQuiet='go test -count=1'
# run go test with verbose flag and count=1 (which bypasses all test caching)
alias goTest='go test -count=1 -v'
# run all go tests. Uses -count=1 to bust all go test caches so all tests are run from scratch even if no changes have been made.
alias goTestAll='_goTestAll -count=1'
# run all go tests without any caching busting.
alias goTestAllCache='_goTestAll'

# Allows running all the test in a single go file (given as the first argument to this function)
# Any additional arguments are passed directly to the go test command (-v --count etc).
goTestFile() {
	# The whole path to the file './blah/blah/file.go'
	filePath="$1"

	if [[ -z "$filePath" ]]; then
		printf "\033[33mMust provide an input file!\033[0m\n"
		return 1
	fi

	# Use perl to get all the tests in the file
	matchingTests=$(perl -ne '/^func (Test.+?)\(/ && print "$1\n";' "$filePath")

	# Insert a '|' between each test name to for a big regex or statement.
	testRunRegex=$(echo "$matchingTests" | tr '\n' '|')

	# Remove the trailing '|' (otherwise all tests in the directory will be run)
	testRunRegex=${testRunRegex%|}

	# Get just the directory path ('./blah/blah')
	testDir=$(dirname "$filePath")

	# Run the test, any arguments after the first are applied to the test command.
	go test "$testDir" --run "$testRunRegex" "${@:2}" -count=1
}

# Helper for go test ./... that adds output for test run status.
_goTestAll() {
	go test ./... "$@"
	exitCode="$?"
	echo
	if [[ "$exitCode" == 0 ]]; then
		printf "\033[32mAll tests passed!\033[0m\n"
	elif [[ "$exitCode" == 1 ]]; then
		printf "\033[31mSOME TESTS FAILED!\033[0m\n"
	else
		printf "\033[34;1mExit code '%s'. There may be build or package structure issues.\033[0m\n" "$exitCode"
		printf "\033[34;1mThis does not necessarily mean any tests failed though.\033[0m\n"
	fi
}

# install golangci-lint (https://github.com/golangci/golangci-lint)
installGolangCiLint() {
	if [[ -z "$1" ]]; then
		version="v1.51.1"
	else
		version="$1"
	fi
	GO111MODULE=off go get -d github.com/golangci/golangci-lint
	(cd "$(go env GOPATH)"/src/github.com/golangci/golangci-lint/ && git fetch --all --prune --tags && git checkout "$version" && cd cmd/golangci-lint &&
		go install -ldflags "-X 'main.version=$(git describe --tags)' -X 'main.commit=$(git rev-parse --short HEAD)' -X 'main.date=$(date)'")
}

# install goimports which is like gofmt, but does a lot more.
installGoimports() {
	go get -u golang.org/x/tools/cmd/goimports
}

# Can be given to _smartGoRunner to run the command on the changes files rather than directories.
readonly _runOnFiles="--runOnFiles"

# Identies all directories with changed go files and runs the given command ($1) in all those directories
# passed in command must be able to run with a single in the form `command $directory $anotherDirectroy $etc`
# In addition, _runOnFiles can be given as the first argument to this function to run the given command (which is
# the second argument) on all changed files rather than directories.
# Note, if this is run from non-repo root, it will only touch things at this directory and below
# E.X. `_smartGoRunner "go test"` would run `go test` in all directories with changed go files
# E.X. `_smartGoRunner "$_runOnFiles" "gofmt -w"` would run `gofmt -w` on all changed go files.
# Generally should use one of the public (not `_`) smartGoBLANK style functions
# TODO The _runOnFiles approach works, but man is it gross. Probably better to have a different
#   function for it, but need to finda good way to share logic in base (passing arguments will
#   be a pain).
_smartGoRunner() {
	# Throw an alert if not at the repo root just so no mistakes are made
	if [[ $(git rev-parse --show-toplevel) != $(pwd) ]]; then
		echo "FYI: Not running at repo root, not all files may be processed"
		echo
	fi

	# Print changed files, no deleted files, .go files only regardless of index or working tree.
	# The --relative flag returns paths relative to the current path, allowing running in sub-directories.
	# Use grep to remove any entries from the vendor directory as these should never be touched.
	changedFiles=$(git diff HEAD --relative --name-only --diff-filter=d -- '*.go' | grep -v '^vendor/')
	if [[ "$changedFiles" == "" ]]; then
		echo "No changed files found, aborting"
		return 0
	fi

	# Add './' to the start of each line as go test (and others) require it.
	# This also allows for correct handling of test files at the current directroy level.
	# shellcheck disable=SC2001
	# As far as I know, bash cannot handle this correctly, so use sed.
	changedFiles=$(echo "$changedFiles" | sed 's|^|./|')

	commandToRun=""
	commandInput=""
	if [[ "$1" == "$_runOnFiles" ]]; then
		commandToRun=$2

		# Put all the directories on a single line (separated by a space).
		commandInput="$changedFiles"
	else
		commandToRun=$1

		# Remove the final trailing /file.go to get only directories.
		# https://unix.stackexchange.com/questions/217628/cut-string-on-last-delimiter
		# echo, reverse it, get 2nd and beyond fields, reverse again
		# using `dirname` might be better, but that requires looping over lines
		endingsRemoved=$(echo "$changedFiles" | rev | cut -d'/' -f2- | rev)

		# Get a list of all the unique directories to use as the command input.
		commandInput=$(echo "$endingsRemoved" | sort | uniq)
	fi

	# Put all the directories on a single line (separated by a space).
	commandInput=$(echo "$commandInput" | tr '\n' ' ')

	echo "####"
	echo "#### Running $commandToRun $commandInput"
	echo "####"
	eval "$commandToRun" "$commandInput"
}

# Identies all directories with changed go files and runs `goFormat` in all those directories
smartGoFormat() { _smartGoRunner "$_runOnFiles" goFormat; }

# Identies all directories with changed go files and runs `goImports` in all those directories
smartGoImports() { _smartGoRunner "$_runOnFiles" goImports; }

# Identies all directories with changed go files and runs `goCiLint` in all those directories
# Passes all arguments along, use -n for only new issues.
smartGoCiLint() { _smartGoRunner "goCiLint $*"; }

smartGoCiLintFiles() {
	echo "#### Limiting results to changed files only."
	rawChangedFiles=$(git diff HEAD --name-only)

	# Turn the changed files into one big or regex.
	changedFiles=""
	while read -r line; do
		changedFiles+="$line:|"
	done <<<"$rawChangedFiles"
	# Trim off the last '|' to make the regex valid.
	changedFiles="${changedFiles::-1}"

	# 0 = no match yet
	# 1 = found a match
	matchState="0"

	while read -r outputLine; do
		# _smartGoRunner uses this pattern for comments and logging, so don't filter it out.
		if [[ "$outputLine" == '####'* ]]; then
			echo "$outputLine"
			continue
		fi

		if [[ "$matchState" -eq "1" ]]; then
			# Look for a line starting with a control character and [1m which matches the
			# color formatting golangci-lint uses when printing a lint match.
			if echo "$outputLine" | grep -q '^[[:cntrl:]]\[1m'; then
				matchState="0"
			else
				# Otherwise echo the line as it relates to a changed file (or is sometype
				# of important log/error).
				echo "$outputLine"
				continue
			fi
		fi

		# Match a line that contains any of the currently changed files.
		if echo "$outputLine" | grep -qE "$changedFiles"; then
			echo "$outputLine"
			matchState="1"
		fi
	done <<<$(_smartGoRunner "goCiLint --color=always $*")
}

# Identies all directories with changed go files and runs `go test` in all those directories
smartGoTest() { _smartGoRunner "go test $*"; }

# Identies all directories with changed go files and runs `go build` in all those directories
smartGoBuild() { _smartGoRunner "go build $*"; }

# Identies all directories with changed go files the whole suite of go checks
# This includes, `goFormat`, `goLint`, `staticcheck` and `go test`
smartGoAll() {
	# Loop over the arguments and figure out which apply to the variation functions being run.
	# Currently only the -short option is supported (passed to go test).
	testArgs=""
	for arg in "$@"; do
		case "$arg" in
		"-short")
			if [[ -n "$testArgs" ]]; then
				testArgs="$testArgs "
			fi
			testArgs="$testArgs$arg"
			;;
		esac
	done

	smartGoImports
	# Use count=1 so no tests run without the test cache.
	smartGoTest -count=1 "$testArgs"
	smartGoCiLint -n
}

# A variation of smartGoAll that runs all tests rather than over just the changed directories.
# The name is silly, but it works I guess.
smartGoAllAll() {
	# Loop over the arguments and figure out which apply to the variation functions being run.
	# Currently only the -short option is supported (passed to go test).
	testArgs=""
	for arg in "$@"; do
		case "$arg" in
		"-short")
			if [[ -n "$testArgs" ]]; then
				testArgs="$testArgs "
			fi
			testArgs="$testArgs$arg"
			;;
		esac
	done

	smartGoImports
	# Use count=1 so no tests run without the test cache.
	goTestAll "$testArgs"
	smartGoCiLint -n
}

# Runs 'golangci-lint' using my global config file.
# Passes arguments to the command so `goCiLint -n` or `goCiLint ./path` etc work.
goCiLint() {
	# $@ will keep each passed in parameter quotes vs $* that will not
	golangci-lint run -c "$MYDOTFILES/.golangci.yml" "$@"
}

# runs `gofmt -w` in the given directory. If no input, assume the current ('.') directory
goFormat() {
	input=$*
	if [[ -z "$input" ]]; then
		input="."
	fi

	gofmt -w $input
}

# runs `goimports -w` in the given directory. If no input, assume the current ('.') directory
goImports() {
	input=$*
	if [[ -z "$input" ]]; then
		input="."
	fi

	goimports -w $input
}

# runs `golint` in the given directory. If no input, assume the current ('.') directory
goLint() {
	input=$*
	if [[ $input == "" ]]; then
		input="."
	fi

	golint $input
}

# populate these two variables with options for paths to not delete when running cleanGoPath. These will be given to a find command.
export cleanGoPathDomainProtected=""                            # E.X '! -name github.com' to ignore all go packages coming from the 'github.com' domain
export cleanGoPathGithubUserProtected="! -name convergedtarkus" # Of course I protect my repos, they are just too awesome to delete

cleanGoPath() {
	# the "$*" passes all arguments to the symlink script
	eval "$MYDOTFILES/bash/scripts/cleanGoPath.bash $*"
}

# Resets a lot of go environment files to fix build issues.
# gopherjs is often an issue so delete it as well.
goResetEnv() {
	if command -v git >/dev/null; then
		# This ensures there are not local changes (and this is a git repo).
		if git diff-index --quiet HEAD --; then
			echo "Running git reset and clean"
			git reset --hard && safeClean
		else
			echo "There are local changes in the repo, not running git reset or clean"
		fi
	fi

	echo "Removing gopherjs from go bin"
	rm -rf "$GOPATH/bin/gopherjs"

	echo "Removing gopherjs from src"
	rm -rf "$GOPATH/src/github.com/gopherjs/"

	echo "Removing go pkg directory (FYI, this is running with sudo)"
	sudo rm -rf "$GOPATH/pkg/"

	echo "Using go clear to clean cache, mod cache and all binaries"
	go clean -cache -i -r
	# i = removes installed binaries
	# r = Applies recursively to import paths.
	go clean -modcache -i -r

	echo "Done resetting go environment!"
}

symlinkVendorPackage() {
	# the "$*" passes all arguments to the symlink script
	eval "$MYDOTFILES/bash/scripts/symlinkPackageIntoVendor.bash $*"
}

# Helper to easily move the vendor directory. Pairs with the symlinkVendorPackage function.
backupVendorDir() {
	if [ ! -d ./vendor ]; then return; fi
	mv ./vendor ./vendor_bak
}

# Helper to undo backupVendorDir
restoreVendorDir() {
	if [ ! -d ./vendor_bak ]; then return; fi
	mv ./vendor_bak ./vendor
}
