package main

import (
	"fmt"
	"regexp"
	"strconv"
)

type semverVersion struct {
	major uint64
	minor uint64
}

func (v semverVersion) String() string {
	return strconv.FormatUint(v.major, 10) + "." + strconv.FormatUint(v.minor, 10)
}

var semverExtractRegex = regexp.MustCompile(`(\d+)\.?(\d+)?`)

// parseVersion attempts to parse a semver version from the input.
// Returns an error if the input does not contain a valid version string.
// If the input contains multiple valid version strings, only the first one is parsed.
func parseVersion(version string) (semverVersion, error) {
	matches := semverExtractRegex.FindAllStringSubmatch(version, 1)
	if len(matches) == 0 || len(matches[0]) < 1 {
		return semverVersion{}, fmt.Errorf("invalid version string: %q", version)
	}

	var err error
	var major uint64
	var minor uint64
	if matches[0][1] != "" {
		major, err = strconv.ParseUint(matches[0][1], 10, 64)
		if err != nil {
			return semverVersion{}, err
		}
	}
	if matches[0][2] != "" {
		minor, err = strconv.ParseUint(matches[0][2], 10, 64)
		if err != nil {
			return semverVersion{}, err
		}
	}

	return semverVersion{major: major, minor: minor}, nil
}

// compareVersionsLE returns true if v1 <= v2 (comparing major.minor only).
func compareVersionsLE(v1, v2 semverVersion) bool {
	if v1.major != v2.major {
		return v1.major < v2.major
	}
	return v1.minor <= v2.minor
}
