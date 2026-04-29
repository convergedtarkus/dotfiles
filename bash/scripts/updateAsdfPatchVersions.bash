#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Prints script usage.
usage() {
	cat <<'EOF'
Usage: updateAsdfPatchVersions.bash [--dry-run] [--verbose] [--help]

Updates installed asdf tool versions to the latest patch release in the same
major.minor series. Example: 1.20.7 -> 1.20.8.

Options:
  --dry-run        Show planned installs/uninstalls without making changes.
  --verbose        Print debug-level logs to stderr while running.
  --help           Show this help text.
EOF
}

# Initializes ANSI color codes for terminal output.
init_colors() {
	COLOR_RED=''
	COLOR_YELLOW=''
	COLOR_GREEN=''
	COLOR_RESET=''

	# Only use colors when stderr is an interactive terminal and NO_COLOR is not set.
	# -t 2 checks whether stderr is interactive (a real terminal).
	# NO_COLOR is a common convention to disable colored output in scripts.
	if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
		COLOR_RED=$'\033[31m'
		COLOR_YELLOW=$'\033[33m'
		COLOR_GREEN=$'\033[32m'
		COLOR_RESET=$'\033[0m'
	fi
}

# Returns a colorized message for the provided level.
colorize_for_level() {
	local level="$1"
	local text="$2"
	local color=''

	case "$level" in
	ERROR)
		color="$COLOR_RED"
		;;
	WARNING)
		color="$COLOR_YELLOW"
		;;
	SUCCESS)
		color="$COLOR_GREEN"
		;;
	esac

	if [[ -n "$color" ]]; then
		printf '%b%s%b' "$color" "$text" "$COLOR_RESET"
		return 0
	fi

	printf '%s' "$text"
}

# Writes a log line to the configured log file and optionally to stderr.
log_line() {
	local level="$1"
	local message="$2"
	local timestamp
	timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
	local line="${timestamp} ${level} !!!! updateAsdfPatchVersions.bash - ${message}"

	echo "$line"
	if [[ "$VERBOSE" == "1" || "$level" != "DEBUG" ]]; then
		colorize_for_level "$level" "$line" >&2
		echo >&2
	fi
}

# Logs an informational message.
log_info() {
	log_line "INFO" "$1"
}

# Logs a debug message that is useful for troubleshooting.
log_debug() {
	log_line "DEBUG" "$1"
}

# Logs a warning message.
log_warn() {
	log_line "WARNING" "$1"
}

# Logs an error message.
log_error() {
	log_line "ERROR" "$1"
}

# Logs a success message.
log_success() {
	log_line "SUCCESS" "$1"
}

# Returns 0 when the version is strict semver (X.Y.Z), otherwise 1.
is_semver_patch() {
	local version="$1"
	[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# Extracts the major.minor prefix from a strict semver (X.Y.Z).
major_minor_prefix() {
	local version="$1"
	echo "${version%.*}"
}

# Trims leading/trailing whitespace.
trim() {
	local value="$1"
	# Remove leading whitespace.
	value="${value#"${value%%[![:space:]]*}"}"
	# Remove trailing whitespace.
	value="${value%"${value##*[![:space:]]}"}"
	echo "$value"
}

# Returns 0 if value is already in a newline-delimited list.
contains_line() {
	local list="$1"
	local value="$2"
	grep -Fqx "$value" <<<"$list"
}

# Runs an asdf command, captures combined stdout/stderr into a variable, and
# returns the original exit code for explicit error handling by callers.
# Usage: run_asdf_capture <result_var_name> <asdf_args...>
run_asdf_capture() {
	# Get the variable name to store the output in and shift it out of the way to get the asdf args.
	local result_var_name="$1"
	shift

	# Run the asdf command.
	local output
	output="$(asdf "$@" 2>&1)"

	local status=$?
	# Print the output to the passed in variable name.
	printf -v "$result_var_name" '%s' "$output"
	return "$status"
}

# Updates installed asdf versions to latest patch for each major.minor.
update_installed_patch_versions() {
	local dry_run="$1"
	local seen_targets=""
	local changed=0

	log_debug "Starting update pass (dry_run=$dry_run)"

	if ! command -v asdf >/dev/null 2>&1; then
		log_error "asdf command not found in PATH"
		return 1
	fi

	local plugin_list
	if ! run_asdf_capture plugin_list plugin list; then
		log_error "Failed to list asdf plugins: $plugin_list"
		return 1
	fi

	while IFS= read -r tool; do
		tool="$(trim "$tool")"
		[[ -z "$tool" ]] && continue
		log_debug "Checking tool '$tool'"

		local version_list
		if ! run_asdf_capture version_list list "$tool"; then
			log_warn "Skipping tool '$tool' because 'asdf list $tool' failed: $version_list"
			continue
		fi

		while IFS= read -r raw_version; do
			local version
			version="$(trim "$raw_version")"
			# `asdf list` prefixes the active version with `*`; strip it before semver parsing.
			version="${version#\*}"
			version="$(trim "$version")"
			[[ -z "$version" ]] && continue

			if ! is_semver_patch "$version"; then
				log_warn "Skipping $tool $version (not strict X.Y.Z semver)"
				continue
			fi

			local prefix
			prefix="$(major_minor_prefix "$version")"

			local latest
			if ! run_asdf_capture latest latest "$tool" "$prefix"; then
				log_warn "Skipping $tool $version because 'asdf latest $tool $prefix' failed with: $latest"
				continue
			fi

			if [[ -z "$latest" ]]; then
				log_warn "Skipping $tool $version (could not find latest for $prefix.x)"
				continue
			fi
			if ! is_semver_patch "$latest"; then
				log_warn "Skipping $tool $version (latest '$latest' is not strict X.Y.Z semver)"
				continue
			fi

			if [[ "$latest" == "$version" ]]; then
				log_debug "No patch update needed for $tool $version"
				continue
			fi

			local key
			key="$tool|$latest"
			# seen_targets is needed in case multiple installed versions share the
			# same latest target. This can happen when multiple patch versions are
			# installed for the same major.minor series.
			if ! contains_line "$seen_targets" "$key"; then
				if [[ "$dry_run" == "1" ]]; then
					log_success "[dry-run] asdf install $tool $latest"
				else
					log_success "Installing $tool $latest"
					# TODO Catch error
					asdf install "$tool" "$latest"
					log_success "Installed $tool $latest"
				fi
				seen_targets+="$key"$'\n'
			else
				log_debug "Install already planned for $tool $latest"
			fi

			if [[ "$dry_run" == "1" ]]; then
				log_success "[dry-run] asdf uninstall $tool $version"
			else
				log_success "Removing $tool $version"
				# TODO Catch error
				asdf uninstall "$tool" "$version"
			fi

			changed=1
		done <<<"$version_list"
	done <<<"$plugin_list"

	if [[ "$changed" == "0" ]]; then
		log_info "No patch updates were available."
	else
		log_success "Completed update pass with changes"
	fi
}

main() {
	local dry_run=0

	VERBOSE=0

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dry-run)
			dry_run=1
			;;
		--verbose)
			VERBOSE=1
			;;
		--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown argument: $1" >&2
			usage >&2
			exit 1
			;;
		esac
		shift
	done

	update_installed_patch_versions "$dry_run"
}

main "$@"
