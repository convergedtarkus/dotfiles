// This provides a tool to clean up the .pub-cache directory by removing
// older versions of packages, keeping only the most recent N versions.
// This code was written by AI (Claude Opus 4.5) to be specific.
package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"

	"github.com/convergedtarkus/randomUtils/sharedUtils"
)

// packageVersion represents a package directory with its parsed version info.
type packageVersion struct {
	// FullPath is the absolute path to the package directory.
	FullPath string
	// Name is the package name without the version suffix.
	Name string
	// Version is the semantic version string (with "v" prefix for semver comparison).
	Version string
	// OriginalVersion is the version string as it appears in the directory name.
	OriginalVersion string
	// Size is the total size of the directory in bytes.
	Size int64
}

// unparsableEntry represents a directory that could not be parsed for versioning.
type unparsableEntry struct {
	// FullPath is the absolute path to the directory.
	FullPath string
	// Reason explains why the entry could not be parsed.
	Reason string
}

func main() {
	keepCount, performDelete, cacheDir, skipSize, workers := parseAndValidateFlags()

	// Scan the cache directory
	packages, unparsable, err := scanCacheDirectory(*cacheDir, *skipSize, *workers)
	if err != nil {
		fmt.Printf("Error scanning cache directory: %v\n", err)
		os.Exit(1)
	}

	// Report unparsable entries
	if len(unparsable) > 0 {
		fmt.Printf("Unparsable entries (may require manual review):\n")
		fmt.Printf("-----------------------------------------------\n")
		for _, entry := range unparsable {
			fmt.Printf("  %s\n    Reason: %s\n", entry.FullPath, entry.Reason)
		}
		fmt.Println()
	}

	// Group packages by name and determine which to delete
	toDelete := determinePackagesToDelete(packages, *keepCount)

	if len(toDelete) == 0 {
		fmt.Println("No packages to delete. Cache is already clean.")
		return
	}

	// Report what will be deleted
	fmt.Printf("Packages to delete (%d total):\n", len(toDelete))
	fmt.Printf("------------------------------\n")

	// Group by package name for clearer output
	var totalSizeToDelete int64
	deleteByName := make(map[string][]packageVersion)
	packageTotalSizeByName := make(map[string]int64)
	for _, pkg := range toDelete {
		totalSizeToDelete += pkg.Size
		deleteByName[pkg.Name] = append(deleteByName[pkg.Name], pkg)
		packageTotalSizeByName[pkg.Name] += pkg.Size
	}

	names := make([]string, 0, len(deleteByName))
	for name := range deleteByName {
		names = append(names, name)
	}
	sort.Strings(names)

	for _, name := range names {
		versions := deleteByName[name]
		if *skipSize {
			fmt.Printf("\n  %s:\n", name)
		} else {
			fmt.Printf("\n  %s (total: %s):\n", name, formatBytes(packageTotalSizeByName[name]))
		}
		for _, pkg := range versions {
			if *skipSize {
				fmt.Printf("    - %s\n", pkg.OriginalVersion)
			} else {
				fmt.Printf("    - %s (%s)\n", pkg.OriginalVersion, formatBytes(pkg.Size))
			}
		}
	}

	if *skipSize {
		fmt.Printf("\nTotal space to be freed: (skipped - use without -skip-size to calculate)\n")
	} else {
		fmt.Printf("\nTotal space to be freed: %s\n", formatBytes(totalSizeToDelete))
	}

	// Perform deletion if requested
	fmt.Println()
	if *performDelete {
		deletePackages(toDelete)
	} else {
		fmt.Println("Run with -delete flag to actually remove these packages.")
	}
}

// deletePackages takes a list of package versions to delete and attempts to remove them from the filesystem.
func deletePackages(toDelete []packageVersion) {
	fmt.Println("Deleting packages...")

	var freedSpace int64
	var deleteErrors []string

	for _, pkg := range toDelete {
		err := os.RemoveAll(pkg.FullPath)
		if err != nil {
			fmt.Printf("  Deleting %s-%s ERROR: %v\n ", pkg.Name, pkg.OriginalVersion, err)
			deleteErrors = append(deleteErrors, fmt.Sprintf("%s: %v", pkg.FullPath, err))
		} else {
			freedSpace += pkg.Size
		}
	}

	fmt.Println()
	fmt.Printf("Space freed: %s\n", formatBytes(freedSpace))

	if len(deleteErrors) > 0 {
		fmt.Printf("\nErrors encountered during deletion:\n")
		for _, errMsg := range deleteErrors {
			fmt.Printf("  - %s\n", errMsg)
		}
		os.Exit(1)
	}
}

// parseAndValidateFlags parses command-line flags and validates them, returning the values.
// Also prints the configuration that will be used for the run.
func parseAndValidateFlags() (*int, *bool, *string, *bool, *int) {
	// Define command-line flags
	keepCount := flag.Int("keep", 3, "Number of versions to keep for each package")
	performDelete := flag.Bool("delete", false, "Actually perform the deletion (default is dry-run mode)")
	cacheDir := flag.String("dir", filepath.Join(os.Getenv("HOME"), ".pub-cache", "hosted"), "Path to the pub-cache hosted directory")
	skipSize := flag.Bool("skip-size", false, "Skip calculating directory sizes (much faster, but won't show space savings)")
	workers := flag.Int("workers", runtime.NumCPU(), "Number of parallel workers for size calculation")
	flag.Parse()

	if *keepCount < 1 {
		fmt.Println("Error: -keep must be at least 1")
		os.Exit(1)
	}

	if *workers < 1 {
		fmt.Println("Error: -workers must be at least 1")
		os.Exit(1)
	}

	fmt.Printf("Pub-cache cleaner\n")
	fmt.Printf("=================\n")
	fmt.Printf("Cache directory: %s\n", *cacheDir)
	fmt.Printf("Versions to keep: %d\n", *keepCount)
	if *skipSize {
		fmt.Printf("Size calculation: SKIPPED (fast mode)\n")
	} else {
		fmt.Printf("Size calculation: ENABLED (using %d workers)\n", *workers)
	}
	if *performDelete {
		fmt.Printf("Mode: DELETE (will remove files)\n")
	} else {
		fmt.Printf("Mode: DRY-RUN (no files will be removed)\n")
	}
	fmt.Println()

	// Check if the directory exists
	if _, err := os.Stat(*cacheDir); os.IsNotExist(err) {
		fmt.Printf("Error: Cache directory does not exist: %s\n", *cacheDir)
		os.Exit(1)
	}
	return keepCount, performDelete, cacheDir, skipSize, workers
}

// scanCacheDirectory scans the pub-cache hosted directory and returns all
// package versions found, along with any unparsable entries.
func scanCacheDirectory(cacheDir string, skipSize bool, numWorkers int) ([]packageVersion, []unparsableEntry, error) {
	var packages []packageVersion
	var unparsable []unparsableEntry

	// The pub-cache/hosted directory contains subdirectories for each host (e.g., pub.dev)
	hostDirs, err := os.ReadDir(cacheDir)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to read cache directory: %w", err)
	}

	// First pass: collect all package paths and parse names/versions (fast)
	type packageInfo struct {
		fullPath        string
		canonicalName   string
		version         string
		originalVersion string
	}
	var allPackages []packageInfo

	for _, hostDir := range hostDirs {
		if !hostDir.IsDir() {
			continue
		}

		hostPath := filepath.Join(cacheDir, hostDir.Name())
		packageDirs, err := os.ReadDir(hostPath)
		if err != nil {
			unparsable = append(unparsable, unparsableEntry{
				FullPath: hostPath,
				Reason:   fmt.Sprintf("failed to read host directory: %v", err),
			})
			continue
		}

		for _, packageDir := range packageDirs {
			if !packageDir.IsDir() {
				continue
			}

			fullPath := filepath.Join(hostPath, packageDir.Name())
			name, version, err := parsePackageDirectory(packageDir.Name())
			if err != nil {
				unparsable = append(unparsable, unparsableEntry{
					FullPath: fullPath,
					Reason:   err.Error(),
				})
				continue
			}

			// Create a canonical key that includes the host to avoid conflicts
			// between packages from different hosts
			canonicalName := fmt.Sprintf("%s/%s", hostDir.Name(), name)

			allPackages = append(allPackages, packageInfo{
				fullPath:        fullPath,
				canonicalName:   canonicalName,
				version:         "v" + version,
				originalVersion: version,
			})
		}
	}

	// If skipping size calculation, just return packages with zero size
	if skipSize {
		for _, pkg := range allPackages {
			packages = append(packages, packageVersion{
				FullPath:        pkg.fullPath,
				Name:            pkg.canonicalName,
				Version:         pkg.version,
				OriginalVersion: pkg.originalVersion,
			})
		}
		return packages, unparsable, nil
	}

	// Second pass: calculate sizes in parallel
	type sizeResult struct {
		index int
		size  int64
		err   error
	}

	// Create work channel and results channel
	work := make(chan int, len(allPackages))
	results := make(chan sizeResult, len(allPackages))

	// Start worker goroutines
	var wg sync.WaitGroup
	for i := 0; i < numWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for idx := range work {
				size, err := calculateDirSize(allPackages[idx].fullPath)
				results <- sizeResult{index: idx, size: size, err: err}
			}
		}()
	}

	// Send work to workers
	for i := range allPackages {
		work <- i
	}
	close(work)

	// Wait for workers to finish and close results
	go func() {
		wg.Wait()
		close(results)
	}()

	// Collect results
	sizes := make(map[int]int64)
	var sizeErrors []sizeResult
	for result := range results {
		if result.err != nil {
			sizeErrors = append(sizeErrors, result)
		} else {
			sizes[result.index] = result.size
		}
	}

	// Build final package list
	for i, pkg := range allPackages {
		if size, ok := sizes[i]; ok {
			packages = append(packages, packageVersion{
				FullPath:        pkg.fullPath,
				Name:            pkg.canonicalName,
				Version:         pkg.version,
				OriginalVersion: pkg.originalVersion,
				Size:            size,
			})
		}
	}

	// Add size errors to unparsable
	for _, errResult := range sizeErrors {
		pkg := allPackages[errResult.index]
		unparsable = append(unparsable, unparsableEntry{
			FullPath: pkg.fullPath,
			Reason:   fmt.Sprintf("failed to calculate size: %v", errResult.err),
		})
	}

	return packages, unparsable, nil
}

// parsePackageDirectory parses a package directory name to extract the package
// name and version. Directory names are expected to be in the format "name-version".
func parsePackageDirectory(dirName string) (name, version string, err error) {
	// Semantic version pattern: major.minor.patch with optional pre-release and build metadata
	// Examples: 1.0.0, 1.0.0-beta.1, 1.0.0+build.1
	semverPattern := regexp.MustCompile(`^(.+)-(\d+\.\d+\.\d+(?:[-+].*)?)$`)

	matches := semverPattern.FindStringSubmatch(dirName)
	if matches == nil {
		return "", "", fmt.Errorf("directory name does not match expected pattern 'name-version': %s", dirName)
	}

	name = matches[1]
	version = matches[2]

	// Validate that the version is a valid semver
	if !isValidSemver(version) {
		return "", "", fmt.Errorf("invalid semantic version: %s", version)
	}

	return name, version, nil
}

// calculateDirSize calculates the total size of a directory and its contents.
func calculateDirSize(path string) (int64, error) {
	var size int64
	err := filepath.Walk(path, func(_ string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			size += info.Size()
		}
		return nil
	})
	return size, err
}

// determinePackagesToDelete groups packages by name, sorts by version, and
// returns the older versions that should be deleted (keeping the most recent N).
func determinePackagesToDelete(packages []packageVersion, keepCount int) []packageVersion {
	// Group by package name
	byName := make(map[string][]packageVersion)
	for _, pkg := range packages {
		byName[pkg.Name] = append(byName[pkg.Name], pkg)
	}

	var toDelete []packageVersion

	for _, versions := range byName {
		if len(versions) <= keepCount {
			// Not enough versions to require deletion
			continue
		}

		// Sort by version (newest first)
		sort.Slice(versions, func(i, j int) bool {
			return compareSemver(versions[i].Version, versions[j].Version) > 0
		})

		// Mark older versions for deletion
		toDelete = append(toDelete, versions[keepCount:]...)
	}

	// Sort the delete list for consistent output
	sort.Slice(toDelete, func(i, j int) bool {
		if toDelete[i].Name != toDelete[j].Name {
			return toDelete[i].Name < toDelete[j].Name
		}
		return compareSemver(toDelete[i].Version, toDelete[j].Version) > 0
	})

	return toDelete
}

// parsedVersion holds the parsed components of a semantic version.
type parsedVersion struct {
	Major      int
	Minor      int
	Patch      int
	Prerelease string
	Build      string
}

// isValidSemver checks if a version string is a valid semantic version.
func isValidSemver(version string) bool {
	_, err := parseSemver(version)
	return err == nil
}

// parseSemver parses a semantic version string into its components.
// Accepts versions with or without a leading "v".
func parseSemver(version string) (parsedVersion, error) {
	// Remove leading "v" if present
	version = strings.TrimPrefix(version, "v")

	var pv parsedVersion

	// Split off build metadata first (after +)
	if idx := strings.Index(version, "+"); idx != -1 {
		pv.Build = version[idx+1:]
		version = version[:idx]
	}

	// Split off prerelease (after -)
	if idx := strings.Index(version, "-"); idx != -1 {
		pv.Prerelease = version[idx+1:]
		version = version[:idx]
	}

	// Parse major.minor.patch
	parts := strings.Split(version, ".")
	if len(parts) != 3 {
		return parsedVersion{}, fmt.Errorf("invalid version format: expected major.minor.patch")
	}

	var err error
	pv.Major, err = strconv.Atoi(parts[0])
	if err != nil {
		return parsedVersion{}, fmt.Errorf("invalid major version: %s", parts[0])
	}

	pv.Minor, err = strconv.Atoi(parts[1])
	if err != nil {
		return parsedVersion{}, fmt.Errorf("invalid minor version: %s", parts[1])
	}

	pv.Patch, err = strconv.Atoi(parts[2])
	if err != nil {
		return parsedVersion{}, fmt.Errorf("invalid patch version: %s", parts[2])
	}

	return pv, nil
}

// compareSemver compares two semantic versions.
// Returns:
//
//	-1 if v1 < v2
//	 0 if v1 == v2
//	 1 if v1 > v2
func compareSemver(v1, v2 string) int {
	pv1, err1 := parseSemver(v1)
	pv2, err2 := parseSemver(v2)

	// If either fails to parse, fall back to string comparison
	if err1 != nil || err2 != nil {
		return strings.Compare(v1, v2)
	}

	// Compare major
	if pv1.Major != pv2.Major {
		if pv1.Major > pv2.Major {
			return 1
		}
		return -1
	}

	// Compare minor
	if pv1.Minor != pv2.Minor {
		if pv1.Minor > pv2.Minor {
			return 1
		}
		return -1
	}

	// Compare patch
	if pv1.Patch != pv2.Patch {
		if pv1.Patch > pv2.Patch {
			return 1
		}
		return -1
	}

	// Compare prerelease
	// No prerelease > prerelease (e.g., 1.0.0 > 1.0.0-beta)
	if pv1.Prerelease == "" && pv2.Prerelease != "" {
		return 1
	}
	if pv1.Prerelease != "" && pv2.Prerelease == "" {
		return -1
	}
	if pv1.Prerelease != pv2.Prerelease {
		return comparePrerelease(pv1.Prerelease, pv2.Prerelease)
	}

	return 0
}

// comparePrerelease compares two prerelease strings according to semver rules.
func comparePrerelease(pr1, pr2 string) int {
	parts1 := strings.Split(pr1, ".")
	parts2 := strings.Split(pr2, ".")

	minLen := len(parts1)
	if len(parts2) < minLen {
		minLen = len(parts2)
	}

	for i := 0; i < minLen; i++ {
		// Try to compare as numbers first
		num1, err1 := strconv.Atoi(parts1[i])
		num2, err2 := strconv.Atoi(parts2[i])

		if err1 == nil && err2 == nil {
			// Both are numbers
			if num1 != num2 {
				if num1 > num2 {
					return 1
				}
				return -1
			}
		} else {
			// At least one is not a number, compare as strings
			cmp := strings.Compare(parts1[i], parts2[i])
			if cmp != 0 {
				return cmp
			}
		}
	}

	// If all compared parts are equal, longer prerelease is greater
	if len(parts1) > len(parts2) {
		return 1
	}
	if len(parts1) < len(parts2) {
		return -1
	}

	return 0
}

// formatBytes formats a byte count as a human-readable string.
func formatBytes(bytes int64) string {
	const (
		KB = 1024
		MB = KB * 1024
		GB = MB * 1024
	)

	switch {
	case bytes >= GB:
		return fmt.Sprintf("%.2f GB", float64(bytes)/GB)
	case bytes >= MB:
		return fmt.Sprintf("%.2f MB", float64(bytes)/MB)
	case bytes >= KB:
		return fmt.Sprintf("%.2f KB", float64(bytes)/KB)
	default:
		return fmt.Sprintf("%d bytes", bytes)
	}
}

// String returns a string representation of the packageVersion for logging.
func (pv packageVersion) String() string {
	return fmt.Sprintf("%s-%s", pv.Name, pv.OriginalVersion)
}

// String returns a string representation of the unparsableEntry for logging.
func (ue unparsableEntry) String() string {
	return fmt.Sprintf("%s: %s", ue.FullPath, ue.Reason)
}

func init() {
	flag.Usage = func() {
		sharedUtils.Fprintf(os.Stderr, "Usage: go run pubCacheClean.go [options]\n\n")
		sharedUtils.Fprintf(os.Stderr, "A tool to clean up the Dart/Flutter pub-cache by removing older versions\n")
		sharedUtils.Fprintf(os.Stderr, "of packages, keeping only the most recent N versions of each package.\n\n")
		sharedUtils.Fprintf(os.Stderr, "Options:\n")
		flag.PrintDefaults()
	}
}
