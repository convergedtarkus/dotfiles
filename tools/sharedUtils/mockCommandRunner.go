package sharedUtils

import (
	"io"
	"testing"

	"github.com/stretchr/testify/mock"
)

func NewMockRunner(t *testing.T) *MockRunner {
	mockRunner := &MockRunner{}
	t.Cleanup(func() {
		mockRunner.AssertExpectations(t)
	})
	return mockRunner
}

type MockRunner struct {
	mock.Mock
}

func (m *MockRunner) Output(name string, args ...string) ([]byte, error) {
	mockArgs := m.Called(name, args)
	return mockArgs.Get(0).([]byte), mockArgs.Error(1)
}

func (m *MockRunner) Run(stdout, stderr io.Writer, name string, args ...string) error {
	mockArgs := m.Called(stdout, stderr, name, args)
	return mockArgs.Error(0)
}
