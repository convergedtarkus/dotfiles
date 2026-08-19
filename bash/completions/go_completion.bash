#!/usr/bin/env bash

# Complete goTestFile with _test.go files and directories.
complete -f -X '!*_test.go' -o plusdirs goTestFile

complete -W "--help -a --all -s --smart --dotfilesbin github.com/ github.com/Workiva/ frugal goimports golangci-lint gopherjs shfmt smartGoInstall smartgorunner" goInstall goInstallAll goInstallSmart goInstallSmartAll goInstallAllSmart _goInstall goInstall.bash
