#!/usr/bin/env bash

_goModReplaceCompletion() {
	#echo "1: '$1'"
	#echo "2: '$2'"
	#echo "3: '$3'"
	#echo "COMP_LINE: '$COMP_LINE'"
	#echo "COMP_POINT: '$COMP_POINT'"
	#echo "COMP_KEY: '$COMP_KEY'"
	#echo "COMP_TYPE: '$COMP_TYPE'"
	#echo "COMP_WORDS: '${COMP_WORDS[*]}'"
	#echo "COMP_CWORD: '$COMP_CWORD'"
	currentWord="${COMP_WORDS[$COMP_CWORD]}"

	numArgs=${#COMP_WORDS[@]}
	#echo "numArgs: $numArgs'"
	# TODO Look at go.mod for repro names too?
	# TODO Look at local branches for reference completion?
	# TODO Look at all branches/tags for completion?
	# TODO Support completion at the non-last word.
	if ((numArgs % 2 == 0)); then
		# Trying to complete a repro name.
		if [[ -z "$GOPATH" ]]; then
			# No Gopath so no way to get repro names.
			return
		fi

		readarray -d '' options < <(find "$GOPATH/src/github.com/Workiva" -type d -maxdepth 1 -mindepth 1 -exec basename {} \;)
		COMPREPLY=($(compgen -W "${options[*]}" -- "$currentWord"))
	else
		# Trying to complete a version.
		COMPREPLY=(local)
	fi
}

# Complete goTestFile with _test.go files and directories.
complete -f -X '!*_test.go' -o plusdirs goTestFile

complete -F _goModReplaceCompletion goModReplaceWorkiva
complete -F _goModReplaceCompletion goModReplaceWorkivaRepro
