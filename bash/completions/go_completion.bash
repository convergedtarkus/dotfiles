#!/usr/bin/env bash

# Complete goTestFile with _test.go files and directories.
complete -f -X '!*_test.go' -o plusdirs goTestFile
