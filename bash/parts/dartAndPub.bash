#!/usr/bin/env bash

# Simple alias for running dart_dev
alias dd='pub run dart_dev'

# Quick aliases for various dart_dev tasks
alias ddAnalyze='pub run dart_dev analyze'
alias ddTest='pub run dart_dev test'
alias ddFormat='pub run dart_dev format'
alias ddGenTestRunner='pub run dart_dev gen-test-runner'

# Runs dart_dev formar, analyze and test
# Normally removes deprecated member use hints from analyze output, use "-a" to include these hints.
fullDartCheck() {
	echo "###"
	echo "### Running dart_dev format ###"
	echo "###"

	dd format || return

	if [[ "$1" == "-a" ]]; then
		echo "###"
		echo "### Running normal dart_dev analyze ###"
		echo "###"
		dd analyze || return
	else
		echo "###"
		echo "### Running dart_dev analayze (no deprecated) ###"
		echo "###"
		analyzeNoDeprecated || return
	fi

	echo "###"
	echo "### Running dart_dev test ###"
	echo "###"

	dd test
}

# Runs a dart_dev analyze, but strips out deprecated member use hints.
analyzeNoDeprecated() {
	# Solution for getting the error code from https://stackoverflow.com/questions/43736021/get-exit-code-of-process-substitution-with-pipe-into-while-loop
	while read -r analyzeLine || { analyzeErrorCode=$analyzeLine && break; }; do # the or case is hit once the analyze is done and captures the exit code
		echo "$analyzeLine" | perl -pe 's/\s*?hint.+?deprecated_member_use\s*//g'
	done < <(
		dd analyze 2>&1
		printf "%s" "$?"
	) # the print will print the commands exit code

	# Return the captured error code from analyze
	return "$analyzeErrorCode"
}

# Runs a safe clean and full pub get. Good for getting up and going.
cleanAndGet() { safeClean && libAndAppGet; }

# Runs pub get in root and ./app (if it exists).
libAndAppGet() {
	pub get

	if [ -d app ]; then
		echo "Pub getting in app"
		(cd app && pub get)
	fi
}

# Removes all pub related junk anywhere in the repo (works for repos with an app/ directory as well).
pubClean() {
	echo "Removing all .pub directories"
	find . -type d -name "*.pub" -exec rm -r {} +

	echo "Removing all .packages files"
	find . -type f -name "*.packages" -exec rm {} +

	echo "Removing all packages directories"
	find . \( -type d -o -type l \) -name "*packages" -exec rm -r {} +

	if [[ $(isGitTracked pubspec.lock) == false ]]; then
		echo "Removing untracked pubspec.lock"
		rm pubspec.lock
	fi
}

# Like cleanAGet, but pub specific and probably safer.
pubCleanAndGet() { pubClean && libAndAppGet; }

# Kills any dart processes. Sometimes they get stuck.
killDart() { killall -KILL dart; }

# Quickly checkout, reset or add pubspec changes
alias gcoPubspecs='git checkout "*pubspec.lock" "*pubspec.yaml"'
alias gusPubspecs='git reset "*pubspec.lock" "*pubspec.yaml"'
alias gaPubspecs='git add "*pubspec.lock" "*pubspec.yaml"'

# quickly add all dart files
alias gaDart='git add "*.dart"'

# Needed to keep Dartium and Content-Shell working in Dart 1
export DARTIUM_EXPIRATION_TIME=1577836800

# This is using a custom installed version of Dartium, not the Dartium from Dart, keep the Chromium.app updated.
# https://webdev.dartlang.org/tools/dartium#getting-dartium
alias dartium='DART_FLAGS="--checked --load_deferred_eagerly" open /Applications/Chromium.app'

# Switch to using dart 1.24.3
switchDart1() {
	brew unlink dart
	brew unlink dart@1
	brew switch dart@1 1.24.3
	brew link --force dart@1
	dart --version
}

# Switch to using dart 2.2.0
switchDart2() {
	brew unlink dart
	brew unlink dart@1
	brew switch dart 2.3.1
	brew link dart
	dart --version
}

# Path to Dart 2 executables
export DART_2_PATH=/usr/local/opt/dart/bin/

# Use regex to get the currently-activated Dart version.
function get_current_dart_version() {
	dart --version 2>&1 | perl -n -e'/version: ([^ ]+)/ && print $1'
}

# Runs `pub get` in Dart 2 using the current Dart version as SDK constraints,
# and then runs `pub get` in Dart 1 to get the lock file in a good state.
#
# `--no-precompile` is important here so that Pub doesn't try
# and fail to compile Dart 1 executables under Dart 2.
#
# Unlike an alias (in Bash), this function also passes any
# additional arguments along to `pub`.
function pub2get() {
	echo "Using Dart 2 solver under Dart $(get_current_dart_version)"
	_PUB_TEST_SDK_VERSION="$(get_current_dart_version)" "$DART_2_PATH/pub" get --no-precompile "$@" && pub get --offline "$@"
}

function pub2upgrade() {
	echo "Using Dart 2 solver under Dart $(get_current_dart_version)"
	_PUB_TEST_SDK_VERSION="$(get_current_dart_version)" "$DART_2_PATH/pub" upgrade --no-precompile "$@" && pub get --offline "$@"
}
