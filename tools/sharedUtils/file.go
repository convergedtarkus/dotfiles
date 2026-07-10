package sharedUtils

import "os"

func CloseFile(f *os.File) {
	if err := f.Close(); err != nil {
		panic("closing file: " + err.Error())
	}
}
