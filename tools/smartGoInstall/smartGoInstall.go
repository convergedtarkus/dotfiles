package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"os"
	"regexp"
	"slices"
	"strings"

	"github.com/convergedtarkus/randomUtils/sharedUtils"
)

// commandConfig holds the parsed command-line configuration.
type commandConfig struct {
	installLatest    bool
	packageToInstall string
	printVersionOnly bool
	verbose          bool
}

func main() {
	// Parse command-line flags into a commandConfig struct.
	cfg, err := parseFlags(os.Args[1:], os.Stderr)
	if err != nil {
		if errors.Is(err, flag.ErrHelp) {
			os.Exit(0)
		}
		slog.Error("invalid arguments", "error", err)
		os.Exit(1)
	}

	// Set up logging with the appropriate level based on the verbose flag.
	logLevel := slog.LevelInfo
	if cfg.verbose {
		logLevel = slog.LevelDebug
	}
	slog.SetDefault(sharedUtils.NewMinimalHandlerLogger(logLevel))

	if err := run(cfg, sharedUtils.ExecRunner{}); err != nil {
		slog.Error("fatal error", "error", err)
		os.Exit(1)
	}
}

// parseFlags parses command-line arguments into a commandConfig struct.
func parseFlags(args []string, output io.Writer) (commandConfig, error) {
	// TODO Flags must be before the package path, but it would be nice to allow them after as well.
	fs := flag.NewFlagSet("smartGoInstall", flag.ContinueOnError)
	fs.SetOutput(output)
	fs.Usage = func() {
		// Define the usage message.
		sharedUtils.Fprintf(fs.Output(), "Usage: smartGoInstall [flags] <package-path>\n\n")
		sharedUtils.Fprintf(fs.Output(), "Installs a Go package at the newest version compatible with the current Go toolchain.\n\n")
		sharedUtils.Fprintf(fs.Output(), "Example:\n  smartGoInstall github.com/golangci/golangci-lint/cmd/golangci-lint\n\n")
		sharedUtils.Fprintf(fs.Output(), "Flags:\n")
		fs.PrintDefaults()
		sharedUtils.Fprintf(fs.Output(), "\nIf --install-latest is not provided, the command will fail when it cannot determine a compatible version.\n")
	}

	// -l / --install-latest: fall back to installing the latest version when no
	// compatible version is found or cannot be determined.
	var cfg commandConfig
	fs.BoolVar(&cfg.installLatest, "install-latest", false, "install latest version if no compatible version is found")
	fs.BoolVar(&cfg.installLatest, "l", false, "shorthand for --install-latest")

	// -p / --print-version-only: print the version that would be installed and exit
	// without actually installing it.
	fs.BoolVar(&cfg.printVersionOnly, "print-version-only", false, "print the compatible version without installing")
	fs.BoolVar(&cfg.printVersionOnly, "p", false, "shorthand for --print-version-only")

	// -v / --verbose: enable debug-level logging for version checking details
	fs.BoolVar(&cfg.verbose, "verbose", false, "enable verbose output")
	fs.BoolVar(&cfg.verbose, "v", false, "shorthand for --verbose")

	// Parse the args.
	if err := fs.Parse(args); err != nil {
		// The err should be a flag.ErrHelp which will just terminate the program..
		return commandConfig{}, err
	}

	// Require exactly one non-flag argument: the package path.
	if fs.NArg() == 0 {
		fs.Usage()
		return commandConfig{}, fmt.Errorf("missing required argument: package-path")
	}
	if fs.NArg() > 1 {
		fs.Usage()
		return commandConfig{}, fmt.Errorf("too many arguments: only one package-path is allowed")
	}

	// Set the package path from the first non-flag argument.
	cfg.packageToInstall = fs.Arg(0)
	return cfg, nil
}

// run contains the main application logic, returning an error instead of
// calling os.Exit so that deferred functions run and the caller controls exit.
func run(cfg commandConfig, runner sharedUtils.CommandRunner) error {
	// Extract the module path (without /cmd/... suffix)
	modulePath := extractModulePath(cfg.packageToInstall)

	// Get the current Go version (major.minor) to compare against module requirements.
	systemGoVersion, err := getSystemGoVersion(runner)
	if err != nil {
		return fmt.Errorf("getting current Go version: %w", err)
	}

	if !cfg.printVersionOnly {
		slog.Info("Detected system Go version", "version", systemGoVersion)
		slog.Info("Finding compatible version", "module", modulePath)
	}

	// Get all available versions of the module.
	versions, err := getModuleGoVersions(runner, modulePath)
	if err != nil {
		return fmt.Errorf("getting module versions: %w", err)
	}
	if len(versions) == 0 {
		slog.Warn("Did not find any versions of the pacakge", "module", modulePath, "error", err)
		return installLatestOrFail(cfg, runner)
	}

	// Try each version from newest to oldest
	for _, version := range versions {
		slog.Debug("Checking version", "version", version)

		packageRequiredGo, err := getRequiredGoVersionForPackage(runner, modulePath, version)
		if err != nil {
			slog.Debug("Could not determine required Go version for this module version; skipping", "version", version, "error", err)
			continue
		}

		slog.Debug("Version requires Go", "version", version, "packageRequiredGo", packageRequiredGo)

		if compareVersionsLE(packageRequiredGo, systemGoVersion) {
			if cfg.printVersionOnly {
				fmt.Println(version)
				return nil
			}
			slog.Info("Compatible version found", "version", version)
			return runGoInstall(runner, cfg.packageToInstall, version)
		}
	}

	return installLatestOrFail(cfg, runner)
}

// extractModulePath strips any /cmd/... suffix from a package path to get the module root.
func extractModulePath(packagePath string) string {
	if idx := strings.Index(packagePath, "/cmd/"); idx != -1 {
		return packagePath[:idx]
	}
	return packagePath
}

// getSystemGoVersion runs "go version" and extracts the major.minor version string.
func getSystemGoVersion(runner sharedUtils.CommandRunner) (semverVersion, error) {
	out, err := runner.Output("go", "version")
	if err != nil {
		return semverVersion{}, fmt.Errorf("running 'go version': %w", err)
	}

	re := regexp.MustCompile(`go(\d+\.\d+)`)
	matches := re.FindStringSubmatch(string(out))
	if len(matches) < 2 {
		return semverVersion{}, fmt.Errorf("could not parse Go version from: %s", string(out))
	}
	return parseVersion(matches[1])
}

// getModuleGoVersions runs "go list -m -versions" to get all available versions of a module.
// It returns a slice of version strings (e.g. ["1.21.0", "1.20.5", ...]) sorted from newest to oldest.
//
// Flags used:
//   - -mod=readonly: prevent go from modifying go.mod
//   - -m: list modules instead of packages
//   - -versions: show all available versions
func getModuleGoVersions(runner sharedUtils.CommandRunner, modulePath string) ([]string, error) {
	out, err := runner.Output("go", "list", "-mod=readonly", "-m", "-versions", modulePath)
	if err != nil {
		return nil, fmt.Errorf("running 'go list -m -versions': %w", err)
	}

	fields := strings.Fields(string(out))
	if len(fields) <= 1 {
		// First field is the module path itself; if nothing else, no versions found
		return nil, nil
	}
	// Skip the first field (module path) and return the rest as version tags
	versions := fields[1:]

	// Reverse versions so newest is first. Go list -versions orders them from oldest to newest.
	slices.Reverse(versions)
	return versions, nil
}

type modDownloadResult struct {
	GoMod string `json:"GoMod"`
}

// getRequiredGoVersionForPackage downloads the module at a given version and reads the
// required Go version from its go.mod file.
//
// Flags used:
//   - -json: output download result as JSON (includes the GoMod file path)
func getRequiredGoVersionForPackage(runner sharedUtils.CommandRunner, modulePath, version string) (semverVersion, error) {
	out, err := runner.Output("go", "mod", "download", "-json", modulePath+"@"+version)
	if err != nil {
		return semverVersion{}, fmt.Errorf("running 'go mod download -json': %w", err)
	}

	var result modDownloadResult
	if err := json.Unmarshal(out, &result); err != nil {
		return semverVersion{}, fmt.Errorf("parsing JSON from 'go mod download': %w", err)
	}

	if result.GoMod == "" {
		return semverVersion{}, fmt.Errorf("no GoMod path in download result")
	}

	return parseGoVersionFromMod(result.GoMod)
}

// parseGoVersionFromMod reads a go.mod file and extracts the "go X.Y" directive.
func parseGoVersionFromMod(path string) (semverVersion, error) {
	f, err := os.Open(path)
	if err != nil {
		return semverVersion{}, fmt.Errorf("opening go.mod at %s: %w", path, err)
	}
	defer sharedUtils.CloseFile(f)

	re := regexp.MustCompile(`^go\s+(\d+\.\d+)`)
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		matches := re.FindStringSubmatch(scanner.Text())
		if len(matches) >= 2 {
			return parseVersion(matches[1])
		}
	}
	if err := scanner.Err(); err != nil {
		return semverVersion{}, fmt.Errorf("reading go.mod at %s: %w", path, err)
	}
	return semverVersion{}, fmt.Errorf("no 'go' directive found in go.mod at %s", path)
}

// installLatestOrFail installs the latest version if --install-latest was provided.
// If not, it logs a warning and does not error.
func installLatestOrFail(cfg commandConfig, runner sharedUtils.CommandRunner) error {
	if cfg.installLatest {
		if cfg.printVersionOnly {
			fmt.Println("latest")
			return nil
		}
		slog.Info("Installing latest version (--install-latest was provided)")
		return runGoInstall(runner, cfg.packageToInstall, "latest")
	}
	slog.Info("no compatible version found; run with --install-latest (-l) to install latest despite incompatibility")
	return errors.New("no compatible version found")
}

// runGoInstall executes "go install <package>@<version>".
func runGoInstall(runner sharedUtils.CommandRunner, pkg, version string) error {
	slog.Info("Running go install", "package", pkg, "version", version)
	if err := runner.Run(os.Stdout, os.Stderr, "go", "install", pkg+"@"+version); err != nil {
		return fmt.Errorf("go install %s@%s failed: %w", pkg, version, err)
	}
	return nil
}
