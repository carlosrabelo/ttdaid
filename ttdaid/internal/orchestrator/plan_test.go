package orchestrator_test

import (
	"testing"

	"github.com/carlosrabelo/ttdaid/ttdaid/internal/orchestrator"
)

func TestSplitActions(t *testing.T) {
	actions := [][2]string{
		{"a", "install"},
		{"b", "uninstall"},
		{"c", "install"},
	}
	ins, rem := orchestrator.SplitActions(actions)
	if len(ins) != 2 || ins[0] != "a" || ins[1] != "c" {
		t.Fatalf("installs: %v", ins)
	}
	if len(rem) != 1 || rem[0] != "b" {
		t.Fatalf("removes: %v", rem)
	}
}
