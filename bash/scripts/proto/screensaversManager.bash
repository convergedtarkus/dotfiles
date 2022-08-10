#!/usr/bin/env bash

if [[ $# -lt 2 ]]; then
	echo "Must have at least two parameters. Directroy to read images from and directroy to copy images to."
	exit 1
fi

# The directory to start looking at for images.
readRoot=""

# The directory all images will be moved to.
copyToDir=""

deleteCopyDir=""

while [[ -n "$1" ]]; do
	if [[ -z "$readRoot" ]]; then
		readRoot=${1%/}
	elif [[ -z "$copyToDir" ]]; then
		copyToDir=${1%/}
	else
		case "$1" in
		--delete)
			deleteCopyDir="true"
			;;
		--nodelete)
			deleteCopyDir="false"
			;;
		*)
			echo "Unknown argument of '$1'. Aborting"
			exit 1
			;;
		esac
	fi
	shift
done

# Make sure required variables are set.
if [[ -z "$readRoot" || -z "$copyToDir" ]]; then
	echo "Missing readRoot or copyToDir!"
	exit 1
fi

# Clean up the target directory.
handleCopyDir() {
	if [[ "$deleteCopyDir" == "false" ]]; then
		# Do not delete contents of copy to directory.
		return
	fi

	if find "$copyToDir" -not -path "*/\.*" -mindepth 1 -maxdepth 1 | read -r; then
		if [[ "$deleteCopyDir" != "true" ]]; then
			# Ask user if content of copy to directory should be deleted.
			echo "Copy target dir ($copyToDir) is not empty, do you want to delete contents?"
			read -r input_variable
			if [[ "$input_variable" != "y" ]]; then
				# User say not to delete contents of copy directory.
				return
			fi
		fi

		# Delete option given or user confirmed deleting contents of copy to directory.
		rm -rf "${copyToDir:?}"/*
	fi
}

copyIfImage() {
	filename=$(basename -- "$1")
	extension="${filename##*.}"
	filename="${filename%.*}"
	case "$extension" in
	jpg | jpeg | png | webp)
		cp -i "$1" "$copyToDir"
		;;
	*)
		echo "$1 is not an image"
		;;
	esac
}

findAndCopyScreensavers() {
	for f in "$1"/*; do
		if [[ -f "$f" ]]; then
			copyIfImage "$f"
		elif [[ -d "$f" ]]; then
			findAndCopyScreensavers "$f"
		fi
	done
}

handleCopyDir

findAndCopyScreensavers "$readRoot"
