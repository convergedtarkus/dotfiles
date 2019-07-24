#!/usr/bin/env bash

# Parse the given input (branch name) to extract a jira ticket or github issue number.
# Jira ticket follows the form [A-Z]+-[0-9]+ and be at the start of the input.
# Github issue follows the form #[0-9]+ and must be at the end of the input.
# The extract ticket/issue is echoed. Nothing is echoed if nothing is found.
# Example
#  TEAM-123DoWork > 'TEAM-123'
#  FixStuff#14 > '#14'
#  IBrokeItAll > (nothing)
#  TEAM-123FixIt#15 > (nothing)
#  TEAM-123RevertTEAM-666 > 'TEAM-123'
#  revert#13#14 > '#14'
#    The above two are intentional to handle referencing a ticket/issue in the branch name.

input="$1"
jiraTicket=$(echo "$input" | grep -o '^[A-Z]\+-[0-9]\+')
githubIssue=$(echo "$input" | grep -o '#[0-9]\+$')

if [[ -n "$jiraTicket" && -n "$githubIssue" ]]; then
	# both set, so don't do anything
	exit 1
elif [[ -n "$jiraTicket" ]]; then
	echo "$jiraTicket"
	exit 0
elif [[ -n "$githubIssue" ]]; then
	echo "Issue $githubIssue"
	exit 0
fi

exit 0
