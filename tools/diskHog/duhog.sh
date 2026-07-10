#!/usr/bin/env bash

# duhog - A wrapper around du that filters and sorts output.
#
# Usage:
#   duhog <directory> [-d depth] [-m min_size]
#
# Arguments:
#   directory   (required) The directory to scan.
#   -d depth    (optional) How many levels deep to report (passed to du -d). Default: 1.
#   -m min_size (optional) Minimum size to display, in human-readable format
#                          (e.g. 100M, 1G, 500K). Default: 100M.
#
# Examples:
#   duhog ~/Library
#   duhog ~/Library -d 2
#   duhog ~/Library -d 2 -m 1G
#   duhog /usr/local -m 500K
duhog() {
	local dir=""
	local depth=1
	local min_size="100M"

	# --- Parse arguments ---
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-d)
			if [[ -z $2 || $2 == -* ]]; then
				echo "Error: -d requires a numeric depth value." >&2
				return 1
			fi
			depth="$2"
			shift 2
			;;
		-m)
			if [[ -z $2 || $2 == -* ]]; then
				echo "Error: -m requires a size value (e.g. 100M, 1G, 500K)." >&2
				return 1
			fi
			min_size="$2"
			shift 2
			;;
		-*)
			echo "Error: unknown flag '$1'." >&2
			echo "Usage: duhog <directory> [-d depth] [-m min_size]" >&2
			return 1
			;;
		*)
			if [[ -z $dir ]]; then
				dir="$1"
			else
				echo "Error: unexpected argument '$1'. Only one directory is allowed." >&2
				return 1
			fi
			shift
			;;
		esac
	done

	if [[ -z $dir ]]; then
		echo "Error: a directory argument is required." >&2
		echo "Usage: duhog <directory> [-d depth] [-m min_size]" >&2
		return 1
	fi

	if [[ ! -d $dir ]]; then
		echo "Error: '$dir' is not a directory or does not exist." >&2
		return 1
	fi

	# --- Convert human-readable min_size to kilobytes for numeric comparison ---
	# Accepts formats like 500K, 100M, 1G (case-insensitive).
	local size_number="${min_size//[^0-9.]/}"
	local size_suffix="${min_size//[0-9.]/}"
	size_suffix="$(echo "$size_suffix" | tr '[:lower:]' '[:upper:]')"

	local threshold_kb
	case "$size_suffix" in
	K) threshold_kb=$(awk "BEGIN {printf \"%.0f\", $size_number}") ;;
	M) threshold_kb=$(awk "BEGIN {printf \"%.0f\", $size_number * 1024}") ;;
	G) threshold_kb=$(awk "BEGIN {printf \"%.0f\", $size_number * 1024 * 1024}") ;;
	T) threshold_kb=$(awk "BEGIN {printf \"%.0f\", $size_number * 1024 * 1024 * 1024}") ;;
	"")
		# No suffix; assume bytes, convert to KB.
		threshold_kb=$(awk "BEGIN {printf \"%.0f\", $size_number / 1024}")
		;;
	*)
		echo "Error: unrecognized size suffix '$size_suffix'. Use K, M, G, or T." >&2
		return 1
		;;
	esac

	# --- Run du, filter, sort, and humanize ---
	# du -k:  output sizes in kilobytes for reliable numeric comparison.
	# -d N:   limit depth to N levels.
	# 2>/dev/null: suppress permission-denied and other errors.
	# awk:    filter entries below the threshold (comparing in KB).
	# sort -rn: sort numerically, largest first.
	# Final awk: convert KB back to human-readable format.
	du -k -d "$depth" "$dir" 2>/dev/null |
		awk -v thresh="$threshold_kb" '$1 >= thresh' |
		sort -rn |
		awk '{
            kb = $1;
            if (kb >= 1073741824) {
                printf "%8.2f TB  %s\n", kb / 1073741824, $2
            } else if (kb >= 1048576) {
                printf "%8.2f GB  %s\n", kb / 1048576, $2
            } else if (kb >= 1024) {
                printf "%8.2f MB  %s\n", kb / 1024, $2
            } else {
                printf "%8.2f KB  %s\n", kb, $2
            }
        }'
}
