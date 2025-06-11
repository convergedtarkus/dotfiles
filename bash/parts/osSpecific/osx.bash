#!/usr/bin/env bash

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
