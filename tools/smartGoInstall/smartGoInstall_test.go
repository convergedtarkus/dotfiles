package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/convergedtarkus/randomUtils/sharedUtils"
)

func TestParseFlags(t *testing.T) {
	const usageString = "Usage: smartGoInstall [flags] <package-path>\n\n" +
		"Installs a Go package at the newest version compatible with the current Go toolchain.\n\n" +
		"Example:\n  smartGoInstall github.com/golangci/golangci-lint/cmd/golangci-lint\n\n" +
		"Flags:\n  " +
		"-install-latest\n    \tinstall latest version if no compatible version is found\n  -l\tshorthand for --install-latest\n  -" +
		"p\tshorthand for --print-version-only\n  -print-version-only\n    \tprint the compatible version without installing\n  -" +
		"v\tshorthand for --verbose\n  -verbose\n    \tenable verbose output\n\n" +
		"If --install-latest is not provided, the command will fail when it cannot determine a compatible version.\n"

	testCases := []struct {
		testName       string
		inputFlags     []string
		expectedConfig commandConfig
		expectedError  string
		expectedOutput string
	}{
		{
			testName:   "valid package path only",
			inputFlags: []string{"github.com/example/pkg"},
			expectedConfig: commandConfig{
				packageToInstall: "github.com/example/pkg",
			},
		},
		{
			testName:   "with --install-latest flag",
			inputFlags: []string{"--install-latest", "github.com/example/pkg"},
			expectedConfig: commandConfig{
				installLatest:    true,
				packageToInstall: "github.com/example/pkg",
			},
		},
		{
			testName:   "with -l shorthand",
			inputFlags: []string{"-l", "github.com/example/pkg"},
			expectedConfig: commandConfig{
				installLatest:    true,
				packageToInstall: "github.com/example/pkg",
			},
		},
		{
			testName:   "with both install latest flags",
			inputFlags: []string{"-l", `--install-latest`, "github.com/example/pkg2"},
			expectedConfig: commandConfig{
				installLatest:    true,
				packageToInstall: "github.com/example/pkg2",
			},
		},
		{
			testName:   "with --verbose shorthand",
			inputFlags: []string{"--verbose", "github.com/example/pkg"},
			expectedConfig: commandConfig{
				packageToInstall: "github.com/example/pkg",
				verbose:          true,
			},
		},
		{
			testName:   "with -v shorthand",
			inputFlags: []string{"-v", "github.com/example/pkg"},
			expectedConfig: commandConfig{
				packageToInstall: "github.com/example/pkg",
				verbose:          true,
			},
		},
		{
			testName:   "with both verbose flags",
			inputFlags: []string{"-v", `--verbose`, "github.com/example/pkg"},
			expectedConfig: commandConfig{
				packageToInstall: "github.com/example/pkg",
				verbose:          true,
			},
		},
		{
			testName:   "with --print-version-only flag",
			inputFlags: []string{"--print-version-only", "github.com/example/pkg"},
			expectedConfig: commandConfig{
				packageToInstall: "github.com/example/pkg",
				printVersionOnly: true,
			},
		},
		{
			testName:   "with -p shorthand",
			inputFlags: []string{"-p", "github.com/example/pkg"},
			expectedConfig: commandConfig{
				packageToInstall: "github.com/example/pkg",
				printVersionOnly: true,
			},
		},
		{
			testName:   "All flags together",
			inputFlags: []string{"-v", "--install-latest", "-p", "github.com/example/pkg"},
			expectedConfig: commandConfig{
				packageToInstall: "github.com/example/pkg",
				installLatest:    true,
				printVersionOnly: true,
				verbose:          true,
			},
		},
		{
			testName:       "Two trailing arguments",
			inputFlags:     []string{"-v", "--verbose", "-l", "--install-latest", "github.com/example/pkg", `github.com/extra/arg`},
			expectedError:  "too many arguments: only one package-path is allowed",
			expectedOutput: usageString,
		},
		{
			testName:       "Unknown flag",
			inputFlags:     []string{"-y", "github.com/example/pkg"},
			expectedError:  "flag provided but not defined: -y",
			expectedOutput: "flag provided but not defined: -y\n" + usageString,
		},
		{
			testName:       "with --help",
			inputFlags:     []string{"--help"},
			expectedError:  flag.ErrHelp.Error(),
			expectedOutput: usageString,
		},
		{
			testName:       "with -h",
			inputFlags:     []string{"--help"},
			expectedError:  flag.ErrHelp.Error(),
			expectedOutput: usageString,
		},
		{
			testName:       "with --help and other args",
			inputFlags:     []string{"--help", "-v", "-l", "github.com/example/pkg"},
			expectedError:  flag.ErrHelp.Error(),
			expectedOutput: usageString,
		},
		{
			testName:       "missing package path",
			expectedError:  "missing required argument: package-path",
			expectedOutput: usageString,
		},
	}

	for _, tc := range testCases {
		// For Scopelint
		tc := tc
		t.Run(tc.testName, func(t *testing.T) {
			capturedOutput := &bytes.Buffer{}
			cfg, err := parseFlags(tc.inputFlags, capturedOutput)
			assert.Equal(t, tc.expectedOutput, capturedOutput.String(), "expected output did not match actual output")

			if tc.expectedError != "" {
				assert.EqualError(t, err, tc.expectedError, "expected error did not match actual error")
				return
			}

			require.NoError(t, err, "parseFlags should not error")
			assert.Equal(t, tc.expectedConfig.packageToInstall, cfg.packageToInstall, `Wrong packageToInstall`)
			assert.Equal(t, tc.expectedConfig.installLatest, cfg.installLatest, `Wrong installLatest`)
			assert.Equal(t, tc.expectedConfig.printVersionOnly, cfg.printVersionOnly, `Wrong printVersionOnly`)
			assert.Equal(t, tc.expectedConfig.verbose, cfg.verbose, `Wrong verbose`)
		})
	}
}

func TestExtractModulePath(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "with cmd suffix",
			input:    "github.com/golangci/golangci-lint/cmd/golangci-lint",
			expected: "github.com/golangci/golangci-lint",
		},
		{
			name:     "without cmd suffix",
			input:    "github.com/Antonboom/testifylint",
			expected: "github.com/Antonboom/testifylint",
		},
		{
			name:     "cmd at root",
			input:    "example.com/cmd/tool",
			expected: "example.com",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			assert.Equal(t, tc.expected, extractModulePath(tc.input))
		})
	}
}

func Test_getSystemGoVersion(t *testing.T) {
	testCases := []struct {
		testName        string
		fakeOutput      []byte
		fakeError       error
		expectedVersion string
		expectedError   string
	}{
		{
			testName:        "valid go version output",
			fakeOutput:      []byte("go version go1.21.5 darwin/arm64"),
			expectedVersion: "1.21",
		},
		{
			testName:        "valid go version output, no patch",
			fakeOutput:      []byte("go version go1.20 darwin/arm64"),
			expectedVersion: "1.20",
		},
		{
			testName:      "command failure",
			fakeError:     fmt.Errorf("command not found"),
			expectedError: "running 'go version': command not found",
		},
		{
			testName:      "unparseable output",
			fakeOutput:    []byte("some garbage output"),
			expectedError: `could not parse Go version from: some garbage output`,
		},
	}

	for _, tc := range testCases {
		// For Scopelint
		tc := tc
		t.Run(tc.testName, func(t *testing.T) {
			runner := sharedUtils.NewMockRunner(t)
			runner.On("Output", "go", []string{"version"}).Return(tc.fakeOutput, tc.fakeError).Once()

			actual, err := getSystemGoVersion(runner)
			if tc.expectedError != "" {
				assert.EqualError(t, err, tc.expectedError, "expected error did not match actual error")
				return
			}
			require.NoError(t, err, "getSystemGoVersion should not error")
			assert.Equal(t, tc.expectedVersion, actual.String())
		})
	}
}

func Test_getModuleGoVersions(t *testing.T) {
	testCases := []struct {
		testName         string
		fakeOutput       []byte
		fakeError        error
		expectedVersions []string
		expectedError    string
	}{
		{
			testName:         "Single version found",
			fakeOutput:       []byte("github.com/example/pkg v2.1.1"),
			expectedVersions: []string{"v2.1.1"},
		},
		{
			testName:         "Multiple versions found",
			fakeOutput:       []byte("github.com/example/pkg v1.0.0 v1.1.0 v1.2.0"),
			expectedVersions: []string{"v1.2.0", "v1.1.0", "v1.0.0"},
		},
		{
			testName:   "No versions found",
			fakeOutput: []byte("github.com/example/pkg"),
		},
		{
			testName:   "Bad output",
			fakeOutput: []byte(""),
		},
		{
			testName:      "command failure",
			fakeError:     fmt.Errorf("network error"),
			expectedError: "running 'go list -m -versions': network error",
		},
	}

	for _, tc := range testCases {
		// For Scopelint
		tc := tc
		t.Run(tc.testName, func(t *testing.T) {
			runner := sharedUtils.NewMockRunner(t)
			runner.On("Output", "go", []string{"list", "-mod=readonly", "-m", "-versions", "github.com/example/pkg"}).Return(tc.fakeOutput, tc.fakeError).Once()

			actual, err := getModuleGoVersions(runner, "github.com/example/pkg")
			if tc.expectedError != "" {
				assert.EqualError(t, err, tc.expectedError, "expected error did not match actual error")
				return
			}
			require.NoError(t, err, "getModuleGoVersions should not error")
			assert.Equal(t, tc.expectedVersions, actual)
		})
	}
}

func Test_getRequiredGoVersionForPackage(t *testing.T) {
	testCases := []struct {
		testName        string
		makeJsonOutput  func() []byte
		fakeError       error
		expectedVersion string
		expectedError   string
	}{
		{
			testName: "valid download result",
			makeJsonOutput: func() []byte {
				return writeTmpGoModJSON(t, "module example.com/foo\n\ngo 1.20\n")
			},
			expectedVersion: "1.20",
		},
		{
			testName: "download result does not have GoMod field",
			makeJsonOutput: func() []byte {
				goModPath := writeTmpGoMod(t, "module example.com/foo\n\ngo 1.20\n")
				jsonOutput, err := json.Marshal(struct {
					SomeFile string `json:"SomeFile"`
				}{SomeFile: goModPath})
				require.NoError(t, err, "json.Marshal should not error")
				return jsonOutput
			},
			expectedError: "no GoMod path in download result",
		},
		{
			testName: "Unparsable JSON output",
			makeJsonOutput: func() []byte {
				return []byte("not a valid json")
			},
			expectedError: `parsing JSON from 'go mod download': invalid character 'o' in literal null (expecting 'u')`,
		},
		{
			testName: "empty GoMod path",
			makeJsonOutput: func() []byte {
				jsonOutput, err := json.Marshal(modDownloadResult{GoMod: ""})
				require.NoError(t, err, "json.Marshal should not error")
				return jsonOutput
			},
			expectedError: "no GoMod path in download result",
		},
		{
			testName:      "command failure",
			fakeError:     fmt.Errorf("download failed"),
			expectedError: "running 'go mod download -json': download failed",
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.testName, func(t *testing.T) {
			var jsonOutput []byte
			if tc.makeJsonOutput != nil {
				jsonOutput = tc.makeJsonOutput()
			}

			runner := sharedUtils.NewMockRunner(t)
			runner.On("Output", "go", []string{"mod", "download", "-json", "example.com/foo@v1.0.0"}).Return(jsonOutput, tc.fakeError).Once()

			actual, err := getRequiredGoVersionForPackage(runner, "example.com/foo", "v1.0.0")
			if tc.expectedError != "" {
				assert.EqualError(t, err, tc.expectedError, "expected error did not match actual error")
				assert.Empty(t, actual)
				return
			}
			require.NoError(t, err, "getRequiredGoVersionForPackage should not error")
			assert.Equal(t, tc.expectedVersion, actual.String())
		})
	}
}

func TestParseGoVersionFromMod(t *testing.T) {
	testCases := []struct {
		testName         string
		makeGoModContent func() string
		expectedVersion  string
		expectedError    string
	}{
		{
			testName: "standard go.mod",
			makeGoModContent: func() string {
				return writeTmpGoMod(t, "module example.com/foo\n\ngo 1.21\n\nrequire (\n\tgithub.com/bar v1.0.0\n)\n")
			},
			expectedVersion: "1.21",
		},
		{
			testName: "go.mod with patch version",
			makeGoModContent: func() string {
				return writeTmpGoMod(t, "module example.com/foo\n\ngo 1.22.3\n\nrequire (\n\tgithub.com/bar v1.0.0\n)\n")
			},
			expectedVersion: "1.22",
		},
		{
			testName: "no go directive",
			makeGoModContent: func() string {
				return writeTmpGoMod(t, "module example.com/foo\n")
			},
			expectedError: "no 'go' directive found in go.mod at",
		},
		{
			testName: "file does not exist",
			makeGoModContent: func() string {
				return "/path/to/nonexistent/go.mod"
			},
			expectedError: "opening go.mod at /path/to/nonexistent/go.mod: open /path/to/nonexistent/go.mod: no such file or directory",
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.testName, func(t *testing.T) {
			path := tc.makeGoModContent()
			actual, err := parseGoVersionFromMod(path)
			if tc.expectedError != "" {
				assert.ErrorContains(t, err, tc.expectedError, "expected error did not match actual error")
				assert.Empty(t, actual)
				return
			}
			require.NoError(t, err, "parseGoVersionFromMod should not error")
			assert.Equal(t, tc.expectedVersion, actual.String())
		})
	}
}

func writeTmpGoMod(t *testing.T, content string) string {
	tmpDir := t.TempDir()
	goModPath := filepath.Join(tmpDir, "go.mod")
	require.NoError(t, os.WriteFile(goModPath, []byte(content), 0644), "WriteFile should not error")
	return goModPath
}

func writeTmpGoModJSON(t *testing.T, content string) []byte {
	goModPath := writeTmpGoMod(t, content)
	jsonOutput, err := json.Marshal(modDownloadResult{GoMod: goModPath})
	require.NoError(t, err, "json.Marshal should not error")
	return jsonOutput
}

func Test_installLatestOrFail(t *testing.T) {
	testCases := []struct {
		testName      string
		cfg           commandConfig
		runCallError  error
		expectedError string
	}{
		{
			testName: "install-latest flag set, install succeeds",
			cfg: commandConfig{
				installLatest:    true,
				packageToInstall: "example.com/tool",
			},
		},
		{
			testName: "install-latest flag set, install fails",
			cfg: commandConfig{
				installLatest:    true,
				packageToInstall: "example.com/tool",
			},
			runCallError:  fmt.Errorf("permission denied"),
			expectedError: "go install example.com/tool@latest failed: permission denied",
		},
		{
			testName: "install-latest flag not set",
			cfg: commandConfig{
				installLatest:    false,
				packageToInstall: "example.com/tool",
			},
			expectedError: "no compatible version found",
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.testName, func(t *testing.T) {
			runner := sharedUtils.NewMockRunner(t)
			if tc.cfg.installLatest {
				runner.On("Run", mock.Anything, mock.Anything, "go", []string{"install", tc.cfg.packageToInstall + "@latest"}).Return(tc.runCallError).Once()
			}

			err := installLatestOrFail(tc.cfg, runner)
			if tc.expectedError != "" {
				assert.EqualError(t, err, tc.expectedError, "expected error did not match actual error")
				return
			}
			require.NoError(t, err, "installLatestOrFail should not error")
		})
	}
}

func Test_runGoInstall(t *testing.T) {
	testCases := []struct {
		testName      string
		pkg           string
		version       string
		runCallError  error
		expectedError string
	}{
		{
			testName: "successful install",
			pkg:      "example.com/tool",
			version:  "v1.2.3",
		},
		{
			testName: "successful install with latest",
			pkg:      "example.com/tool/cmd/tool",
			version:  "latest",
		},
		{
			testName:      "install fails",
			pkg:           "example.com/tool",
			version:       "v1.0.0",
			runCallError:  fmt.Errorf("exit status 1"),
			expectedError: "go install example.com/tool@v1.0.0 failed: exit status 1",
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.testName, func(t *testing.T) {
			runner := sharedUtils.NewMockRunner(t)
			runner.On("Run", mock.Anything, mock.Anything, "go", []string{"install", tc.pkg + "@" + tc.version}).Return(tc.runCallError).Once()

			err := runGoInstall(runner, tc.pkg, tc.version)
			if tc.expectedError != "" {
				assert.EqualError(t, err, tc.expectedError, "expected error did not match actual error")
				return
			}
			require.NoError(t, err, "runGoInstall should not error")
		})
	}
}

func TestRun(t *testing.T) {
	t.Run("finds compatible version and installs it", func(t *testing.T) {
		// Discard all output to avoid making the test output messy.
		sharedUtils.NewDiscardHandlerLoggerRestoreAfterTest(t)

		// Create a temporary go.mod for the compatible version
		downloadJSON := writeTmpGoModJSON(t, "module example.com/tool\n\ngo 1.21\n")

		runner := sharedUtils.NewMockRunner(t)
		runner.On("Output", "go", []string{"version"}).Return([]byte("go version go1.21.5 darwin/arm64"), nil).Once()
		runner.On("Output", "go", []string{"list", "-mod=readonly", "-m", "-versions", "example.com/tool"}).Return([]byte("example.com/tool v1.0.0 v1.1.0"), nil).Once()
		// getRequiredGoVersionForPackage for v1.1.0 (newest first after reverse)
		runner.On("Output", "go", []string{"mod", "download", "-json", "example.com/tool@v1.1.0"}).Return(downloadJSON, nil).Once()
		runner.On("Run", mock.Anything, mock.Anything, "go", []string{"install", "example.com/tool@v1.1.0"}).Return(nil).Once()

		err := run(commandConfig{packageToInstall: "example.com/tool"}, runner)
		require.NoError(t, err, "run should not error")
	})

	t.Run("no compatible version without install-latest", func(t *testing.T) {
		// Discard all output to avoid making the test output messy.
		sharedUtils.NewDiscardHandlerLoggerRestoreAfterTest(t)

		// Create a go.mod that requires a higher Go version than we have
		downloadJSON := writeTmpGoModJSON(t, "module example.com/tool\n\ngo 1.23\n")

		runner := sharedUtils.NewMockRunner(t)
		runner.On("Output", "go", []string{"version"}).Return([]byte("go version go1.21.5 darwin/arm64"), nil).Once()
		runner.On("Output", "go", []string{"list", "-mod=readonly", "-m", "-versions", "example.com/tool"}).Return([]byte("example.com/tool v1.0.0"), nil).Once()
		// getRequiredGoVersionForPackage for v1.0.0: requires 1.23
		runner.On("Output", "go", []string{"mod", "download", "-json", "example.com/tool@v1.0.0"}).Return(downloadJSON, nil).Once()

		err := run(commandConfig{packageToInstall: "example.com/tool"}, runner)
		assert.ErrorContains(t, err, "no compatible version found")
		runner.AssertNotCalled(t, "Run", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("no compatible version with install-latest", func(t *testing.T) {
		// Discard all output to avoid making the test output messy.
		sharedUtils.NewDiscardHandlerLoggerRestoreAfterTest(t)

		// Create a go.mod that requires a higher Go version than we have
		downloadJSON := writeTmpGoModJSON(t, "module example.com/tool\n\ngo 1.23\n")

		runner := sharedUtils.NewMockRunner(t)
		runner.On("Output", "go", []string{"version"}).Return([]byte("go version go1.21.5 darwin/arm64"), nil).Once()
		runner.On("Output", "go", []string{"list", "-mod=readonly", "-m", "-versions", "example.com/tool"}).Return([]byte("example.com/tool v1.0.0"), nil).Once()
		// getRequiredGoVersionForPackage for v1.0.0: requires 1.23
		runner.On("Output", "go", []string{"mod", "download", "-json", "example.com/tool@v1.0.0"}).Return(downloadJSON, nil).Once()
		// runGoInstall with "latest"
		runner.On("Run", mock.Anything, mock.Anything, "go", []string{"install", "example.com/tool@latest"}).Return(nil).Once()

		err := run(commandConfig{
			packageToInstall: "example.com/tool",
			installLatest:    true,
		}, runner)
		require.NoError(t, err, "run should not error")
	})

	t.Run("no versions found with install-latest", func(t *testing.T) {
		// Discard all output to avoid making the test output messy.
		sharedUtils.NewDiscardHandlerLoggerRestoreAfterTest(t)

		runner := sharedUtils.NewMockRunner(t)
		runner.On("Output", "go", []string{"version"}).Return([]byte("go version go1.21.5 darwin/arm64"), nil).Once()
		// getModuleGoVersions: no versions
		runner.On("Output", "go", []string{"list", "-mod=readonly", "-m", "-versions", "example.com/tool"}).Return([]byte("example.com/tool"), nil).Once()
		// runGoInstall with "latest"
		runner.On("Run", mock.Anything, mock.Anything, "go", []string{"install", "example.com/tool@latest"}).Return(nil).Once()

		err := run(commandConfig{
			packageToInstall: "example.com/tool",
			installLatest:    true,
		}, runner)
		require.NoError(t, err, "run should not error")
	})

	t.Run("go version command fails", func(t *testing.T) {
		// Discard all output to avoid making the test output messy.
		sharedUtils.NewDiscardHandlerLoggerRestoreAfterTest(t)

		runner := sharedUtils.NewMockRunner(t)
		runner.On("Output", "go", []string{"version"}).Return([]byte(nil), fmt.Errorf("go not found")).Once()

		err := run(commandConfig{packageToInstall: "example.com/tool"}, runner)
		assert.Error(t, err)
		assert.ErrorContains(t, err, "getting current Go version")
	})

	t.Run("get module versions fails", func(t *testing.T) {
		// Discard all output to avoid making the test output messy.
		sharedUtils.NewDiscardHandlerLoggerRestoreAfterTest(t)

		runner := sharedUtils.NewMockRunner(t)
		runner.On("Output", "go", []string{"version"}).Return([]byte("go version go1.21.5 darwin/arm64"), nil).Once()
		// getModuleGoVersions fails
		runner.On("Output", "go", []string{"list", "-mod=readonly", "-m", "-versions", "example.com/tool"}).Return([]byte(nil), fmt.Errorf("network error")).Once()

		err := run(commandConfig{packageToInstall: "example.com/tool"}, runner)
		assert.Error(t, err)
		assert.ErrorContains(t, err, "getting module versions")
	})

	t.Run("extracts module path from cmd package", func(t *testing.T) {
		// Discard all output to avoid making the test output messy.
		sharedUtils.NewDiscardHandlerLoggerRestoreAfterTest(t)

		downloadJSON := writeTmpGoModJSON(t, "module example.com/tool\n\ngo 1.21\n")

		runner := sharedUtils.NewMockRunner(t)
		runner.On("Output", "go", []string{"version"}).Return([]byte("go version go1.21.5 darwin/arm64"), nil).Once()
		// getModuleGoVersions uses "example.com/tool" not the full cmd path
		runner.On("Output", "go", []string{"list", "-mod=readonly", "-m", "-versions", "example.com/tool"}).Return([]byte("example.com/tool v1.0.0"), nil).Once()
		runner.On("Output", "go", []string{"mod", "download", "-json", "example.com/tool@v1.0.0"}).Return(downloadJSON, nil).Once()
		runner.On("Run", mock.Anything, mock.Anything, "go", []string{"install", "example.com/tool/cmd/tool@v1.0.0"}).Return(nil).Once()

		err := run(commandConfig{packageToInstall: "example.com/tool/cmd/tool"}, runner)
		require.NoError(t, err, "run should not error")
	})

	t.Run("print-version-only prints compatible version without installing", func(t *testing.T) {
		// Discard all output to avoid making the test output messy.
		sharedUtils.NewDiscardHandlerLoggerRestoreAfterTest(t)

		downloadJSON := writeTmpGoModJSON(t, "module example.com/tool\n\ngo 1.21\n")

		runner := sharedUtils.NewMockRunner(t)
		runner.On("Output", "go", []string{"version"}).Return([]byte("go version go1.21.5 darwin/arm64"), nil).Once()
		runner.On("Output", "go", []string{"list", "-mod=readonly", "-m", "-versions", "example.com/tool"}).Return([]byte("example.com/tool v1.0.0 v1.1.0"), nil).Once()
		runner.On("Output", "go", []string{"mod", "download", "-json", "example.com/tool@v1.1.0"}).Return(downloadJSON, nil).Once()

		err := run(commandConfig{
			packageToInstall: "example.com/tool",
			printVersionOnly: true,
		}, runner)
		require.NoError(t, err, "run should not error")
		// Run should NOT be called since we are only printing the version.
		runner.AssertNotCalled(t, "Run", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("print-version-only with install-latest prints latest when no compatible version found", func(t *testing.T) {
		// Discard all output to avoid making the test output messy.
		sharedUtils.NewDiscardHandlerLoggerRestoreAfterTest(t)

		downloadJSON := writeTmpGoModJSON(t, "module example.com/tool\n\ngo 1.23\n")

		runner := sharedUtils.NewMockRunner(t)
		runner.On("Output", "go", []string{"version"}).Return([]byte("go version go1.21.5 darwin/arm64"), nil).Once()
		runner.On("Output", "go", []string{"list", "-mod=readonly", "-m", "-versions", "example.com/tool"}).Return([]byte("example.com/tool v1.0.0"), nil).Once()
		runner.On("Output", "go", []string{"mod", "download", "-json", "example.com/tool@v1.0.0"}).Return(downloadJSON, nil).Once()

		err := run(commandConfig{
			packageToInstall: "example.com/tool",
			printVersionOnly: true,
			installLatest:    true,
		}, runner)
		require.NoError(t, err, "run should not error")
		// Run should NOT be called since we are only printing the version.
		runner.AssertNotCalled(t, "Run", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})
}
