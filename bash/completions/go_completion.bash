#!/usr/bin/env bash

# Complete goTestFile with _test.go files and directories.
complete -f -X '!*_test.go' -o plusdirs goTestFile

complete -W "--help -help -a --all -all -s --smart -smart shfmt golangci-lint frugal gopherjs smartGoInstall github.com/ github.com/Workiva/" goInstall goInstallAll goInstallSmart goInstallSmartAll goInstallAllSmart _goInstall
