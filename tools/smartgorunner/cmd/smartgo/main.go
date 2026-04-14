package main

import (
	"context"
	"flag"
	"fmt"
	"os"

	"dotfiles/tools/smartgo/internal/smartrunner"
)

// Main entry point for the smartgo command line tool.
func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "smartgo error: %v\n", err)
		os.Exit(1)
	}
}

// run is the main helper for the smartgo command line tool.
func run() error {
	// TODO (CF) I believe this can be removed.
	var onFiles bool
	flag.BoolVar(&onFiles, "on-files", false, "run command on changed files instead of changed directories")
	flag.Parse()

	command := flag.Args()
	if len(command) == 0 {
		return fmt.Errorf("missing command (example: smartgo --on-files gofmt -w)")
	}

	return smartrunner.Run(context.Background(), smartrunner.Options{
		OnFiles: onFiles,
		Command: command,
	})
}
