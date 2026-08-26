package cache

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/convergedtarkus/randomUtils/smartGoInstall/semver"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// freezeTime overrides timeNow for the duration of the test and restores it afterward.
func freezeTime(t *testing.T, fixed time.Time) {
	t.Helper()
	previous := timeNow
	timeNow = func() time.Time { return fixed }
	t.Cleanup(func() { timeNow = previous })
}

func TestLoadInstallCache(t *testing.T) {
	t.Run("missing file returns empty usable cache", func(t *testing.T) {
		path := filepath.Join(t.TempDir(), ".smartGoInstallCache")
		cache, err := loadInstallCache(path)
		require.NoError(t, err, "loadInstallCache should not error for a missing file")
		assert.Equal(t, path, cache.path)
		assert.Empty(t, cache.Entries)

		_, ok := cache.Get("example.com/tool", parseVersion(t, "1.21"))
		assert.False(t, ok, "expected no cached entry")
	})

	t.Run("valid cache file is parsed", func(t *testing.T) {
		// Freeze "now" to just after the entry's cachedAt so it's well within cacheTTL.
		freezeTime(t, time.Date(2026, 1, 1, 1, 0, 0, 0, time.UTC))

		require.NoError(t, os.WriteFile(
			filepath.Join(userHome(t), ".smartGoInstallCache"),
			[]byte(`{"entries":{"example.com/tool@1.21":{"version":"v1.1.0","cachedAt":"2026-01-01T00:00:00Z"}}}`),
			0o644,
		))

		cache, err := LoadInstallCache()
		require.NoError(t, err, "loadInstallCache should not error for a valid file")

		version, ok := cache.Get("example.com/tool", parseVersion(t, "1.21"))
		require.True(t, ok, "expected a cached entry")
		assert.Equal(t, "v1.1.0", version)
	})

	t.Run("corrupt cache file returns error but still usable cache", func(t *testing.T) {
		path := filepath.Join(userHome(t), ".smartGoInstallCache")
		require.NoError(t, os.WriteFile(path, []byte("not valid json"), 0o644))

		cache, err := LoadInstallCache()
		assert.ErrorContains(t, err, "parsing cache file at")
		assert.Equal(t, path, cache.path)
		assert.Empty(t, cache.Entries)
	})

	t.Run("unreadable cache file returns error but still usable cache", func(t *testing.T) {
		// A directory at the cache path can't be read as a file, which
		// triggers a non-"not exist" error from os.ReadFile.
		path := filepath.Join(t.TempDir(), ".smartGoInstallCache")
		require.NoError(t, os.Mkdir(path, 0o755))

		cache, err := loadInstallCache(path)
		assert.ErrorContains(t, err, "reading cache file at")
		assert.Equal(t, path, cache.path)
		assert.Empty(t, cache.Entries)
	})
}

func TestInstallCacheSaveAndRoundTrip(t *testing.T) {
	now := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	freezeTime(t, now)

	path := filepath.Join(t.TempDir(), ".smartGoInstallCache")

	cache := &InstallCache{path: path, Entries: map[string]cacheEntry{}}
	cache.Set("example.com/tool", parseVersion(t, "1.21"), "v1.1.0")
	cache.Set("example.com/tool/cmd/tool", parseVersion(t, "1.20"), "v0.9.0")

	require.NoError(t, cache.Save(), "save should not error")

	reloaded, err := loadInstallCache(path)
	require.NoError(t, err, "loadInstallCache should not error")

	version, ok := reloaded.Get("example.com/tool", parseVersion(t, "1.21"))
	require.True(t, ok)
	assert.Equal(t, "v1.1.0", version)
	assert.Equal(t, now, reloaded.Entries[cacheKey("example.com/tool", parseVersion(t, "1.21"))].CachedAt)

	version, ok = reloaded.Get("example.com/tool/cmd/tool", parseVersion(t, "1.20"))
	require.True(t, ok)
	assert.Equal(t, "v0.9.0", version)

	// A different Go version for a cached package should not be a hit.
	_, ok = reloaded.Get("example.com/tool", parseVersion(t, "1.22"))
	assert.False(t, ok)
}

func TestInstallCacheSaveWithoutPath(t *testing.T) {
	cache := &InstallCache{Entries: map[string]cacheEntry{}}
	err := cache.Save()
	assert.EqualError(t, err, "no cache path set")
}

func TestCacheKey(t *testing.T) {
	key := cacheKey("example.com/tool", parseVersion(t, "1.21"))
	assert.Equal(t, "example.com/tool@1.21", key)
}

func TestInstallCacheGetExpiry(t *testing.T) {
	setAt := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)

	testCases := []struct {
		testName             string
		now                  time.Time
		useZeroCacheDuration bool
		expectedHit          bool
	}{
		{
			testName:    "well within TTL",
			now:         setAt.Add(time.Hour),
			expectedHit: true,
		},
		{
			testName:    "exactly at TTL boundary is still a hit",
			now:         setAt.Add(cacheTTL),
			expectedHit: true,
		},
		{
			testName: "just past TTL is a miss",
			now:      setAt.Add(cacheTTL + time.Second),
		},
		{
			testName: "long past TTL (e.g. over a month later) is a miss",
			now:      setAt.AddDate(0, 2, 0),
		},
		{
			testName:             "maxAge of zero always expires",
			now:                  setAt.AddDate(10, 0, 0),
			useZeroCacheDuration: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.testName, func(t *testing.T) {
			freezeTime(t, setAt)
			cache := &InstallCache{Entries: map[string]cacheEntry{}}
			cache.Set("example.com/tool", parseVersion(t, "1.21"), "v1.1.0")

			freezeTime(t, tc.now)
			maxAge := cacheTTL
			if tc.useZeroCacheDuration {
				maxAge = 0
			}
			version, ok := cache.get("example.com/tool", parseVersion(t, "1.21"), maxAge)
			assert.Equal(t, tc.expectedHit, ok)
			if tc.expectedHit {
				assert.Equal(t, "v1.1.0", version)
			} else {
				assert.Empty(t, version)
			}
		})
	}
}

func TestCacheEntryJSONRoundTrip(t *testing.T) {
	entry := cacheEntry{Version: "v1.1.0", CachedAt: time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)}

	data, err := json.Marshal(entry)
	require.NoError(t, err)

	var decoded cacheEntry
	require.NoError(t, json.Unmarshal(data, &decoded))
	assert.Equal(t, entry, decoded)
}

func parseVersion(t *testing.T, versionString string) semver.Version {
	t.Helper()
	version, err := semver.ParseVersion(versionString)
	require.NoError(t, err, `ParseVersion for '%s' failed`, versionString)
	return version
}

func userHome(t *testing.T) string {
	t.Helper()
	homeDir, err := os.UserHomeDir()
	require.NoError(t, err, `Failed to get user home directory`)
	return homeDir
}
