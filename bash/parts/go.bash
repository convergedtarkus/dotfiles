#!/usr/bin/env bash

# The GOCACHE makes tests a lot faster, but it can also hide random failures.
enableGoTestCache() { unset GOCACHE; }
disableGoTestCache() { export GOCACHE=off; }

# clear go test cache
alias goClearTestCache='go clean -testcache'

# run all go tests
alias goTestAll='go test ./...'

# run go test with verbose flag and count=1 (which bypasses all test caching)
alias gotest='go test -v -count=1'

# install go-tools staticcheck (https://github.com/dominikh/go-tools)
installStaticcheck() {
	go get -d honnef.co/go/tools/cmd/staticcheck
	# Most recent release (3/15/19)
	(cd "$GOPATH/src/honnef.co/go/tools" && git checkout 2019.1.1 && go get ./... && cd ./staticcheck && go install .)
}

# install golangci-lint (https://github.com/golangci/golangci-lint)
installGolangCiLint() {
	go get -d github.com/golangci/golangci-lint
	# Most recent release (3/31/19)
	(cd "$GOPATH/src/github.com/golangci/golangci-lint" && git checkout "v1.16.0" && cd "cmd/golangci-lint" &&
		go install -ldflags "-X 'main.version=$(git describe --tags)' -X 'main.commit=$(git rev-parse --short HEAD)' -X 'main.date=$(date)'")
}

# install goimports which is like gofmt, but does a lot more.
installGoimports() {
	go get -u golang.org/x/tools/cmd/goimports
}

# remove/install gopherJS, because of caching issues with serve
removeGopherJS() { rm -rf "$GOPATH/src/github.com/gopherjs"; }
installGopherJS() { go get -u github.com/gopherjs/gopherjs; }
reinstallGopherJS() { removeGopherJS && installGopherJS; }

# Identies all directories with changed go files and runs the given command ($1) in all those directories
# passed in command must be able to run with a single in the form `command $directory $anotherDirectroy $etc`
# Note, if this is run from non-repo root, it will only touch things at this directory and below
# E.X. `_smartGoRunner goFormat` would run `goFormat` in all directories with changed go files
# Generally should use one of the public (not `_`) smartGoBLANK style functions
_smartGoRunner() {
	# TODO Need to look into this, not sure it always works.
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

	commandToRun=$1

	# https://unix.stackexchange.com/questions/217628/cut-string-on-last-delimiter
	# echo, reverse it, get 2nd and beyond fields, reverse again
	# using `dirname` might be better, but that requires looping over lines
	endingsRemoved=$(echo "$changedFiles" | rev | cut -d'/' -f2- | rev)

	uniqueDirs=$(echo "$endingsRemoved" | sort | uniq)

	# Add './' to the start of each line as go test (and others) require it.
	# shellcheck disable=SC2001
	# As far as I know, bash cannot handle this correctly, so use sed.
	uniqueDirs=$(echo "$uniqueDirs" | sed 's|^|./|')

	# Put all the directories on a single line (separated by a space).
	commandInput=$(echo "$uniqueDirs" | tr '\n' ' ')

	echo "####"
	echo "#### Running $commandToRun $commandInput"
	echo "####"
	eval "$commandToRun" "$commandInput"
}

# Identies all directories with changed go files and runs `goFormat` in all those directories
smartGoFormat() { _smartGoRunner goFormat; }

# Identies all directories with changed go files and runs `goImports` in all those directories
smartGoImports() { _smartGoRunner goImports; }

# Identies all directories with changed go files and runs `goCiLint` in all those directories
# Passes all arguments along, use -n for only new issues.
smartGoCiLint() { _smartGoRunner "goCiLint $*"; }

# Identies all directories with changed go files and runs `go test` in all those directories
smartGoTest() { _smartGoRunner 'go test'; }

# Identies all directories with changed go files the whole suite of go checks
# This includes, `goFormat`, `goLint`, `staticcheck` and `go test`
smartGoAll() {
	smartGoImports
	smartGoCiLint -n
	smartGoTest
}

# runs 'staticcheck' in the given directory. If not input, assume the current ('.') directory.
# Removes the checks for using deprecations and missing package comments.
goStatic() {
	staticcheck -checks all,-SA1019,-ST1000 ${@:+"$@"}
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

# dep aliases
alias depEnsure='dep ensure -v'
alias depEnsureUp='dep ensure -v -update'
