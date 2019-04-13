# Parse the given input (branch name) to extract a jira ticket or github issue number.
# Jira ticket follows the form [A-Z]+-[0-9]+ and be at the start of the input.
# Github issue follows the form #[0-9]+ and must be at the end of the input.
# The extract ticket/issue is echoed. Nothing is echoed if nothing is found.
# Example
#   TEAM-123DoWork > 'TEAM-123'
#   FixStuff#14 > '#14'
#   IBrokeItAll > (nothing)
#   TEAM-123FixIt#15 > (nothing)

input="$1"
jiraTicket=$(echo "$input" | grep -o '^[A-Z]\+-[0-9]\+')
githubIssue=$(echo "$input" | grep -o '#[0-9]\+$')

if [[ ! -z "$jiraTicket" && ! -z "$githubIssue" ]]; then
	# both set, so don't do anything
	exit 1
elif [[ ! -z "$jiraTicket" ]]; then
	echo "$jiraTicket"
	exit 0
elif [[ ! -z "$githubIssue" ]]; then
	echo "$githubIssue"
	exit 0
fi

exit 0
