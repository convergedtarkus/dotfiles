package main

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"syscall"

	"github.com/convergedtarkus/randomUtils/sharedUtils"
)

// commandConfig holds the parsed command-line configuration.
type commandConfig struct {
	// extraDirs are additional directories to scan beyond the defaults.
	extraDirs []string
	// thresholdMB is the minimum size in MB for a directory to be reported.
	thresholdMB int
	// verbose enables debug-level logging.
	verbose bool
}

// hotspot represents a well-known directory that tends to accumulate disk usage.
type hotspot struct {
	// name is a human-readable label for the hotspot (e.g. "Pub Cache").
	name string
	// path is the absolute path to check. May contain ~ for the home directory.
	path string
}

// scanResult holds the result of scanning a single directory.
type scanResult struct {
	// name is the human-readable label for this directory.
	name string
	// path is the absolute path that was scanned.
	path string
	// sizeBytes is the total size of the directory in bytes.
	sizeBytes int64
	// err is set if the directory could not be scanned.
	err error
}

// diskUsageInfo holds the overall disk usage statistics for the filesystem.
type diskUsageInfo struct {
	// totalBytes is the total size of the filesystem.
	totalBytes uint64
	// usedBytes is the amount of space currently in use.
	usedBytes uint64
}

// diskScanner abstracts filesystem operations for testability.
type diskScanner interface {
	// DirSize returns the total size of a directory tree in bytes.
	DirSize(path string) (int64, error)
	// GetDiskUsage returns the total and used disk space for the filesystem
	// containing the given path.
	GetDiskUsage(path string) (diskUsageInfo, error)
	// UserHomeDir returns the current user's home directory.
	UserHomeDir() (string, error)
}

// realDiskScanner is the production implementation of diskScanner that interacts
// with the real filesystem.
type realDiskScanner struct{}

func (r realDiskScanner) DirSize(path string) (int64, error) {
	return dirSize(path)
}

func (r realDiskScanner) GetDiskUsage(path string) (diskUsageInfo, error) {
	var stat syscall.Statfs_t
	if err := syscall.Statfs(path, &stat); err != nil {
		return diskUsageInfo{}, fmt.Errorf("statfs %s: %w", path, err)
	}
	total := stat.Blocks * uint64(stat.Bsize)
	free := stat.Bavail * uint64(stat.Bsize)
	return diskUsageInfo{
		totalBytes: total,
		usedBytes:  total - free,
	}, nil
}

func (r realDiskScanner) UserHomeDir() (string, error) {
	return os.UserHomeDir()
}

func main() {
	cfg, err := parseFlags(os.Args[1:], os.Stderr)
	if err != nil {
		if errors.Is(err, flag.ErrHelp) {
			os.Exit(0)
		}
		slog.Error("invalid arguments", "error", err)
		os.Exit(1)
	}

	logLevel := slog.LevelInfo
	if cfg.verbose {
		logLevel = slog.LevelDebug
	}
	slog.SetDefault(sharedUtils.NewMinimalHandlerLogger(logLevel))

	if err := run(cfg, realDiskScanner{}); err != nil {
		slog.Error("fatal error", "error", err)
		os.Exit(1)
	}
}

// parseFlags parses command-line arguments into a commandConfig.
func parseFlags(args []string, output io.Writer) (commandConfig, error) {
	fs := flag.NewFlagSet("diskHog", flag.ContinueOnError)
	fs.SetOutput(output)
	fs.Usage = func() {
		sharedUtils.Fprintf(fs.Output(), "Usage: diskHog [flags] [additional-directories...]\n\n")
		sharedUtils.Fprintf(fs.Output(), "Scans well-known cache directories and reports which ones are using\n")
		sharedUtils.Fprintf(fs.Output(), "significant disk space. Additional directories can be provided as\n")
		sharedUtils.Fprintf(fs.Output(), "trailing arguments.\n\n")
		sharedUtils.Fprintf(fs.Output(), "Flags:\n")
		fs.PrintDefaults()
	}

	var cfg commandConfig

	fs.IntVar(&cfg.thresholdMB, "threshold", 500, "minimum size in MB to report a directory")
	fs.IntVar(&cfg.thresholdMB, "t", 500, "shorthand for --threshold")

	fs.BoolVar(&cfg.verbose, "verbose", false, "enable verbose output")
	fs.BoolVar(&cfg.verbose, "v", false, "shorthand for --verbose")

	if err := fs.Parse(args); err != nil {
		return commandConfig{}, err
	}

	cfg.extraDirs = fs.Args()
	return cfg, nil
}

// goModCachePath returns the Go module cache path by checking $GOMODCACHE first,
// then $GOPATH/pkg/mod, and falling back to ~/go/pkg/mod (the default GOPATH).
func goModCachePath() string {
	if modCache := os.Getenv("GOMODCACHE"); modCache != "" {
		return modCache
	}
	if gopath := os.Getenv("GOPATH"); gopath != "" {
		// GOPATH can be a list; use the first entry.
		first, _, _ := strings.Cut(gopath, string(os.PathListSeparator))
		return filepath.Join(first, "pkg", "mod")
	}
	return "~/go/pkg/mod"
}

// goEnvCachePath returns the value of the given environment variable if set,
// otherwise returns the provided fallback path.
func goEnvCachePath(envVar, fallback string) string {
	if val := os.Getenv(envVar); val != "" {
		return val
	}
	return fallback
}

// defaultHotspots returns the default list of directories to check. The paths
// use ~ as a placeholder for the user's home directory, which is resolved at
// scan time.
func defaultHotspots() []hotspot {
	spots := []hotspot{
		// Library content
		{name: "Docker Desktop Data", path: "~/Library/Containers/com.docker.docker/Data"},
		{name: "Wallpaper Agent", path: "./Library/Containers/com.apple.wallpaper.agent/Data/"},
		// Go content
		{name: "Go Build Cache", path: goEnvCachePath("GOCACHE", "~/Library/Caches/go-build")},
		{name: "Go Module Cache", path: goModCachePath()},
		{name: "Maven Cache", path: "~/.m2/repository"},
		// Dart and Pub content.
		{name: "Dart Server", path: "~/.dartServer/"},
		{name: "Pub Cache (git)", path: "~/.pub-cache/git"},
		{name: "Pub Cache (hosted)", path: "~/.pub-cache/hosted"},
		// Caches
		{name: ".cache", path: "~/.cache/"},
		{name: "Homebrew Cache", path: "~/Library/Caches/Homebrew"},
		{name: "Spotify Cache", path: "./Library/Caches/com.spotify.client"},
		{name: "asdf", path: "~/.asdf/installs"},
		{name: "npm Cache", path: "~/.npm"},
		{name: "pnpm Store", path: "~/Library/pnpm/store"},
	}

	return spots
}

// run is the main application logic.
func run(cfg commandConfig, scanner diskScanner) error {
	homeDir, err := scanner.UserHomeDir()
	if err != nil {
		return fmt.Errorf("determining home directory: %w", err)
	}

	diskInfo, err := scanner.GetDiskUsage(homeDir)
	if err != nil {
		slog.Warn("Could not determine disk usage", "error", err)
	}

	spots := defaultHotspots()

	// Add any user-supplied directories.
	for _, dir := range cfg.extraDirs {
		spots = append(spots, hotspot{
			name: dir,
			path: dir,
		})
	}

	thresholdBytes := int64(cfg.thresholdMB) * 1024 * 1024
	slog.Debug("Scan settings", "threshold_mb", cfg.thresholdMB, "hotspots", len(spots))

	var results []scanResult
	for _, spot := range spots {
		resolved := resolvePath(spot.path, homeDir)

		slog.Debug("Scanning", "name", spot.name, "path", resolved)

		size, scanErr := scanner.DirSize(resolved)
		results = append(results, scanResult{
			name:      spot.name,
			path:      resolved,
			sizeBytes: size,
			err:       scanErr,
		})
	}

	// Filter to results that exceed the threshold and had no error.
	var reported []scanResult
	for _, r := range results {
		if r.err != nil {
			slog.Debug("Skipped (error)", "name", r.name, "path", r.path, "error", r.err)
			continue
		}
		if r.sizeBytes < thresholdBytes {
			slog.Debug("Below threshold", "name", r.name, "size", formatSize(r.sizeBytes))
			continue
		}
		reported = append(reported, r)
	}

	if len(reported) == 0 {
		fmt.Printf("No directories found exceeding %d MB.\n", cfg.thresholdMB)
		return nil
	}

	// Sort largest first.
	slices.SortFunc(reported, func(a, b scanResult) int {
		if a.sizeBytes > b.sizeBytes {
			return -1
		}
		if a.sizeBytes < b.sizeBytes {
			return 1
		}
		return 0
	})

	printResults(reported, diskInfo)
	return nil
}

// resolvePath replaces a leading ~ with the home directory.
func resolvePath(path, homeDir string) string {
	if strings.HasPrefix(path, "~/") {
		return filepath.Join(homeDir, path[2:])
	}
	if path == "~" {
		return homeDir
	}
	return path
}

// dirSize calculates the total size of a directory tree in bytes.
// Returns an error if the root directory does not exist.
func dirSize(path string) (int64, error) {
	info, err := os.Lstat(path)
	if err != nil {
		return 0, err
	}
	if !info.IsDir() {
		return info.Size(), nil
	}

	var total int64
	err = filepath.WalkDir(path, func(_ string, d fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			// Skip entries we can't read (permission denied, etc.)
			slog.Debug("Walk error, skipping", "error", walkErr)
			return nil
		}
		if !d.IsDir() {
			fi, fiErr := d.Info()
			if fiErr != nil {
				slog.Debug("Stat error, skipping", "error", fiErr)
				return nil
			}
			total += fi.Size()
		}
		return nil
	})
	return total, err
}

// formatSize converts a byte count into a human-readable string (KB, MB, GB).
func formatSize(bytes int64) string {
	const (
		kb = 1024
		mb = 1024 * kb
		gb = 1024 * mb
	)

	switch {
	case bytes >= gb:
		return fmt.Sprintf("%.2f GB", float64(bytes)/float64(gb))
	case bytes >= mb:
		return fmt.Sprintf("%.2f MB", float64(bytes)/float64(mb))
	case bytes >= kb:
		return fmt.Sprintf("%.2f KB", float64(bytes)/float64(kb))
	default:
		return fmt.Sprintf("%d B", bytes)
	}
}

// printResults outputs the scan results in a formatted table.
func printResults(results []scanResult, diskInfo diskUsageInfo) {
	// Find the longest name and path for alignment.
	maxName := 0
	maxPath := 0
	for _, r := range results {
		if len(r.name) > maxName {
			maxName = len(r.name)
		}
		if len(r.path) > maxPath {
			maxPath = len(r.path)
		}
	}

	lineWidth := maxName + 14 + maxPath + 4
	var totalBytes int64
	fmt.Println()
	fmt.Println(strings.Repeat("─", lineWidth))
	fmt.Printf("%-*s  %10s  %-*s\n", maxName, "DIRECTORY", "SIZE", maxPath, "PATH")
	fmt.Println(strings.Repeat("─", lineWidth))

	for _, r := range results {
		fmt.Printf("%-*s  %10s  %-*s\n", maxName, r.name, formatSize(r.sizeBytes), maxPath, r.path)
		totalBytes += r.sizeBytes
	}

	fmt.Println(strings.Repeat("─", lineWidth))
	fmt.Printf("%-*s  %10s\n", maxName, "TOTAL", formatSize(totalBytes))
	fmt.Println()

	// Print overall disk usage summary if available.
	if diskInfo.totalBytes > 0 {
		fmt.Printf("Disk Usage:  %s used / %s total (%.1f%%)\n",
			formatSize(int64(diskInfo.usedBytes)),
			formatSize(int64(diskInfo.totalBytes)),
			float64(diskInfo.usedBytes)/float64(diskInfo.totalBytes)*100,
		)
		fmt.Printf("Hotspots account for %s of %s used (%.1f%%)\n",
			formatSize(totalBytes),
			formatSize(int64(diskInfo.usedBytes)),
			float64(totalBytes)/float64(diskInfo.usedBytes)*100,
		)
		fmt.Println()
	}
}
