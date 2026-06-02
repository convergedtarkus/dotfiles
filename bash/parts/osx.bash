#!/usr/bin/env bash

# Each two letters define the colors.
#     First is foreground
#     Second is background
#
# 1.  Directory
# 2.  Symbolic link
# 3.  Socket
# 4.  Pipe
# 5.  Executable
# 6.  Block special
# 7.  Character special
# 8.  Executable with setuid bit set
# 9.  Executable with setgid bit set
# 10. Directory writable to others, with sticky bit
# 11. Directory writable to others, without sticky bit
#
# a = black
# b = red
# c = green
# d = brown
# e = blue
# f = magenta
# g = cyan
# h = light grey
# A = bold black, usually shows up as dark grey
# B = bold red
# C = bold green
# D = bold brown, usually shows up as yellow
# E = bold blue
# F = bold magenta
# G = bold cyan
# H = bold light grey; looks like bright white
# x = default foreground or background
export LSCOLORS="Exfxcxdxbxegedabagacad"

# Check if we're on Mac OS X before defining any of these aliases or functions.
if [[ "$(uname)" != "Darwin" ]]; then
	return
fi

# Desktop Programs
alias preview='open -a "preview"'
alias chrome='open -a google\ chrome'
alias finder='open -a Finder'

# open the target file in a new tab of mvim
alias mvi='open -a MacVim'

# Show/hide hidden files (for Mac OS X Mavericks)
alias showhidden='defaults write com.apple.finder AppleShowAllFiles TRUE'
alias hidehidden='defaults write com.apple.finder AppleShowAllFiles FALSE'

# From http://apple.stackexchange.com/questions/110343/copy-last-command-in-terminal
# Strips the ending newline so the command will not auto run when pasted
getLastCmd() { fc -ln -1 | awk '{$1=$1}1' | tr -d '\n' | pbcopy; }

# Copies the piped in data (echo "blah" | pbcopynonewline) minus the final newline.
# ALl lowercase for faster and eay tab completion.
pbcopynonewline() {
	allData=""
	while read -r data; do
		allData+="$data"
	done
	echo "$allData" | tr -d '\n' | pbcopy
}

# Copy the filename given as input.
# Trim the trailing newline to make sure paste doesn't trigger command line to run or do anything else weird.
copyFileName() { realpath "$1" | pbcopynonewline; }

# This was a suggestion from Reddit to fix cases where dictation appears to no longer work on Mac.
# This appears to happen more often when switching between microphones or using an external microphone.
fixDictation() {
	killall corespeechd
}

# Opens the IntelliJ Copilot configuration file in vim.
openIntellijCopilotConfig() {
	local basePath="$HOME/Library/Application Support/JetBrains/"

	# Find the latest version of IntelliJ IDEA in the JetBrains directory.
	# sort -V sorts version numbers correctly, and tail -n 1 will get the latest one.
	local latestVersion
	latestVersion=$(find "$basePath" -maxdepth 1 -name "IntelliJIdea*" 2>/dev/null | sort -V | tail -n 1)
	if [[ -z $latestVersion ]]; then
		echo "No IntelliJ IDEA versions found in $basePath"
		return 1
	else
		echo "Latest IntelliJ IDEA version found: $latestVersion"
	fi

	vim "$latestVersion/options/github-copilot.xml"
}

# #############################################
# Keychain Password Management
# #############################################

# Passwords being managed by this script. This is used for tab completion of password names.
_managedPasswords=()

# Adds the given password name to the list of managed passwords for tab completion.
_addToManagedPasswords() {
	if [[ -z $1 ]]; then
		echo "Password name cannot be empty"
		return 1
	fi
	_managedPasswords+=("$1")
}

# https://www.netmeister.org/blog/keychain-passwords.html for usage on security (OSX keychain)
# Takes in the name of the password to add.
# This will prompt for the new password value.
addGenericPassword() {
	if [[ -z $1 ]]; then
		echo "Password name cannot be empty"
		return 1
	fi
	# This will prompt for the password value to add.
	security add-generic-password -a "${USER}" -s "$1" -w
}

# Takes in the name of the password to get.
# Echos the password value to stdout.
getGenericPassword() {
	security find-generic-password -a "${USER}" -s "$1" -w
}

# Takes in the name of the password to check for.
# Returns 0 if it exists, 1 if it does not.
doesGenericPasswordExist() {
	if (getGenericPassword "$1" >/dev/null 2>&1); then
		echo "Yes"
		return 0
	else
		echo "No"
		return 1
	fi
}

# Same as doesGenericPasswordExist but does not print anything to stdout.
doesGenericPasswordExistSilent() {
	doesGenericPasswordExist "$1" >/dev/null 2>&1
}

# Takes in the name of the password to update.
# This will prompt for the new password value.
updateGenericPassword() {
	if [[ -z $1 ]]; then
		echo "Password name cannot be empty"
		return 1
	fi
	security add-generic-password -a "${USER}" -s "$1" -U -w
}

# Removes the password with the given name from the keychain.
removeGenericPassword() {
	security delete-generic-password -a "${USER}" -s "$1"
}
