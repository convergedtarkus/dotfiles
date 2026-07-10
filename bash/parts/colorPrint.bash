#!/usr/bin/env bash

# This script can be sourced into other files to provide pretty printing capabilities

# Clears any echo text coloring
_noColor='\033[0m'

colorEcho() {
	case ${#@} in
	# Print just an empty line.
	0) printf "\n" ;;
		# Print the single argument as a string, no color.
	1) printf "%s\n" "$1" ;;
	*)
		if [[ ! -t 2 || -n ${NO_COLOR:-} ]]; then
			# Terminal asks for no color, respect it. Remove first arg and print.
			shift
			printf "%s\n" "$*"
			return
		fi

		declare color
		case $1 in
		# 30
		black) color='\033[0;30m' ;;
		darkgray | dark_gray) color='\033[1;30m' ;;
		faintgray) color='\033[2;30m' ;;
		# 31
		red) color='\033[0;31m' ;;
		lightred | light_red) color='\033[1;31m' ;;
		faintred) color='\033[2;31m' ;;
		# 32
		green) color='\033[0;32m' ;;
		lightgreen | light_green) color='\033[1;32m' ;;
		faintgreen) color='\033[2;32m' ;;
		# 33
		brown | orange) color='\033[0;33m' ;;
		yellow) color='\033[1;33m' ;;
		faintyellow) color='\033[2;33m' ;;
		# 34
		blue) color='\033[0;34m' ;;
		lightblue | light_blue) color='\033[1;34m' ;;
		faintblue) color='\033[2;34m' ;;
		# 35
		purple) color='\033[0;35m' ;;
		lightpurple | light_purple) color='\033[1;35m' ;;
		faintpurple) color='\033[2;35m' ;;
		# 36
		cyan) color='\033[0;36m' ;;
		lightcyan | light_cyan) color='\033[1;36m' ;;
		faintcyan) color='\033[2;36m' ;;
		# 37
		lightgray | light_gray) color='\033[0;37m' ;;
		white) color='\033[1;37m' ;;
		faintwhite) color='\033[2;37m' ;;
		esac
		readonly color

		# Remove the color argument.
		shift

		printf "%b%s%b\n" "$color" "$*" "$_noColor"
		;;
	esac
}

# Commonly used for information or to standout a little.
echoBlue() {
	colorEcho "blue" "$*"
}

# Commonly used for success
echoGreen() {
	colorEcho "green" "$*"
}

# Commonly used for important information.
echoYellow() {
	colorEcho "yellow" "$*"
}

# Commonly used for errors.
echoRed() {
	colorEcho "red" "$*"
}
