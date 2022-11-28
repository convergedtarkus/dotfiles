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
		if [[ ! -d "$readRoot" ]]; then
			echo "Read location '$readRoot' is not a directroy, aborting!"
			exit 2
		fi
	elif [[ -z "$copyToDir" ]]; then
		copyToDir=${1%/}
		if [[ ! -d "$copyToDir" ]]; then
			echo "Copy location '$copyToDir' is not a directroy, aborting!"
			exit 2
		fi
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

# Convert input directories to absolute paths.
readRoot=$(
	cd "$readRoot" || exit
	pwd
)
copyToDir=$(
	cd "$copyToDir" || exit
	pwd
)

# Clean up the target directory.
handleCopyDir() {
	if [[ "$deleteCopyDir" == "false" || "$readRoot" == "$copyToDir" ]]; then
		# Do not delete contents of copy to directory.
		return
	fi

	if find "$copyToDir" -not -path "*/\.*" -mindepth 1 -maxdepth 1 | read -r; then
		if [[ "$deleteCopyDir" != "true" ]]; then
			# Ask user if content of copy to directory should be deleted.
			echo
			echo
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

declare -a imagesToCopy

addToImagesToCopy() {
	filename=$(basename -- "$1")
	extension="${filename##*.}"
	filename="${filename%.*}"
	case "$extension" in
	jpg | jpeg | png | webp)
		imagesToCopy+=("$1")
		;;
	*)
		echo "$1 is not an image"
		;;
	esac
}

findScreensavers() {
	for f in "$1"/*; do
		if [[ -f "$f" ]]; then
			addToImagesToCopy "$f"
		elif [[ -d "$f" ]]; then
			if [[ "$f" == "$copyToDir" ]]; then
				echo "Skipping images in copy to target of '$copyToDir'"
				continue
			fi
			findScreensavers "$f"
		fi
	done
}

findScreensavers "$readRoot"

handleCopyDir

# Copy all the images in one shot. Faster than one by one.
echo "Copying ${#imagesToCopy[@]} images to $copyToDir"
cp -i "${imagesToCopy[@]}" "$copyToDir"
