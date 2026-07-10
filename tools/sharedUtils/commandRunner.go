package sharedUtils

import (
	"io"
	"os/exec"
)

// CommandRunner abstracts the execution of external commands for testability.
type CommandRunner interface {
	// Output runs the command and returns its stdout.
	Output(name string, args ...string) ([]byte, error)
	// Run runs the command with stdout/stderr connected to the given writers.
	Run(stdout, stderr io.Writer, name string, args ...string) error
}

// ExecRunner is the real/production implementation of CommandRunner using os/exec.
type ExecRunner struct{}

func (e ExecRunner) Output(name string, args ...string) ([]byte, error) {
	return exec.Command(name, args...).Output()
}

func (e ExecRunner) Run(stdout, stderr io.Writer, name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	return cmd.Run()
}
