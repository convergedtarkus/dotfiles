package utils

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

// GetChangedGoFiles returns the list of changed go files relative to the working directory, excluding deleted files and vendor directory.
func GetChangedGoFiles(ctx context.Context, workingDir string) ([]string, error) {
	// Get .go files only regardless of index or working tree excluding deleted files.
	// The --relative flag returns paths relative to the current path, allowing running in sub-directories.
	// Use grep to remove any entries from the vendor directory as these should never be touched.
	// Add './' to the start of each line as go test (and others) require it.
	// This also allows for correct handling of test files at the current directory level.
	cmd := exec.CommandContext(ctx, "git", "diff", "HEAD", "--relative", "--name-only", "--diff-filter=d", "--", "*.go")
	cmd.Dir = workingDir
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("list changed go files: %w", err)
	}
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) <= 1 && lines[0] == "" {
		return nil, nil
	}

	return normalizeChangedFiles(lines), nil
}

// normalizeChangedFiles normalizes the changed file paths by trimming whitespace,
// converting to slash format, and ensuring they start with "./". It also filters
// out any files in the vendor directory.
func normalizeChangedFiles(changedFiles []string) []string {
	normalaizedFiles := make([]string, 0, len(changedFiles))
	for _, file := range normalFileStrings(changedFiles) {
		// Filter out any files in the vendor directory.
		regexpedFile := regexp.MustCompile(`^\.?/?vendor/`)
		if regexpedFile.MatchString(file) {
			continue
		}
		normalaizedFiles = append(normalaizedFiles, file)
	}
	return normalaizedFiles
}

// normalFileStrings normalizes file or directory paths by trimming whitespace,
// converting to slash format, ensuring they start with "./", and removing duplicates.
func normalFileStrings(filePaths []string) []string {
	set := make(map[string]struct{}, len(filePaths))
	for _, file := range filePaths {
		// Trim whitespace and convert to slash format for consistency across platforms.
		normalized := filepath.ToSlash(strings.TrimSpace(file))
		if normalized == "" {
			continue
		}

		if normalized == "." || normalized == "./" {
			normalized = "."
		} else if !strings.HasPrefix(normalized, "./") {
			// Ensure the path starts with "./" for consistency with Go tool expectations.
			normalized = "./" + normalized
		}

		set[normalized] = struct{}{}
	}

	// Convert set back to slice.
	out := make([]string, 0, len(set))
	for dir := range set {
		out = append(out, dir)
	}

	return out
}

// GetModuleDirs walks the working directory to find all directories containing a
// go.mod file, returning them in normalized form.
// The returned module directories are ordered by depth (deepest first) and then
// alphabetically,
func GetModuleDirs(workingDir string) ([]string, error) {
	var foundModDirs []string
	err := filepath.WalkDir(workingDir, func(filePath string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() {
			// Completely skip vendor directories and hidden directories.
			if entry.Name() == "vendor" || strings.HasPrefix(entry.Name(), ".") {
				return filepath.SkipDir
			}
			return nil
		}
		if entry.Name() != "go.mod" {
			return nil
		}

		rel, err := filepath.Rel(workingDir, filepath.Dir(filePath))
		if err != nil {
			return err
		}

		if rel == "." {
			foundModDirs = append(foundModDirs, ".")
		} else {
			foundModDirs = append(foundModDirs, filepath.ToSlash(filepath.Join(".", rel)))
		}
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("find go.mod files: %w", err)
	}

	return normalizeModDirs(foundModDirs), nil
}

// normalizeModDirs normalizes the module directories by trimming whitespace, converting
// to slash format, ensuring they start with "./", and removing duplicates.
// It also sorts the directories by depth (deepest first) and then alphabetically
// to ensure submodules are processed before parent modules.
func normalizeModDirs(modDirs []string) []string {
	cleanedModDirs := normalFileStrings(modDirs)

	orderModuleDirectories(cleanedModDirs)
	return cleanedModDirs
}

// orderModuleDirectories sorts the module directories by depth (deepest first) and
// then alphabetically to ensure submodules are processed before parent modules.
func orderModuleDirectories(cleanedModDirs []string) {
	// Sort by depth (deepest first) and then alphabetically to ensure submodules
	// are processed before parent modules.
	sort.Slice(cleanedModDirs, func(i, j int) bool {
		depthI := strings.Count(cleanedModDirs[i], "/")
		depthJ := strings.Count(cleanedModDirs[j], "/")
		if depthI == depthJ {
			return cleanedModDirs[i] < cleanedModDirs[j]
		}
		return depthI > depthJ
	})
}

// UniqueSorted returns a sorted slice of unique strings from the input slice.
func UniqueSorted(input []string) []string {
	set := make(map[string]struct{}, len(input))
	for _, value := range input {
		set[value] = struct{}{}
	}
	out := make([]string, 0, len(set))
	for value := range set {
		out = append(out, value)
	}
	sort.Strings(out)
	return out
}
