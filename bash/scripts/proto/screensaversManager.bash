#!/usr/bin/env bash

if [[ $# != 2 ]]; then
	echo "Must have at least two parameters. Directroy to read images from and directroy to copy images to."
	exit 1
fi

# The directory to start looking at for images.
readRoot=""

# The directory all images will be moved to.
copyToDir=""

while [[ -n "$1" ]]; do
	if [[ -z "$readRoot" ]]; then
		readRoot=${1%/}
	elif [[ -z "$copyToDir" ]]; then
		copyToDir=${1%/}
	fi
	shift
done

# Make sure required variables are set.
if [[ -z "$readRoot" || -z "$copyToDir" ]]; then
	echo "Missing readRoot or copyToDir!"
	exit 1
fi

# Clean up the target directory.
if find "$copyToDir" -not -path "*/\.*" -mindepth 1 -maxdepth 1 | read -r; then
	echo "Copy target dir ($copyToDir) is not empty, do you want to delete contents?"
	read -r input_variable
	if [[ "$input_variable" == "y" ]]; then
		rm -rf "${copyToDir:?}"/*
	fi
fi

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

findAndCopyScreensavers "$readRoot"
