package detector_test

import (
	"testing"

	"github.com/carlosrabelo/ttdaid/ttdaid/internal/detector"
)

func TestDetectInstalledEmpty(t *testing.T) {
	got := detector.DetectInstalled(nil)
	if len(got) != 0 {
		t.Fatalf("got %v", got)
	}
}

func TestDetectInstalledUnknownFallback(t *testing.T) {
	// Unknown components fall back to which(<last-segment>).
	// A nonsense name should report false without panicking.
	if detector.IsInstalled("zz-no-such-binary-xyzzy") {
		t.Fatal("expected unknown component to be absent")
	}
}
