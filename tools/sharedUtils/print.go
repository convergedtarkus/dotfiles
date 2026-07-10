package sharedUtils

import (
	"fmt"
	"io"
)

func Fprintf(w io.Writer, format string, a ...any) {
	_, err := fmt.Fprintf(w, format, a...)
	if err != nil {
		panic(fmt.Sprintf("Fprintf failed: %v", err))
	}
}
