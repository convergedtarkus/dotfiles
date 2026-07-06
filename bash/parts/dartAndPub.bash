#!/usr/bin/env bash

# Simple alias for running dart_dev
alias dd='dart run dart_dev'

# Quick aliases for various dart_dev tasks
alias ddAnalyze='dart run dart_dev analyze'
alias ddTest='dart run dart_dev test'
alias ddFormat='dart run dart_dev format'
alias pub='dart pub'

# Kills any dart processes. Sometimes they get stuck.
killDart() { killall -KILL dart; }

# Quickly checkout, reset or add pubspec changes
alias gcoPubspecs='git checkout "*pubspec.lock" "*pubspec.yaml"'
alias gusPubspecs='git reset "*pubspec.lock" "*pubspec.yaml"'
alias gaPubspecs='git add "*pubspec.lock" "*pubspec.yaml"'

# Resets a lot of dart enviroment files and directories to fix build issues.
dartResetEnv() {
	if command -v git >/dev/null; then
		# This ensures there are not local changes (and this is a git repo).
		if git diff-index --quiet HEAD --; then
			echo "Running git reset and clean"
			git reset --hard && safeClean
		else
			echo "There are local changes in the repo, not running git reset or clean"
		fi
	fi

	echo "Killing all dart processes"
	killDart

	echo "Removing .pub-cache"
	rm -rf ~/.pub-cache/

	echo "Removing .dartServer"
	rm -rf ~/.dartServer/

	echo "Running a pub clean"
	pubClean

	echo "Done resetting dart environment!"
}
