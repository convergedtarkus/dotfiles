package semver

import (
	"fmt"
	"regexp"
	"strconv"
)

// Version defines a semver version of a package (major and minor, no patch).
type Version struct {
	major uint64
	minor uint64
}

// Major returns the major version.
func (v Version) Major() uint64 {
	return v.major
}

// Minor returns the minor version.
func (v Version) Minor() uint64 {
	return v.minor
}

// String returns the major.minor.
func (v Version) String() string {
	return strconv.FormatUint(v.major, 10) + "." + strconv.FormatUint(v.minor, 10)
}

var semverExtractRegex = regexp.MustCompile(`(\d+)\.?(\d+)?`)

// ParseVersion attempts to parse a semver version from the input.
// Returns an error if the input does not contain a valid version string.
// If the input contains multiple valid version strings, only the first one is parsed.
func ParseVersion(version string) (Version, error) {
	matches := semverExtractRegex.FindAllStringSubmatch(version, 1)
	if len(matches) == 0 || len(matches[0]) < 1 {
		return Version{}, fmt.Errorf("invalid version string: %q", version)
	}

	var err error
	var major uint64
	var minor uint64
	if matches[0][1] != "" {
		major, err = strconv.ParseUint(matches[0][1], 10, 64)
		if err != nil {
			return Version{}, err
		}
	}
	if matches[0][2] != "" {
		minor, err = strconv.ParseUint(matches[0][2], 10, 64)
		if err != nil {
			return Version{}, err
		}
	}

	return Version{major: major, minor: minor}, nil
}

// CompareVersionsLE returns true if v1 <= v2 (comparing major.minor only).
func CompareVersionsLE(v1, v2 Version) bool {
	if v1.major != v2.major {
		return v1.major < v2.major
	}
	return v1.minor <= v2.minor
}
