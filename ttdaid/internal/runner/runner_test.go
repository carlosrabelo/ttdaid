package runner_test

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/carlosrabelo/ttdaid/ttdaid/internal/runner"
)

func TestComponentScript(t *testing.T) {
	got := runner.ComponentScript("/repo", "debian", "trixie", "containers-docker")
	want := filepath.Join("/repo", "distros", "debian", "trixie", "scripts", "containers-docker.sh")
	if got != want {
		t.Fatalf("got %q want %q", got, want)
	}
}

func TestRunComponentMissingScript(t *testing.T) {
	var buf strings.Builder
	code := runner.RunComponent(context.Background(), "/nonexistent", "debian", "trixie",
		"no-such-component", "install", true, false, func(line string) { buf.WriteString(line) })
	if code != 1 {
		t.Fatalf("exit %d, want 1; out=%s", code, buf.String())
	}
	if !strings.Contains(buf.String(), "Script not found") {
		t.Fatalf("expected not-found message: %s", buf.String())
	}
}

func TestRunComponentCancelled(t *testing.T) {
	root := t.TempDir()
	scripts := filepath.Join(root, "distros", "debian", "trixie", "scripts")
	if err := os.MkdirAll(scripts, 0o755); err != nil {
		t.Fatal(err)
	}
	script := filepath.Join(scripts, "fixture-sleep.sh")
	body := "#!/usr/bin/env bash\ninstall() { sleep 30; }\nuninstall() { :; }\ncase \"$1\" in install|uninstall) \"$1\" ;; *) exit 2 ;; esac\n"
	if err := os.WriteFile(script, []byte(body), 0o755); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	var buf strings.Builder
	code := runner.RunComponent(ctx, root, "debian", "trixie", "fixture-sleep",
		"install", true, false, func(line string) { buf.WriteString(line) })
	if code != runner.ExitCancelled {
		t.Fatalf("exit %d, want %d; out=%s", code, runner.ExitCancelled, buf.String())
	}
}

func TestAptUpdateDryRun(t *testing.T) {
	var buf strings.Builder
	code := runner.AptUpdate(context.Background(), true, false, func(line string) { buf.WriteString(line) })
	if code != 0 {
		t.Fatalf("exit %d", code)
	}
	if !strings.Contains(buf.String(), "DRY-RUN") {
		t.Fatalf("expected dry-run output: %s", buf.String())
	}
}
