#!/usr/bin/env bash

# TODO Include more questions like
#   What letter(s) are in between?
#   What number of the alphabet is this?
#   Add a difficulty option (reduces the max delta between the numbers)
#   Add in non-alphabetical characters? Numbers, basic symbols, dashes etc?

# The english alphabet.
declare -r letters=("A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z")

# Echos a random letter from the english alphabet (always capital).
getRandomLetter() {
	echo "${letters[RANDOM % 26]}"
}

# Returns the zero based index of a letter in the english alphabet.
getLetterIndex() {
	declare targetLetter="$1"
	declare -i curIdx=0

	for curLetter in "${letters[@]}"; do
		if [[ "$curLetter" == "$targetLetter" ]]; then
			echo "$curIdx"
			return
		fi

		((curIdx++))
	done

	echo "getLetterIndex invalid. targetLetter: '$targetLetter'"
	return 3
}

generateOffsetChoices() {
	if [[ "$#" != "2" ]]; then
		echo "Wrong number of arguments to generateOffsetChoices. Has $#"
		return 6
	fi

	declare -i curLetterIdx="$1"

	declare -i maxOffset="$2"
	if ((maxOffset == 0)) || ((maxOffset < 0)); then
		echo "Invalid maxOffset of $maxOffset' must be positive and non-zero"
		return 7
	fi

	declare validOffsets=()
	declare -i curIdx=0

	while ((curIdx < maxOffset)); do
		nextOffset=$((curLetterIdx + (maxOffset - curIdx)))
		if ((nextOffset < 26)); then
			validOffsets+=("$nextOffset")
		fi
		((curIdx++))
	done

	curIdx=0
	while ((curIdx < maxOffset)); do
		nextOffset=$((curLetterIdx - (maxOffset - curIdx)))
		if ((nextOffset > -1)); then
			validOffsets+=("$nextOffset")
		fi
		((curIdx++))
	done

	echo "${validOffsets[@]}"
}

generateSecondChoice() {
	if [[ "$#" != "2" ]]; then
		echo "Wrong number of arguments to generateSecondChoice. Has $#"
		return 4
	fi

	# TODO Validate inputs?
	declare -r firstLetter="$1"
	declare -r mode="$2"
	declare curIdx
	curIdx=$(getLetterIndex "$firstLetter")
	declare -i sign=1

	if ((curIdx == 25)); then
		# Must offset to a lower value
		sign=-1
	elif ((curIdx == 0)); then
		# Must offset to a higher value
		sign=1
	elif ((RANDOM % 2 == 1)); then
		# Use a random sign
		sign=-1
	fi

	declare secondIdx
	declare secondChoice
	if [[ "$mode" == "random" ]]; then
		# No extra work required here so just echo and return
		getRandomLetter
		return
	elif [[ "$mode" == "oneoff" ]]; then
		secondChoice=${letters[((curIdx + (1 * sign)))]}
	elif [[ "$mode" == "veryclose" ]]; then
		# 1-3
		offset=$(((RANDOM % 3) + 1))
		echo
	elif [[ "$mode" == "close" ]]; then
		echo
	elif [[ "$mode" == "mid" ]]; then
		echo
	elif [[ "$mode" == "far" ]]; then
		echo
	elif [[ "$mode" == "veryfar" ]]; then
		echo
	fi

	if ((secondIdx > 25)); then
		secondIdx=25
	elif ((secondIdx < 0)); then
		secondIdx=0
	fi

	echo "$secondChoice"
}

# Takes in two arguments (the two letter choices given to the user) and logs
# out some helpful data to explain and visualize the difference between
# the two letters.
logFailure() {
	if [[ "$#" != "2" ]]; then
		echo "Wrong number of arguments to logFailure. Has $#."
		return 5
	fi

	declare -i firstIdx
	declare -i secondIdx
	declare -i curIdx=1

	locationStr=""
	for value in "${letters[@]}"; do
		added="false"
		for char in "$@"; do
			if [[ "$char" == "$value" ]]; then
				if [[ "$char" == "$1" ]]; then
					firstIdx="$curIdx"
				else
					secondIdx="$curIdx"
				fi
				locationStr="$locationStr^ "
				added="true"
			fi
		done

		if [[ $added != "true" ]]; then
			locationStr="$locationStr  "
		fi

		((curIdx++))
	done

	# Log the number indexies of the letters.
	printf "%s is %d. %s is %d.\n\n" "$1" "$firstIdx" "$2" "$secondIdx"

	# Log the alphabet with ^ pointing to the letters.
	printf "%s\n%s\n" "${letters[*]}" "$locationStr"
}

# ###################################
# ###################################
# Script Starts Here
# ###################################
# ###################################

runMode="$1"
if [[ -z "$runMode" ]]; then
	# Default to random mode
	runMode="random"
fi

echo "Running in mode $runMode"

while true; do
	# Get the two letters to compare
	declare choiceOne
	choiceOne=$(getRandomLetter)
	declare choiceTwo
	choiceTwo=$(generateSecondChoice "$choiceOne" "$runMode")
	while [[ "$choiceOne" == "$choiceTwo" ]]; do
		choiceTwo=$(generateSecondChoice "$choiceOne" "$runMode")
	done

	# If the user if picking which letter is first (true) or last (false).
	pickingFirst="true"
	if ((RANDOM % 2 == 1)); then
		pickingFirst="false"
	fi

	# Determine the order of the two choices.
	orderedFirst="$choiceOne"
	orderedLast="$choiceTwo"
	if [[ "$orderedFirst" > "$orderedLast" ]]; then
		orderedFirst="$choiceTwo"
		orderedLast="$choiceOne"
	fi

	# Prompt the user to pick between the letters.
	if [[ "$pickingFirst" == "true" ]]; then
		correctAnswer="$orderedFirst"
		read -r -p "Which comes FIRST: $choiceOne or $choiceTwo? " userChoice
	else
		correctAnswer="$orderedLast"
		read -r -p "Which comes LAST: $choiceOne or $choiceTwo? " userChoice
	fi

	# Make sure a valid option was chosen.
	if [[ "$userChoice" != "$choiceOne" && "$userChoice" != "$choiceTwo" ]]; then
		echo "That was not an option"
		echo "Was $userChoice Valid $choiceOne or $choiceTwo"
		exit 1
	fi

	# Check if the correct answer was chosen.
	if [[ "$userChoice" == "$correctAnswer" ]]; then
		printf "\033[32mThat is correct!\033[0m\n"
	else
		printf "\033[31mIncorrect...\033[0m\n"
		logFailure "$orderedFirst" "$orderedLast"
	fi
	echo
done
