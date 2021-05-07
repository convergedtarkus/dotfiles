#!/usr/bin/env bash

if [[ ! -f "$1" ]]; then
	echo "Must pass an input file"
	exit 1
fi

sed <"$1" '/\s*\/\/.*$/d'
