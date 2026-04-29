package internal

import (
	"context"
	"errors"
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type runCommandCall struct {
	modulePath string
	command    string
	args       []string
}

// assertPlanEqual compares plans with field-level assertions to provide granular failure messages.
func assertPlanEqual(t *testing.T, expectedPlan plan, actualPlan plan) {
	t.Helper()

	require.Len(t, actualPlan.Items, len(expectedPlan.Items), "plan item count should match")
	for itemIndex, expectedItem := range expectedPlan.Items {
		actualItem := actualPlan.Items[itemIndex]
		assert.Equal(t, expectedItem.ModuleDir, actualItem.ModuleDir, "plan item %d module dir should match", itemIndex)
		assert.Equal(t, expectedItem.Inputs, actualItem.Inputs, "plan item %d inputs should match", itemIndex)
	}
}

// TestBuildPlan verifies buildPlan produces expected inputs for file and directory modes.
func TestBuildPlan(t *testing.T) {
	testCases := []struct {
		name          string
		onFiles       bool
		expectedItems []planItem
	}{
		{
			name:    "on files keeps file paths",
			onFiles: true,
			expectedItems: []planItem{
				{ModuleDir: "./submodule", Inputs: []string{"./pkg/arbiter.go", "./pkg/icarus_test.go"}},
				{ModuleDir: ".", Inputs: []string{"./api/shepard.go"}},
			},
		},
		{
			name:    "on directories normalizes to dot slash directories",
			onFiles: false,
			expectedItems: []planItem{
				{ModuleDir: "./submodule", Inputs: []string{"./pkg"}},
				{ModuleDir: ".", Inputs: []string{"./api"}},
			},
		},
	}

	changedFiles := []string{"./submodule/pkg/arbiter.go", "./api/shepard.go", "./submodule/pkg/icarus_test.go"}
	moduleDirs := []string{"./submodule", ".", "./othermodule"}

	for _, testCase := range testCases {
		t.Run(testCase.name, func(t *testing.T) {
			actualPlan, err := buildPlan(changedFiles, moduleDirs, testCase.onFiles)
			require.NoError(t, err, "BuildPlan should not error")

			expectedPlan := plan{Items: testCase.expectedItems}
			assertPlanEqual(t, expectedPlan, actualPlan)
		})
	}
}

// TestBuildPlanReturnsErrorWhenFileHasNoModule verifies buildPlan fails for unassigned files.
func TestBuildPlanReturnsErrorWhenFileHasNoModule(t *testing.T) {
	changedFiles := []string{"./api/zenith.go"}
	moduleDirs := []string{"./submodule"}

	_, err := buildPlan(changedFiles, moduleDirs, true)
	require.Error(t, err)
	assert.ErrorContains(t, err, "file does not belong to any module")
}

// TestRunWithDepsReturnsErrorWhenCommandMissing verifies Run rejects empty command input.
func TestRunWithDepsReturnsErrorWhenCommandMissing(t *testing.T) {
	actualErr := runWithDeps(context.Background(), Options{}, runnerDeps{})
	require.Error(t, actualErr)
	assert.EqualError(t, actualErr, "command must be provided")
}

// TestRunWithDepsReturnsErrNoChangedGoFiles verifies Run returns errNoChangedGoFiles when no files are changed.
func TestRunWithDepsReturnsErrNoChangedGoFiles(t *testing.T) {
	deps := runnerDeps{
		getWorkingDir: func() (string, error) {
			return "/workspace/dotfiles", nil
		},
		getChangedFiles: func(context.Context, string) ([]string, error) {
			return nil, nil
		},
		getModuleDirs: func(string) ([]string, error) {
			return []string{"."}, nil
		},
		runCommand: func(context.Context, string, string, []string) error {
			return nil
		},
	}

	actualErr := runWithDeps(context.Background(), Options{Command: []string{"go", "test"}}, deps)
	require.Error(t, actualErr)
	assert.ErrorIs(t, actualErr, errNoChangedGoFiles)
}

// TestRunWithDepsRunsCommandsForEachModule verifies Run builds and executes module-scoped commands without executing real binaries.
func TestRunWithDepsRunsCommandsForEachModule(t *testing.T) {
	actualCalls := make([]runCommandCall, 0)
	deps := runnerDeps{
		getWorkingDir: func() (string, error) {
			return "/workspace/dotfiles", nil
		},
		getChangedFiles: func(context.Context, string) ([]string, error) {
			return []string{"./submodule/pkg/samus.go", "./api/doomguy.go"}, nil
		},
		getModuleDirs: func(string) ([]string, error) {
			return []string{"./submodule", "."}, nil
		},
		runCommand: func(_ context.Context, modulePath string, command string, args []string) error {
			actualCalls = append(actualCalls, runCommandCall{modulePath: modulePath, command: command, args: append([]string{}, args...)})
			return nil
		},
	}

	actualErr := runWithDeps(context.Background(), Options{Command: []string{"go", "test"}}, deps)
	require.NoError(t, actualErr, "runWithDeps should not error")

	expectedCalls := []runCommandCall{
		{modulePath: "/workspace/dotfiles/submodule", command: "go", args: []string{"test", "./pkg"}},
		{modulePath: "/workspace/dotfiles", command: "go", args: []string{"test", "./api"}},
	}
	assert.Equal(t, expectedCalls, actualCalls)
}

// TestRunWithDepsStopsWhenCommandFails verifies Run returns an error as soon as command execution fails.
func TestRunWithDepsStopsWhenCommandFails(t *testing.T) {
	actualCallCount := 0
	deps := runnerDeps{
		getWorkingDir: func() (string, error) {
			return "/workspace/dotfiles", nil
		},
		getChangedFiles: func(context.Context, string) ([]string, error) {
			return []string{"./submodule/pkg/commander.go", "./api/cortana.go"}, nil
		},
		getModuleDirs: func(string) ([]string, error) {
			return []string{"./submodule", "."}, nil
		},
		runCommand: func(_ context.Context, modulePath string, _ string, _ []string) error {
			actualCallCount++
			return fmt.Errorf("module %s failed: %w", modulePath, errors.New("kaboom"))
		},
	}

	actualErr := runWithDeps(context.Background(), Options{Command: []string{"go", "test"}}, deps)
	require.Error(t, actualErr)
	assert.ErrorContains(t, actualErr, "run command in module \"./submodule\"")
	assert.Equal(t, 1, actualCallCount)
}
