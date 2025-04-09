#!/usr/bin/env bash

# Complete ddTest with dart test files and directories.
complete -f -X '!*_test.dart' -o plusdirs -- ddTest
