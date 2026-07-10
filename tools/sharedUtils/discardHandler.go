package sharedUtils

import (
	"context"
	"log"
	"log/slog"
	"testing"
)

// Verify that DiscardHandler implements slog.Handler.
var _ slog.Handler = (*DiscardHandler)(nil)

// DiscardHandler is a slog.Handler outputs nothing.
type DiscardHandler struct{}

// NewDiscardHandlerLoggerRestoreAfterTest creates a new slog.Logger with a DiscardHandler and sets it as the default logger.
// It also registers a cleanup function to restore the previous default logger and log output after the test completes.
func NewDiscardHandlerLoggerRestoreAfterTest(t *testing.T) *slog.Logger {
	previousDefault := slog.Default()
	// Save log.Default() writer and flags because slog.SetDefault with
	// a *defaultHandler does not restore them (it skips log.SetOutput
	// to avoid a deadlock), leaving log output pointed at the discard
	// handler's writer.
	previousLogOutput := log.Default().Writer()
	previousLogFlags := log.Flags()
	t.Cleanup(func() {
		slog.SetDefault(previousDefault)
		log.SetOutput(previousLogOutput)
		log.SetFlags(previousLogFlags)
	})
	logger := slog.New(&DiscardHandler{})
	slog.SetDefault(logger)
	return logger
}

func (h *DiscardHandler) Enabled(_ context.Context, _ slog.Level) bool {
	return false
}

func (h *DiscardHandler) Handle(_ context.Context, _ slog.Record) error {
	return nil
}

func (h *DiscardHandler) WithAttrs(_ []slog.Attr) slog.Handler { return h }
func (h *DiscardHandler) WithGroup(_ string) slog.Handler      { return h }
