#!/usr/bin/env bash

# clear go test cache
alias goClearTestCache='go clean -testcache'

# run go test with count=1 (which bypasses all test caching)
alias goTestQuiet='go test -count=1'
# run go test with verbose flag and count=1 (which bypasses all test caching)
alias goTest='go test -count=1 -v'
# run all go tests. Uses -count=1 to bust all go test caches so all tests are run from scratch even if no changes have been made.
alias goTestAll='_goTestAll -count=1'
# Uses go test to build all the go tests but not run them. Helpful for finding compile errors without seeing test failure noise.
alias goTestBuildOnly='go test ./... -count=1 -run="^$"'
# run all go tests without any caching busting.
alias goTestAllCache='_goTestAll'

# Helps to use my goInstall.bash script which is asdf aware and
alias goInstall='_goInstall'
alias goInstallAll='_goInstall --all'
alias goInstallSmart='_goInstall --smart'
alias goInstallSmartAll='_goInstall --smart --all'
alias goInstallAllSmart='_goInstall --all --smart'
_goInstall() {
	if SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && [[ -f "$SCRIPT_DIR/../scripts/goInstall.bash" ]]; then
		"$SCRIPT_DIR/../scripts/goInstall.bash" "$@"
	else
		echo "Cannot find goInstall.bash"
		return 1
	fi
}

# Allows running all the test in a single go file (given as the first argument to this function)
# Any additional arguments are passed directly to the go test command (-v --count etc).
goTestFile() {
	# The whole path to the file './blah/blah/file.go'
	filePath="$1"

	# Make sure an argument is provided.
	if [[ -z $filePath ]]; then
		printf "\033[33mFirst argument must be provided and be the path to the file!\033[0m\n"
		return 1
	fi

	# Make sure the file exists.
	if [[ ! -f $filePath ]]; then
		printf "\033[33mFirst argument does not point to a file!\033[0m\n"
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

	# Get the rest of the input arguments and check if -count is set. If not,
	# add a -count=1 argument to bust test caches.
	inputArgs=("${@:2}")
	for i in "${inputArgs[@]}"; do
		if [[ $i == "-count"* ]]; then
			hasCount="true"
		fi
	done

	# No -count argument provided, add it.
	if [[ -z $hasCount ]]; then
		inputArgs=("${inputArgs[@]}" "-count=1")
	fi

	# Run the test.
	go test "$testDir" --run "$testRunRegex" "${inputArgs[@]}"
}

# Helper for go test ./... that adds output for test run status.
# Aggregates all stderr output and displays it at the end so it is easier to find.
_goTestAll() {
	# Capture stderr while still displaying everything in real-time
	# The fancy routing and error capturing is AI generated code.
	local errorOutput
	local exitCode

	# Set pipefail to ensure we capture the correct exit code
	local oldPipefail
	oldPipefail=$(set +o | grep pipefail)
	set -o pipefail

	# Redirect stderr through tee to both display and capture it
	# Run the command, capturing stderr to a temporary location
	exec 3>&1
	errorOutput=$(
		go test ./... "$@" 2>&1 1>&3 | tee /dev/stderr
		# Return the exit code of go test (first element in PIPESTATUS)
		exit "${PIPESTATUS[0]}"
	)
	exitCode=$?
	exec 3>&-

	# Restore pipefail setting
	eval "$oldPipefail"

	echo
	if [[ $exitCode == 0 ]]; then
		printf "\033[32mAll tests passed!\033[0m\n"
	elif [[ $exitCode == 1 ]]; then
		printf "\033[31mSOME TESTS FAILED!\033[0m\n"
	else
		printf "\033[34;1mExit code '%s'. There may be build or package structure issues.\033[0m\n" "$exitCode"
		printf "\033[34;1mThis does not necessarily mean any tests failed though.\033[0m\n"
	fi

	# If there was error output, display it at the end
	if [[ -n $errorOutput ]]; then
		echo
		printf "\033[33m========================================\033[0m\n"
		printf "\033[33mError Output Summary:\033[0m\n"
		printf "\033[33m========================================\033[0m\n"
		printf '%s\n' "$errorOutput"
		printf "\033[33m========================================\033[0m\n"
	fi
}

# install golangci-lint (https://github.com/golangci/golangci-lint)
installGolangCiLint() {
	if [[ -z $1 ]]; then
		version="v1.51.1"
	else
		version="$1"
	fi
	# Pass along extra arguments as well (expect the first).
	goInstall "github.com/golangci/golangci-lint/v2/cmd/golangci-lint@$version" "${@:1}"
}

# Installs shfmt through go.
installShfmt() {
	# Pass along extra arguments as well (expect the first).
	goInstall "mvdan.cc/sh/v3/cmd/shfmt" "${@:1}"
}

# Identifies all directories with changed go files and runs `goFormat` in all those directories
smartGoFormat() { smartgorunner --on-files gofmt -w; }

# Identifies all directories with changed go files and runs `goImports` in all those directories
smartGoImports() { smartgorunner --on-files goimports -w; }

# Identifies all directories with changed go files and runs `goCiLint` in all those directories
# Passes all arguments along, use -n for only new issues.
smartGoCiLint() { smartgorunner golangci-lint run -c "$MYDOTFILES/.golangci.yml" "$@"; }

# Identifies all directories with changed go files and runs `go test` in all those directories
smartGoTest() { smartgorunner go test "$@"; }

# Identifies all directories with changed go files and runs `go build` in all those directories
smartGoBuild() { smartgorunner go build "$@"; }

# Identifies all directories with changed go files the whole suite of go checks
# This includes, `goFormat`, `goLint`, `staticcheck` and `go test`
smartGoAll() {
	# Loop over the arguments and figure out which apply to the variation functions being run.
	# Currently only the -short option is supported (passed to go test).
	local -a testArgs=()
	for arg in "$@"; do
		case "$arg" in
		"-short")
			testArgs+=("$arg")
			;;
		esac
	done

	smartGoImports || return
	# Use count=1 so no tests run without the test cache.
	smartGoTest -count=1 "${testArgs[@]}" || return
	smartGoCiLint -n
}

# A variation of smartGoAll that runs all tests rather than over just the changed directories.
# The name is silly, but it works I guess.
smartGoAllAll() {
	# Loop over the arguments and figure out which apply to the variation functions being run.
	# Currently only the -short option is supported (passed to go test).
	local -a testArgs=()
	for arg in "$@"; do
		case "$arg" in
		"-short")
			testArgs+=("$arg")
			;;
		esac
	done

	smartGoImports || return
	# Use count=1 so no tests run without the test cache.
	goTestAll "${testArgs[@]}" || return
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
	input=("$@")
	if [[ ${#input[@]} -eq 0 ]]; then
		input=(".")
	fi

	gofmt -w "${input[@]}"
}

# runs `goimports -w` in the given directory. If no input, assume the current ('.') directory
goImports() {
	input=("$@")
	if [[ ${#input[@]} -eq 0 ]]; then
		input=(".")
	fi

	goimports -w "${input[@]}"
}

# runs `golint` in the given directory. If no input, assume the current ('.') directory
goLint() {
	input=("$@")
	if [[ ${#input[@]} -eq 0 ]]; then
		input=(".")
	fi

	golint "${input[@]}"
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

	echo "Removing go pkg directory (FYI, this is running with sudo)"
	sudo rm -rf "$GOPATH/pkg/"

	echo "Using go clear to clean cache, mod cache and all binaries"
	# i = removes installed binaries
	# r = Applies recursively to import paths.
	go clean -cache -modcache -testcache -fuzzcache -i -r

	echo "Done resetting go environment!"
}

symlinkVendorPackage() {
	# The "$@" passes all arguments to the symlink script.
	"$MYDOTFILES/bash/scripts/symlinkPackageIntoVendor.bash" "$@"
}

# Helper to easily move the vendor directory. Pairs with the symlinkVendorPackage function.
backupVendorDir() {
	if [[ ! -d ./vendor ]]; then return; fi
	mv ./vendor ./vendor_bak
}

# Helper to undo backupVendorDir
restoreVendorDir() {
	if [[ ! -d ./vendor_bak ]]; then return; fi
	mv ./vendor_bak ./vendor
}

# Resets all vendor directories, go.mod and go.sum files in the repo.
# This handles repos with nested vendor directories.
# Using git diff is much faster than using a find command.
gResetVendor() {
	(cat <(git diff --name-only | grep -E '(^vendor/|/vendor/)' | awk -F'^vendor|/vendor/' '{print $1"/vendor/"}' | sort -u | sed 's|^/vendor/$|./vendor|g') <(git diff --name-only | grep -E '(go.mod|go.sum)')) | sort -u | xargs git checkout --
}
