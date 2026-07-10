package main

import (
	"bytes"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/convergedtarkus/randomUtils/sharedUtils"
)

// mockDiskScanner is a testify mock implementation of the diskScanner interface.
type mockDiskScanner struct {
	mock.Mock
}

func newMockDiskScanner(t *testing.T) *mockDiskScanner {
	m := &mockDiskScanner{}
	t.Cleanup(func() {
		m.AssertExpectations(t)
	})
	return m
}

func (m *mockDiskScanner) DirSize(path string) (int64, error) {
	args := m.Called(path)
	return args.Get(0).(int64), args.Error(1)
}

func (m *mockDiskScanner) GetDiskUsage(path string) (diskUsageInfo, error) {
	args := m.Called(path)
	return args.Get(0).(diskUsageInfo), args.Error(1)
}

func (m *mockDiskScanner) UserHomeDir() (string, error) {
	args := m.Called()
	return args.String(0), args.Error(1)
}

func TestParseFlags(t *testing.T) {
	testCases := []struct {
		testName       string
		inputFlags     []string
		expectedConfig commandConfig
		expectedError  string
	}{
		{testName: "defaults with no args", inputFlags: []string{}, expectedConfig: commandConfig{thresholdMB: 500}},
		{testName: "custom threshold with --threshold", inputFlags: []string{"--threshold", "100"}, expectedConfig: commandConfig{thresholdMB: 100}},
		{testName: "custom threshold with -t shorthand", inputFlags: []string{"-t", "200"}, expectedConfig: commandConfig{thresholdMB: 200}},
		{testName: "verbose with -v", inputFlags: []string{"-v"}, expectedConfig: commandConfig{thresholdMB: 500, verbose: true}},
		{testName: "verbose with --verbose", inputFlags: []string{"--verbose"}, expectedConfig: commandConfig{thresholdMB: 500, verbose: true}},
		{testName: "extra directories as trailing args", inputFlags: []string{"/tmp/cache1", "/tmp/cache2"}, expectedConfig: commandConfig{thresholdMB: 500, extraDirs: []string{"/tmp/cache1", "/tmp/cache2"}}},
		{testName: "all flags with extra dirs", inputFlags: []string{"-v", "-t", "50", "/some/dir"}, expectedConfig: commandConfig{thresholdMB: 50, verbose: true, extraDirs: []string{"/some/dir"}}},
		{testName: "help flag", inputFlags: []string{"--help"}, expectedError: flag.ErrHelp.Error()},
		{testName: "unknown flag", inputFlags: []string{"-z"}, expectedError: "flag provided but not defined: -z"},
	}
	for _, tc := range testCases {
		tc := tc
		t.Run(tc.testName, func(t *testing.T) {
			cfg, err := parseFlags(tc.inputFlags, io.Discard)
			if tc.expectedError != "" {
				assert.EqualError(t, err, tc.expectedError, "expected error did not match actual error")
				return
			}
			require.NoError(t, err, "parseFlags should not error")
			assert.Equal(t, tc.expectedConfig.thresholdMB, cfg.thresholdMB, "wrong thresholdMB")
			assert.Equal(t, tc.expectedConfig.verbose, cfg.verbose, "wrong verbose")
			if tc.expectedConfig.extraDirs == nil {
				assert.Empty(t, cfg.extraDirs, "expected no extra dirs")
			} else {
				assert.Equal(t, tc.expectedConfig.extraDirs, cfg.extraDirs, "wrong extraDirs")
			}
		})
	}
}

func TestGoModCachePath(t *testing.T) {
	t.Run("GOMODCACHE set", func(t *testing.T) {
		t.Setenv("GOMODCCHE", "/custom/modcache")
		t.Setenv("GOPATH", "/should/be/ignored")
		actual := goModCachePath()
		assert.Equal(t, "/custom/modcache", actual)
	})
	t.Run("GOPATH set without GOMODCACHE", func(t *testing.T) {
		t.Setenv("GOMODCCHE", "")
		t.Setenv("GOPATH", "/my/gopath")
		actual := goModCachePath()
		assert.Equal(t, "/my/gopath/pkg/mod", actual)
	})
	t.Run("GOPATH with multiple entries", func(t *testing.T) {
		t.Setenv("GOMODCACHE", "")
		t.Setenv("GOPATH", "/first/path"+string(os.PathListSeparator)+"/second/path")
		actual := goModCachePath()
		assert.Equal(t, "/first/path/pkg/mod", actual, "should use the first GOPATH entry")
	})
	t.Run("neither set falls back to default", func(t *testing.T) {
		t.Setenv("GOMODCCHE", "")
		t.Setenv("GOPATH", "")
		actual := goModCachePath()
		assert.Equal(t, "~/go/pkg/mod", actual)
	})
}

func TestGoEnvCachePath(t *testing.T) {
	t.Run("env var set", func(t *testing.T) {
		t.Setenv("GOCACHE", "/custom/cache")
		actual := goEnvCachePath("GOCACHE", "/fallback")
		assert.Equal(t, "/custom/cache", actual)
	})
	t.Run("env var empty uses fallback", func(t *testing.T) {
		t.Setenv("GOCACHE", "")
		actual := goEnvCachePath("GOCACHE", "/fallback")
		assert.Equal(t, "/fallback", actual)
	})
}

func TestResolvePath(t *testing.T) {
	testCases := []struct {
		testName, path, homeDir, expectedPath string
	}{
		{"tilde prefix", "~/some/dir", "/Users/testuser", "/Users/testuser/some/dir"},
		{"tilde only", "~", "/Users/testuser", "/Users/testuser"},
		{"absolute path unchanged", "/var/cache/something", "/Users/testuser", "/var/cache/something"},
		{"relative path unchanged", "relative/dir", "/Users/testuser", "relative/dir"},
	}
	for _, tc := range testCases {
		tc := tc
		t.Run(tc.testName, func(t *testing.T) {
			actual := resolvePath(tc.path, tc.homeDir)
			assert.Equal(t, tc.expectedPath, actual)
		})
	}
}

func TestDirSize(t *testing.T) {
	t.Run("directory with files", func(t *testing.T) {
		tmpDir := t.TempDir()
		writeFile(t, filepath.Join(tmpDir, "a.txt"), 1000)
		writeFile(t, filepath.Join(tmpDir, "b.txt"), 2000)
		subDir := filepath.Join(tmpDir, "sub")
		require.NoError(t, os.Mkdir(subDir, 0755), "Mkdir should not error")
		writeFile(t, filepath.Join(subDir, "c.txt"), 500)
		actual, err := dirSize(tmpDir)
		require.NoError(t, err, "dirSize should not error")
		assert.Equal(t, int64(3500), actual)
	})
	t.Run("empty directory", func(t *testing.T) {
		tmpDir := t.TempDir()
		actual, err := dirSize(tmpDir)
		require.NoError(t, err, "dirSize should not error")
		assert.Zero(t, actual)
	})
	t.Run("nonexistent directory", func(t *testing.T) {
		_, err := dirSize("/nonexistent/path/that/does/not/exist")
		assert.Error(t, err)
	})
	t.Run("single file", func(t *testing.T) {
		tmpDir := t.TempDir()
		fp := filepath.Join(tmpDir, "single.txt")
		writeFile(t, fp, 750)
		actual, err := dirSize(fp)
		require.NoError(t, err, "dirSize should not error")
		assert.Equal(t, int64(750), actual)
	})
}

func TestFormatSize(t *testing.T) {
	testCases := []struct {
		testName string
		bytes    int64
		expected string
	}{
		{"bytes", 512, "512 B"},
		{"kilobytes", 1536, "1.50 KB"},
		{"megabytes", 10 * 1024 * 1024, "10.00 MB"},
		{"gigabytes", 3 * 1024 * 1024 * 1024, "3.00 GB"},
		{"zero", 0, "0 B"},
	}
	for _, tc := range testCases {
		tc := tc
		t.Run(tc.testName, func(t *testing.T) {
			actual := formatSize(tc.bytes)
			assert.Equal(t, tc.expected, actual)
		})
	}
}

func TestPrintResults(t *testing.T) {
	oldStdout := os.Stdout
	r, w, err := os.Pipe()
	require.NoError(t, err, "os.Pipe should not error")
	os.Stdout = w
	results := []scanResult{
		{name: "Big Cache", path: "/home/user/.cache/big", sizeBytes: 2 * 1024 * 1024 * 1024},
		{name: "Small Cache", path: "/home/user/.cache/small", sizeBytes: 500 * 1024 * 1024},
	}
	printResults(results, diskUsageInfo{
		totalBytes: 500 * 1024 * 1024 * 1024,
		usedBytes:  300 * 1024 * 1024 * 1024,
	})
	require.NoError(t, w.Close(), "Close should not error")
	os.Stdout = oldStdout
	var buf bytes.Buffer
	_, err = buf.ReadFrom(r)
	require.NoError(t, err, "ReadFrom should not error")
	output := buf.String()
	assert.Contains(t, output, "Big Cache")
	assert.Contains(t, output, "Small Cache")
	assert.Contains(t, output, "2.00 GB")
	assert.Contains(t, output, "500.00 MB")
	assert.Contains(t, output, "TOTAL")
	assert.Contains(t, output, "/home/user/.cache/big")
	assert.Contains(t, output, "/home/user/.cache/small")
	assert.Contains(t, output, "Disk Usage:")
	assert.Contains(t, output, "Hotspots account for")
}

func TestRun(t *testing.T) {
	t.Run("scans extra directories above threshold", func(t *testing.T) {
		sharedUtils.NewDiscardHandlerLoggerRestoreAfterTest(t)

		scanner := newMockDiskScanner(t)
		scanner.On("UserHomeDir").Return("/home/testuser", nil).Once()
		scanner.On("GetDiskUsage", "/home/testuser").Return(diskUsageInfo{
			totalBytes: 500 * 1024 * 1024 * 1024,
			usedBytes:  200 * 1024 * 1024 * 1024,
		}, nil).Once()
		// The extra directory exceeds the threshold — register before the catch-all.
		scanner.On("DirSize", "/extra/cache").Return(int64(2*1024*1024), nil).Once()
		// Default hotspots all return 0 (below threshold).
		scanner.On("DirSize", mock.AnythingOfType("string")).Return(int64(0), nil)

		cfg := commandConfig{thresholdMB: 1, extraDirs: []string{"/extra/cache"}}
		err := run(cfg, scanner)
		require.NoError(t, err, "run should not error")
	})

	t.Run("reports nothing when below threshold", func(t *testing.T) {
		sharedUtils.NewDiscardHandlerLoggerRestoreAfterTest(t)

		scanner := newMockDiskScanner(t)
		scanner.On("UserHomeDir").Return("/home/testuser", nil).Once()
		scanner.On("GetDiskUsage", "/home/testuser").Return(diskUsageInfo{
			totalBytes: 500 * 1024 * 1024 * 1024,
			usedBytes:  200 * 1024 * 1024 * 1024,
		}, nil).Once()
		// All directories return small sizes.
		scanner.On("DirSize", mock.AnythingOfType("string")).Return(int64(100), nil)

		cfg := commandConfig{thresholdMB: 500, extraDirs: []string{"/extra/small"}}
		err := run(cfg, scanner)
		require.NoError(t, err, "run should not error")
	})

	t.Run("handles nonexistent extra directory gracefully", func(t *testing.T) {
		sharedUtils.NewDiscardHandlerLoggerRestoreAfterTest(t)

		scanner := newMockDiskScanner(t)
		scanner.On("UserHomeDir").Return("/home/testuser", nil).Once()
		scanner.On("GetDiskUsage", "/home/testuser").Return(diskUsageInfo{
			totalBytes: 500 * 1024 * 1024 * 1024,
			usedBytes:  200 * 1024 * 1024 * 1024,
		}, nil).Once()
		// The nonexistent directory returns an error — register before catch-all.
		scanner.On("DirSize", "/nonexistent/path/abc123").Return(int64(0), fmt.Errorf("no such file or directory")).Once()
		// Default hotspots return 0.
		scanner.On("DirSize", mock.AnythingOfType("string")).Return(int64(0), nil)

		cfg := commandConfig{thresholdMB: 1, extraDirs: []string{"/nonexistent/path/abc123"}}
		err := run(cfg, scanner)
		require.NoError(t, err, "run should not error")
	})

	t.Run("UserHomeDir error propagates", func(t *testing.T) {
		sharedUtils.NewDiscardHandlerLoggerRestoreAfterTest(t)

		scanner := newMockDiskScanner(t)
		scanner.On("UserHomeDir").Return("", fmt.Errorf("home dir unknown")).Once()

		cfg := commandConfig{thresholdMB: 500}
		err := run(cfg, scanner)
		assert.ErrorContains(t, err, "determining home directory")
	})

	t.Run("GetDiskUsage error does not fail run", func(t *testing.T) {
		sharedUtils.NewDiscardHandlerLoggerRestoreAfterTest(t)

		scanner := newMockDiskScanner(t)
		scanner.On("UserHomeDir").Return("/home/testuser", nil).Once()
		scanner.On("GetDiskUsage", "/home/testuser").Return(diskUsageInfo{}, fmt.Errorf("statfs failed")).Once()
		// All directories return small sizes so nothing is reported.
		scanner.On("DirSize", mock.AnythingOfType("string")).Return(int64(0), nil)

		cfg := commandConfig{thresholdMB: 500}
		err := run(cfg, scanner)
		require.NoError(t, err, "run should not error even when GetDiskUsage fails")
	})
}

func writeFile(t *testing.T, path string, sizeBytes int) {
	t.Helper()
	data := make([]byte, sizeBytes)
	require.NoError(t, os.WriteFile(path, data, 0644), "WriteFile should not error")
}
