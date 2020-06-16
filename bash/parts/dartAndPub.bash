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
		echo "$analyzeLine" | perl -pe 's/\s*?hint.+?deprecated_member_use(_from_same_package)?\s*//g'
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
	find . \( -type d -o -type l \) -not -path "./vendor/*" -name "*packages" -exec rm -r {} +

	if [[ -f "pubspec.lock" && $(isGitTracked pubspec.lock) == false ]]; then
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

	echo "Removing .pub-cache"
	rm -rf ~/.pub-cache/

	echo "Removing .dartServer"
	rm -rf ~/.dartServer/

	echo "Running a pub clean"
	pubClean

	echo "Done resetting dart environment!"

}
