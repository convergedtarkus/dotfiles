package main

import (
	"context"
	"flag"
	"fmt"
	"os"

	"dotfiles/tools/smartgorunner/internal"
)

// Main entry point for the smartgorunner command line tool.
func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "smartgorunner error: %v\n", err)
		os.Exit(1)
	}
}

// run is the main helper for the smartgorunner command line tool.
func run() error {
	// TODO (CF) I believe this can be removed.
	var onFiles bool
	flag.BoolVar(&onFiles, "on-files", false, "run command on changed files instead of changed directories")
	flag.Parse()

	command := flag.Args()
	if len(command) == 0 {
		return fmt.Errorf("missing command (example: smartgorunner --on-files gofmt -w)")
	}

	return internal.Run(context.Background(), internal.Options{
		OnFiles: onFiles,
		Command: command,
	})
}
