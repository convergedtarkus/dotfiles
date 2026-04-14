package utils

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
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
	for _, file := range changedFiles {
		// Trim whitespace and convert to slash format for consistency across platforms.
		normalized := filepath.ToSlash(strings.TrimSpace(file))
		if normalized == "" {
			continue
		}

		// Filter out any files in the vendor directory.
		if strings.HasPrefix(normalized, "vendor/") {
			continue
		}

		// Ensure the path starts with "./" for consistency with Go tool expectations.
		if !strings.HasPrefix(normalized, "./") {
			normalized = "./" + normalized
		}
		normalaizedFiles = append(normalaizedFiles, normalized)
	}
	return normalaizedFiles
}

// GetModuleDirs walks the working directory to find all directories containing a
// go.mod file, returning them in normalized form.
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
	set := make(map[string]struct{}, len(modDirs))
	// TODO (CF) I think some of this normalization is duplicated in the normalizedChangedFiles function.
	for _, dir := range modDirs {
		normalized := filepath.ToSlash(strings.TrimSpace(dir))
		if normalized == "" {
			continue
		}
		if normalized == "." || normalized == "./" {
			normalized = "."
		} else if !strings.HasPrefix(normalized, "./") {
			normalized = "./" + strings.TrimPrefix(normalized, "./")
		}
		set[normalized] = struct{}{}
	}

	// Convert set back to slice.
	out := make([]string, 0, len(set))
	for dir := range set {
		out = append(out, dir)
	}

	// Sort by depth (deepest first) and then alphabetically to ensure submodules
	// are processed before parent modules.
	sort.Slice(out, func(i, j int) bool {
		depthI := strings.Count(out[i], "/")
		depthJ := strings.Count(out[j], "/")
		if depthI == depthJ {
			return out[i] < out[j]
		}
		return depthI > depthJ
	})
	return out
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
