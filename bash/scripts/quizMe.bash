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

# Takes in two arguments (the two letter choices given to the user) and logs
# out some helpful data to explain and visualize the difference between
# the two letters.
logFailure() {
	if [[ "$#" != "2" ]]; then
		echo "Wrong number of arguments to logFailure. Has $#."
		return
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

difficulty="$1"
if [[ -z "$difficulty" ]]; then
	difficulty=0
else
	# Valid the requested difficulty is a number.
	if ! [[ "$difficulty" =~ ^[0-9]+$ ]]; then
		echo "Difficulty must be a value number"
		return
	fi

	declare -r -i minDifficulty=0
	declare -r -i maxDifficulty=14

	# TODO Maybe better ideas?
	# Difficulty levels
	# unset = random
	# 5 = Letters appart by 1-3
	# 4 = Letters appart by 1-8
	# 3 = Letters appart by 1-14
	# 2 = Letters appart by 1-20
	# 1 = Letters appart by 1-26

	# Verify the script supports the requested version
	declare -i -r requestedVersion="$1"
	if [[ $requestedVersion < $minDifficulty || $requestedVersion > $maxDifficulty ]]; then
		echo "Request difficulty of $requestedVersion is out of the accepted range of $minDifficulty to $maxDifficulty."
		exit 1
	fi
fi

while true; do
	# Get the two letters to compare
	declare choiceOne
	choiceOne=$(getRandomLetter)
	declare choiceTwo
	choiceTwo=$(getRandomLetter)
	while [[ "$choiceOne" == "$choiceTwo" ]]; do
		choiceTwo=$(getRandomLetter)
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
		read -r -p "Which comes first: $choiceOne or $choiceTwo? " userChoice
	else
		correctAnswer="$orderedLast"
		read -r -p "Which comes last: $choiceOne or $choiceTwo? " userChoice
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
