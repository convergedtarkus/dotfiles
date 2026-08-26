package cache

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"time"

	"github.com/convergedtarkus/randomUtils/smartGoInstall/semver"
)

// cacheFileName is the name of the cache file, stored in the user's home directory.
const cacheFileName = ".smartGoInstallCache"

// cacheFilePermissions is the Unix file mode used when writing the cache file:
// rw-r--r-- (owner can read/write; group and others can only read).
const cacheFilePermissions os.FileMode = 0o644

// cacheTTL controls how long a cached version is trusted before it is
// re-resolved, so that newer, still-compatible releases eventually get picked up.
const cacheTTL = 30 * 24 * time.Hour // 30 days.

// timeNow is a seam for tests to control the current time.
var timeNow = time.Now

// cacheEntry is a single resolved version, along with when it was resolved.
type cacheEntry struct {
	Version  string    `json:"version"`
	CachedAt time.Time `json:"cachedAt"`
}

// InstallCache stores resolved compatible versions keyed by "<package>@<go-version>"
// so that repeated invocations for the same package/Go-version pair can skip the
// (potentially slow, network-bound) version-resolution steps, at least until the
// entry ages past cacheTTL.
type InstallCache struct {
	path    string
	Entries map[string]cacheEntry `json:"entries"`
}

// LoadInstallCache reads the cache from disk at path. If the file does not exist,
// an empty (but usable) cache is returned without error. If the file exists but
// cannot be read or parsed, an empty (but usable, pointing at path) cache is
// returned.
func LoadInstallCache() (*InstallCache, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return &InstallCache{Entries: map[string]cacheEntry{}}, fmt.Errorf("getting user home directory: %w", err)
	}
	cachePath := filepath.Join(homeDir, cacheFileName)
	return loadInstallCache(cachePath)
}

func loadInstallCache(cachePath string) (*InstallCache, error) {
	cache := &InstallCache{path: cachePath, Entries: map[string]cacheEntry{}}
	data, err := os.ReadFile(cachePath)
	if err != nil {
		if os.IsNotExist(err) {
			// No cache yet, make a new one.
			return cache, nil
		}
		// Cache cannot be read, likely corrupt.
		return cache, fmt.Errorf("reading cache file at %s: %w", cachePath, err)
	}

	if err := json.Unmarshal(data, cache); err != nil {
		// Cache cannot be read, likely corrupt.
		return cache, fmt.Errorf("parsing cache file at %s: %w", cachePath, err)
	}
	if cache.Entries == nil {
		cache.Entries = map[string]cacheEntry{}
	}
	return cache, nil
}

// Save writes the cache to disk as JSON.
func (c *InstallCache) Save() error {
	if c == nil || c.path == "" {
		return fmt.Errorf("no cache path set")
	}

	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return fmt.Errorf("marshaling cache: %w", err)
	}
	if err := os.WriteFile(c.path, data, cacheFilePermissions); err != nil {
		return fmt.Errorf("writing cache file at %s: %w", c.path, err)
	}
	return nil
}

// cacheKey builds the lookup key for a package/Go-version pair.
func cacheKey(pkg string, goVersion semver.Version) string {
	return pkg + "@" + goVersion.String()
}

// Get returns the cached compatible version for the given package/Go-version
// pair, if present and not older than maxAge. An entry older than maxAge is
// treated as a miss so the caller re-resolves it, in case a newer compatible
// version has since been released.
func (c *InstallCache) Get(pkg string, goVersion semver.Version) (string, bool) {
	return c.get(pkg, goVersion, cacheTTL)
}

// Internal version of Get that allows passing in a cacheTTL.
func (c *InstallCache) get(pkg string, goVersion semver.Version, customCacheTTL time.Duration) (string, bool) {
	if c == nil {
		return "", false
	}
	key := cacheKey(pkg, goVersion)
	entry, ok := c.Entries[key]
	if !ok {
		return "", false
	}

	if age := timeNow().Sub(entry.CachedAt); age > customCacheTTL {
		slog.Debug("Cached entry expired; re-resolving", "key", key, "cachedAt", entry.CachedAt, "age", age)
		return "", false
	}

	return entry.Version, true
}

// Set records the resolved compatible version for the given package/Go-version
// pair, stamped with the current time.
func (c *InstallCache) Set(pkg string, goVersion semver.Version, version string) {
	if c == nil {
		return
	}
	c.Entries[cacheKey(pkg, goVersion)] = cacheEntry{Version: version, CachedAt: timeNow()}
}
