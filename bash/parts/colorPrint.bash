#!/usr/bin/env bash

# This script can be sourced into other files to provide pretty printing capabilities

# Clears any echo text coloring
_noColor='\033[0m'

# The main printing function.
# The first argument should be the color to output.
# The second argument is either the first thing to print or --force.
# Special cases:
#    - No arguments will print just a newline (just like an empty echo)
#    - One argument will just print the argument
#    - Argument two is --force. The check to see if the terminal output is connected
#      to standard output and NO_COLOR is not set is ignored. This can be helpful to
#      capture color output to a variable.
#    - The color argument is an unknown color. The arguments are printed literally.
#      Note, if --force is given with an invalid color, the --force will be printed
#      literally.
colorEcho() {
	case ${#@} in
	# Print just an empty line.
	0) printf "\n" ;;
		# Print the single argument as a string, no color.
	1) printf "%s\n" "$1" ;;
	*)
		declare force=""
		if [[ $2 == "--force" ]]; then
			force="true"
		fi
		if [[ -z $force && (! -t 1 || -n ${NO_COLOR:-}) ]]; then
			# Terminal is non-interactive (-t 1 means if standard out is to an
			# interactive terminal) or asks for no color, respect it.
			# Remove first arg and print.
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
		*)
			# Unknown color, print all the input literally.
			printf "%s\n" "$*"
			return
			;;
		esac
		readonly color

		# Remove the color argument.
		shift

		if [[ -n $force ]]; then
			# Remove the force argument.
			shift
		fi

		printf "%b%s%b\n" "$color" "$*" "$_noColor"
		;;
	esac
}

# Commonly used for information or to standout a little.
echoBlue() {
	colorEcho "blue" "$@"
}

# Commonly used for success
echoGreen() {
	colorEcho "green" "$@"
}

# Commonly used for important information.
echoYellow() {
	colorEcho "yellow" "$@"
}

# Commonly used for errors.
# Outputs to standard error.
echoRed() {
	colorEcho "red" "$*" >&2
}
