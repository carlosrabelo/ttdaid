package orchestrator_test

import (
	"strings"
	"testing"

	"github.com/carlosrabelo/ttdaid/ttdaid/internal/catalog"
	"github.com/carlosrabelo/ttdaid/ttdaid/internal/orchestrator"
	"github.com/carlosrabelo/ttdaid/ttdaid/internal/rootfs"
)

func TestApplyDryRun(t *testing.T) {
	root, err := rootfs.Resolve()
	if err != nil {
		t.Fatal(err)
	}
	comps, err := catalog.DiscoverComponents(root, "debian", "trixie")
	if err != nil {
		t.Fatal(err)
	}
	if len(comps) == 0 {
		t.Fatal("no components discovered")
	}
	scope := []string{comps[0]}
	var buf strings.Builder
	code := orchestrator.Apply(orchestrator.ApplyOptions{
		Distro:      "debian",
		Release:     "trixie",
		Desired:     map[string]struct{}{},
		Scope:       scope,
		DryRun:      true,
		SkipOSCheck: true,
		RepoRoot:    root,
		UseSudo:     false,
	}, func(line string) { buf.WriteString(line) }, nil)
	if code != 0 {
		t.Fatalf("dry-run exit %d\n%s", code, buf.String())
	}
	out := buf.String()
	if !strings.Contains(out, "Dry-run") && !strings.Contains(out, "dry-run") && !strings.Contains(out, "Already in sync") && !strings.Contains(out, "Will uninstall") {
		t.Fatalf("unexpected output:\n%s", out)
	}
	if !strings.Contains(out, "system-bash") {
		t.Fatalf("expected always-run system-bash in output:\n%s", out)
	}
}
