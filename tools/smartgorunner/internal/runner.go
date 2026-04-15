package internal

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"sort"
	"strings"

	"dotfiles/tools/smartgorunner/internal/utils"
)

var ErrNoChangedGoFiles = errors.New("no changed go files found")

// Options represents the configuration options for running commands in modules based on changed files.
type Options struct {
	OnFiles bool
	Command []string
}

// Plan represents the execution plan for running commands in modules based on changed files.
type Plan struct {
	Items []PlanItem
}

// PlanItem represents a single command execution plan for a module, including the
// module directory and the inputs (files or directories) that should be passed to the command.
type PlanItem struct {
	ModuleDir string
	Inputs    []string
}

func Run(ctx context.Context, options Options) error {
	if len(options.Command) == 0 {
		return errors.New("command must be provided")
	}

	wd, err := os.Getwd()
	if err != nil {
		return fmt.Errorf("get working directory: %w", err)
	}
	workingDir := wd

	// Get the list of changed Go files in the working directory.
	changedFiles, err := utils.GetChangedGoFiles(ctx, workingDir)
	if err != nil {
		return err
	}
	if len(changedFiles) == 0 {
		return ErrNoChangedGoFiles
	}

	// Get the list of module directories in the working directory.
	moduleDirs, err := utils.GetModuleDirs(workingDir)
	if err != nil {
		return err
	}

	// Build the execution plan.
	plan, err := BuildPlan(changedFiles, moduleDirs, options.OnFiles)
	if err != nil {
		return err
	}

	// Run all the commands in the plan.
	for _, item := range plan.Items {
		joinedInputs := strings.Join(item.Inputs, " ")
		fmt.Fprintln(os.Stdout, "####")
		fmt.Fprintf(os.Stdout, "#### Running in module '%s' '%s %s'\n", item.ModuleDir, strings.Join(options.Command, " "), joinedInputs)
		fmt.Fprintln(os.Stdout, "####")

		modulePath := workingDir
		if item.ModuleDir != "." {
			modulePath = filepath.Join(workingDir, item.ModuleDir)
		}

		args := append(append([]string{}, options.Command[1:]...), item.Inputs...)
		cmd := exec.CommandContext(ctx, options.Command[0], args...)
		cmd.Dir = modulePath
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("run command in module %q: %w", item.ModuleDir, err)
		}
	}

	return nil
}

// BuildPlan creates a plan for running commands based on the inputs.
func BuildPlan(changedFiles []string, modDirs []string, onFiles bool) (Plan, error) {
	grouped, err := groupByModule(changedFiles, modDirs)
	if err != nil {
		return Plan{}, err
	}
	orderedModules := orderedModuleKeys(grouped)
	items := make([]PlanItem, 0, len(orderedModules))

	for _, modDir := range orderedModules {
		moduleFiles := grouped[modDir]
		inputs := moduleFiles
		if !onFiles {
			inputs = toDirectories(moduleFiles)
		}
		items = append(items, PlanItem{ModuleDir: modDir, Inputs: inputs})
	}

	return Plan{Items: items}, nil
}

// groupByModule takes a list of changed files and module directories, and groups
// the files by their corresponding module directory.
// Returns a map of module directory to the list of changed files within that module.
func groupByModule(changedFiles []string, modDirs []string) (map[string][]string, error) {
	out := make(map[string][]string, len(modDirs))
	for _, file := range changedFiles {
		assigned := false
		for _, modDir := range modDirs {
			if !fileInModule(file, modDir) {
				continue
			}
			moduleFile := toModuleRelativeFile(file, modDir)
			out[modDir] = append(out[modDir], moduleFile)
			assigned = true
			break
		}
		if !assigned {
			return nil, errors.New("file does not belong to any module: " + file)
		}
	}

	for modDir := range out {
		out[modDir] = utils.UniqueSorted(out[modDir])
	}
	return out, nil
}

// orderedModuleKeys takes the grouped module map and returns the module directories
// ordered by depth (deepest first) and then alphabetically.
// TODO (CF) I'm not 100% sure this ordering is required but some ordering is needed for consistent ordering.
func orderedModuleKeys(grouped map[string][]string) []string {
	keys := make([]string, 0, len(grouped))
	for key := range grouped {
		keys = append(keys, key)
	}
	sort.Slice(keys, func(i, j int) bool {
		depthI := strings.Count(keys[i], "/")
		depthJ := strings.Count(keys[j], "/")
		if depthI == depthJ {
			return keys[i] < keys[j]
		}
		return depthI > depthJ
	})
	return keys
}

// toDirectories converts a list of file paths to their corresponding directories,
// ensuring uniqueness and sorting.
func toDirectories(moduleFiles []string) []string {
	dirs := make([]string, 0, len(moduleFiles))
	for _, file := range moduleFiles {
		dirs = append(dirs, path.Dir(file))
	}
	return utils.UniqueSorted(dirs)
}

// fileInModule checks if the given file is within the module directory.
func fileInModule(file string, modDir string) bool {
	if modDir == "." {
		return true
	}
	return strings.HasPrefix(file, modDir+"/")
}

// Converts a file path to be relative to the module directory.
func toModuleRelativeFile(file string, modDir string) string {
	// TODO (CF) Lots of places that handle the period in a special manner, can that be better?
	if modDir == "." {
		return file
	}
	trimmed := strings.TrimPrefix(file, modDir+"/")
	if strings.HasPrefix(trimmed, "./") {
		return trimmed
	}
	return "./" + trimmed
}
