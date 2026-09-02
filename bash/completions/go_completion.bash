#!/usr/bin/env bash

# Use the gocomplete for general go command completion.
if command -v gocomplete &>/dev/null; then
	complete -C gocomplete go
fi

# Complete goTestFile with _test.go files and directories.
complete -f -X '!*_test.go' -o plusdirs goTestFile

complete -W "--help -a --all -s --smart --dotfilesbin github.com/ github.com/Workiva/ frugal goimports golangci-lint gopherjs shfmt smartGoInstall smartgorunner" goInstall goInstallAll goInstallSmart goInstallSmartAll goInstallAllSmart _goInstall goInstall.bash
