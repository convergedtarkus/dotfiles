#!/bin/bash

# Simple alias for running dart_dev
alias dd='pub run dart_dev'

# Quick aliases for various dart_dev tasks
alias ddAnalyze='dd analyze'
alias ddTest='dd test'
alias ddFormat='dd format'
alias ddGenTestRunner='dd gen-test-runner'

# TODO Add a way to run custom dd analyze based on repo
# Runs a full dart check, formats files, runs analysis, runs all tests
fullDartCheck() {
	echo "###"
	echo "### Running ddev format ###"
	echo "###"

	dd format || return

	echo "###"
	echo "### Running normal ddev analyze ###"
	echo "###"
	dd analyze || return

	echo "###"
	echo "### Running ddev test ###"
	echo "###"

	dd test
}

# Runs a dart_dev analyze that removes deprecated warnings.
noDeprecatedAnalyze() {
	command pub run dart_dev analyze | perl -pe 's/(\s+?hint.+?deprecated_member_use\s)//g'
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
alias dartium="DART_FLAGS='--checked --load_deferred_eagerly' open /Applications/Chromium.app"

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
	brew switch dart 2.2.0
	brew link dart
	dart --version
}

# Path to Dart 2 executables
export DART_2_PATH=/usr/local/opt/dart/bin/

# The Dart SDK version you wish to solve under
export CURRENT_DART_VERSION=1.24.3

# Runs `pub get` in Dart 2 using the current Dart version as SDK constraints,
# and then runs `pub get` in Dart 1 to get the lock file in a good state.
#
# `--no-precompile` is important here so that Pub doesn't try
# and fail to compile Dart 1 executables under Dart 2.
#
# Unlike an alias (in Bash), this function also passes any
# additional arguments along to `pub`.
pub2get() {
	_PUB_TEST_SDK_VERSION="$CURRENT_DART_VERSION" "$DART_2_PATH/pub" get --no-precompile "$@" && pub get --offline "$@"
}

pub2upgrade() {
	_PUB_TEST_SDK_VERSION="$CURRENT_DART_VERSION" "$DART_2_PATH/pub" upgrade --no-precompile "$@" && pub get --offline "$@"
}
