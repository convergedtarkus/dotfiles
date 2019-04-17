#!/bin/bash

# Desktop Programs
alias preview="open -a 'preview'"
alias chrome="open -a google\ chrome"
alias finder='open -a Finder '
alias sublime="open -a 'Sublime Text'"

# open the target file in a new tab of mvim
alias mvi="open -a MacVim"

# Show/hide hidden files (for Mac OS X Mavericks)
alias showhidden="defaults write com.apple.finder AppleShowAllFiles TRUE"
alias hidehidden="defaults write com.apple.finder AppleShowAllFiles FALSE"

# From http://apple.stackexchange.com/questions/110343/copy-last-command-in-terminal
# Strips the ending newline so the command will not auto run when pasted
getLastCmd() { fc -ln -1 | awk '{$1=$1}1' | tr -d '\n' | pbcopy; }
