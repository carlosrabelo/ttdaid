package detector_test

import (
	"testing"

	"github.com/carlosrabelo/ttdaid/ttdaid/internal/detector"
)

func TestIsInstalledUnknownFalse(t *testing.T) {
	if detector.IsInstalled("no-such-component-zzzz") {
		t.Fatal("expected unknown component not installed")
	}
}
