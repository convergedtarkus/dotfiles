package internal

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"

	"dotfiles/tools/smartgorunner/internal/utils"
)

var errNoChangedGoFiles = errors.New("no changed go files found")

// Options represents the configuration options for running commands in modules based on changed files.
type Options struct {
	OnFiles bool
	Command []string
}

// plan represents the execution plan for running commands in modules based on changed files.
type plan struct {
	Items []planItem
}

// planItem represents a single command execution plan for a module, including the
// module directory and the inputs (files or directories) that should be passed to the command.
type planItem struct {
	ModuleDir string
	Inputs    []string
}

type runnerDeps struct {
	getWorkingDir   func() (string, error)
	getChangedFiles func(context.Context, string) ([]string, error)
	getModuleDirs   func(string) ([]string, error)
	runCommand      func(context.Context, string, string, []string) error
}

// defaultRunnerDeps returns production dependencies for Run.
func defaultRunnerDeps() runnerDeps {
	return runnerDeps{
		getWorkingDir:   os.Getwd,
		getChangedFiles: utils.GetChangedGoFiles,
		getModuleDirs:   utils.GetModuleDirs,
		runCommand:      runCommand,
	}
}

// runCommand executes a command inside a module and streams output to stdout/stderr.
func runCommand(ctx context.Context, modulePath string, command string, args []string) error {
	cmd := exec.CommandContext(ctx, command, args...)
	cmd.Dir = modulePath
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// Run executes the configured command against changed files or directories grouped by module.
func Run(ctx context.Context, options Options) error {
	return runWithDeps(ctx, options, defaultRunnerDeps())
}

// runWithDeps executes Run using injected dependencies for testing.
func runWithDeps(ctx context.Context, options Options, deps runnerDeps) error {
	if len(options.Command) == 0 {
		return errors.New("command must be provided")
	}

	wd, err := deps.getWorkingDir()
	if err != nil {
		return fmt.Errorf("get working directory: %w", err)
	}
	workingDir := wd

	// Get the list of changed Go files in the working directory.
	changedFiles, err := deps.getChangedFiles(ctx, workingDir)
	if err != nil {
		return err
	}
	if len(changedFiles) == 0 {
		return errNoChangedGoFiles
	}

	// Get the list of module directories in the working directory.
	moduleDirs, err := deps.getModuleDirs(workingDir)
	if err != nil {
		return err
	}

	// Build the execution plan.
	planToRun, err := buildPlan(changedFiles, moduleDirs, options.OnFiles)
	if err != nil {
		return err
	}

	// Run all the commands in the plan.
	for _, item := range planToRun.Items {
		joinedInputs := strings.Join(item.Inputs, " ")
		fmt.Fprintln(os.Stdout, "####")
		fmt.Fprintf(os.Stdout, "#### Running in module '%s' '%s %s'\n", item.ModuleDir, strings.Join(options.Command, " "), joinedInputs)
		fmt.Fprintln(os.Stdout, "####")

		modulePath := workingDir
		if item.ModuleDir != "." {
			modulePath = filepath.Join(workingDir, item.ModuleDir)
		}

		args := append(append([]string{}, options.Command[1:]...), item.Inputs...)
		if err := deps.runCommand(ctx, modulePath, options.Command[0], args); err != nil {
			return fmt.Errorf("run command in module %q: %w", item.ModuleDir, err)
		}
	}

	return nil
}

// buildPlan creates a plan for running commands based on the inputs.
func buildPlan(changedFiles []string, modDirs []string, onFiles bool) (plan, error) {
	grouped, err := groupByModule(changedFiles, modDirs)
	if err != nil {
		return plan{}, err
	}
	items := make([]planItem, 0, len(modDirs))

	for _, modDir := range modDirs {
		moduleFiles := grouped[modDir]
		if len(moduleFiles) == 0 {
			continue
		}

		inputs := moduleFiles
		if !onFiles {
			inputs = toDirectories(moduleFiles)
		}
		items = append(items, planItem{ModuleDir: modDir, Inputs: inputs})
	}

	return plan{Items: items}, nil
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

// toDirectories converts a list of file paths to their corresponding directories,
// ensuring uniqueness and sorting.
func toDirectories(moduleFiles []string) []string {
	dirs := make([]string, 0, len(moduleFiles))
	for _, file := range moduleFiles {
		dirs = append(dirs, normalizeDirectoryArg(path.Dir(file)))
	}
	return utils.UniqueSorted(dirs)
}

// normalizeDirectoryArg ensures command directory args are dot-slash relative.
func normalizeDirectoryArg(dir string) string {
	if dir == "." || dir == "./" {
		return "./"
	}
	if strings.HasPrefix(dir, "./") {
		return dir
	}
	return "./" + dir
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
	if modDir == "." {
		return file
	}
	trimmed := strings.TrimPrefix(file, modDir+"/")
	if strings.HasPrefix(trimmed, "./") {
		return trimmed
	}
	return "./" + trimmed
}
