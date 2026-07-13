#!/usr/bin/env bash

# Completes resolveCommand arguments: known commands plus supported flags.
_completeResolveCommand() {
	local -r currentWord=${COMP_WORDS[COMP_CWORD]}

	# Generate completions from both supported flags and known commands.
	# `compgen -W` generates completions from a wordlist.
	# `compgen -c` generates completions from bash's known commands (aliases, functions, builtins, executables).
	mapfile -t COMPREPLY < <(
		compgen -W "-v --verbose -l --line --help" -- "$currentWord"
		compgen -c -- "$currentWord"
	)
}

# Completes only executable program names found in PATH.
# Searches each PATH directory directly rather than filtering all known commands,
# which avoids the per-candidate `type -t` subprocess cost.
_completePrograms() {
	local -r currentWord=${COMP_WORDS[COMP_CWORD]}

	local programs=()
	# Associative array used to deduplicate names that appear in multiple PATH dirs.
	local -A seen=()
	local pathDirs
	# `IFS=:` sets the field separator to colon so `read -ra` splits PATH into an array.
	IFS=: read -ra pathDirs <<<"$PATH"
	readonly pathDirs

	local dir
	for dir in "${pathDirs[@]}"; do
		[[ -d $dir ]] || continue
		readonly dir

		# `compgen -f` generates file path completions under the given directory prefix.
		local matches
		mapfile -t matches < <(compgen -f -- "$dir/$currentWord")

		local curMatch
		for curMatch in "${matches[@]}"; do
			readonly curMatch
			local name="${curMatch##*/}"
			# `-x` checks the file is executable; skip names already seen from earlier PATH dirs.
			if [[ -x $curMatch && -z ${seen[$name]+x} ]]; then
				seen[$name]=1
				programs+=("$name")
			fi
		done
	done

	COMPREPLY=("${programs[@]}")
}

# Completes command names managed by asdf, matching what `asdf which` accepts.
# Reads from the asdf shims directory directly rather than invoking asdf.
_completeAsdfShims() {
	local currentWord=${COMP_WORDS[COMP_CWORD]}

	# ASDF_DATA_DIR defaults to ~/.asdf when not set.
	local shimDir="${ASDF_DATA_DIR:-$HOME/.asdf}/shims"
	if [[ ! -d $shimDir ]]; then
		COMPREPLY=()
		return 0
	fi

	local matches
	# `compgen -f` generates file path completions; prefixing with shimDir scopes the search there.
	mapfile -t matches < <(compgen -f -- "$shimDir/$currentWord")

	# Strip the directory prefix from each match, keeping only the bare command name.
	# The `##*/` parameter expansion removes everything up to and including the last `/`.
	COMPREPLY=("${matches[@]##*/}")
}

# `complete -F` tells bash to call the named function to generate completions for a command.
complete -F _completeResolveCommand resolveCommand
complete -F _completePrograms _deleteNormalCommand deleteAllCommand deleteCommand
complete -F _completeAsdfShims asdfPath deleteAsdfCommand
