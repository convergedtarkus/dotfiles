package sharedUtils

import (
	"context"
	"log/slog"
	"os"
	"strings"
)

// Verify that MinimalHandler implements slog.Handler.
var _ slog.Handler = (*MinimalHandler)(nil)

// MinimalHandler is a slog.Handler that outputs only the message and
// key=value attributes, without timestamp or level prefixes.
type MinimalHandler struct {
	level slog.Leveler
}

func NewMinimalHandlerLogger(level slog.Leveler) *slog.Logger {
	return slog.New(&MinimalHandler{level: level})
}

func (h *MinimalHandler) Enabled(_ context.Context, level slog.Level) bool {
	return level >= h.level.Level()
}

func (h *MinimalHandler) Handle(_ context.Context, r slog.Record) error {
	var b strings.Builder
	b.WriteString(r.Message)

	r.Attrs(func(a slog.Attr) bool {
		Fprintf(&b, " %s=%s", a.Key, a.Value.String())
		return true
	})

	b.WriteByte('\n')
	_, err := os.Stderr.WriteString(b.String())
	return err
}

func (h *MinimalHandler) WithAttrs(_ []slog.Attr) slog.Handler { return h }
func (h *MinimalHandler) WithGroup(_ string) slog.Handler      { return h }
