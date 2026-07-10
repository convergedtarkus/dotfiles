package main

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestParseVersion(t *testing.T) {
	tests := []struct {
		name                string
		input               string
		expectedMajor       uint64
		expectedMinor       uint64
		expectedErrorString string
	}{
		{
			name:          "simple major.minor",
			input:         "1.21",
			expectedMajor: 1,
			expectedMinor: 21,
		},
		{
			name:          "with v prefix",
			input:         "v1.22",
			expectedMajor: 1,
			expectedMinor: 22,
		},
		{
			name:          "with go prefix",
			input:         "go1.19",
			expectedMajor: 1,
			expectedMinor: 19,
		},
		{
			name:          "three parts",
			input:         "1.21.5",
			expectedMajor: 1,
			expectedMinor: 21,
		},
		{
			name:          "handles extra zero",
			input:         "03.05.02",
			expectedMajor: 3,
			expectedMinor: 5,
		},
		{
			name:          "three parts with v prefx",
			input:         "v1.21.5",
			expectedMajor: 1,
			expectedMinor: 21,
		},
		{
			name:          "three parts with prefix and suffix",
			input:         "versionGo2.5.5BestVersion",
			expectedMajor: 2,
			expectedMinor: 5,
		},
		{
			name:          "major only",
			input:         "2",
			expectedMajor: 2,
		},
		{
			name:                "empty string",
			input:               "",
			expectedErrorString: `invalid version string: ""`,
		},
		{
			name:                "No semver parts",
			input:               "A.B",
			expectedErrorString: `invalid version string: "A.B"`,
		},
		{
			name:          "Uses first match if multiple found",
			input:         "v1.21.5 and v2.0.1",
			expectedMajor: 1,
			expectedMinor: 21,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			parsedResult, err := parseVersion(tc.input)
			if tc.expectedErrorString != "" {
				assert.EqualError(t, err, tc.expectedErrorString, "error message should match expected string")
				return
			}

			require.NoError(t, err, "parseVersion should not error for input: %s", tc.input)
			assert.Equal(t, tc.expectedMajor, parsedResult.major, "major version mismatch")
			assert.Equal(t, tc.expectedMinor, parsedResult.minor, "minor version mismatch")
			assert.Equal(
				t,
				fmt.Sprintf(`%d.%d`, parsedResult.major, parsedResult.minor),
				parsedResult.String(),
				"String() method should return a non-empty string",
			)
		})
	}
}

func TestCompareVersionsLE(t *testing.T) {
	tests := []struct {
		name     string
		v1       string
		v2       string
		expected bool
	}{
		{
			name:     "equal versions",
			v1:       "1.21",
			v2:       "1.21",
			expected: true,
		},
		{
			name:     "v1 lower minor",
			v1:       "1.20",
			v2:       "1.21",
			expected: true,
		},
		{
			name: "v1 greater minor",
			v1:   "1.22",
			v2:   "1.21",
		},
		{
			name:     "v1 lower major",
			v1:       "1.21",
			v2:       "2.0",
			expected: true,
		},
		{
			name: "v1 greater major",
			v1:   "2.0",
			v2:   "1.21",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			v1Parsed, err := parseVersion(tc.v1)
			require.NoError(t, err, "parseVersion should not error for input: %s", tc.v1)
			v2Parsed, err := parseVersion(tc.v2)
			require.NoError(t, err, "parseVersion should not error for input: %s", tc.v2)

			actual := compareVersionsLE(v1Parsed, v2Parsed)
			assert.Equal(t, tc.expected, actual)
		})
	}
}
