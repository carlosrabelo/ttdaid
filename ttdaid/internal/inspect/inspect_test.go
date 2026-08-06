package inspect_test

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/carlosrabelo/ttdaid/ttdaid/internal/inspect"
	"github.com/carlosrabelo/ttdaid/ttdaid/internal/rootfs"
)

func TestComponentDesktopUtils(t *testing.T) {
	root, err := rootfs.Resolve()
	if err != nil {
		t.Fatal(err)
	}
	info, err := inspect.Component(root, "debian", "trixie", "desktop-utils")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(info.Script, filepath.Join("desktop-utils.sh")) {
		t.Fatalf("script path: %s", info.Script)
	}
	has := map[string]bool{}
	for _, p := range info.AptPackages {
		has[p] = true
	}
	for _, want := range []string{"meld", "mc", "gnome-tweaks"} {
		if !has[want] {
			t.Fatalf("missing package %q in %v", want, info.AptPackages)
		}
	}
	if strings.Contains(inspect.Format(info), "wkhtmltopdf") {
		t.Fatal("wkhtmltopdf should not appear")
	}
}

func TestComponentGithubInstallsVsDepends(t *testing.T) {
	root, err := rootfs.Resolve()
	if err != nil {
		t.Fatal(err)
	}
	info, err := inspect.Component(root, "debian", "trixie", "languages-github")
	if err != nil {
		t.Fatal(err)
	}
	hasPkg := map[string]bool{}
	for _, p := range info.AptPackages {
		hasPkg[p] = true
	}
	hasDep := map[string]bool{}
	for _, p := range info.AptDepends {
		hasDep[p] = true
	}
	if !hasPkg["gh"] {
		t.Fatalf("expected gh in Installs, got %v", info.AptPackages)
	}
	if hasPkg["wget"] {
		t.Fatalf("wget belongs in Depends, not Installs: %v", info.AptPackages)
	}
	if !hasDep["wget"] {
		t.Fatalf("expected wget in Depends, got %v", info.AptDepends)
	}
	formatted := inspect.Format(info)
	if !strings.Contains(formatted, "Installs (APT)") {
		t.Fatalf("missing Installs section:\n%s", formatted)
	}
	if !strings.Contains(formatted, "Depends (bootstrap") {
		t.Fatalf("missing Depends section:\n%s", formatted)
	}
	if strings.Contains(formatted, "githubcli-archive-keyring") {
		t.Fatalf("keyring URL should not appear:\n%s", formatted)
	}
	if len(info.CurlInstalls) != 0 {
		t.Fatalf("key fetch should not be a remote installer: %v", info.CurlInstalls)
	}
}

func TestComponentOpencodeHasRemoteInstaller(t *testing.T) {
	root, err := rootfs.Resolve()
	if err != nil {
		t.Fatal(err)
	}
	info, err := inspect.Component(root, "debian", "trixie", "ai-opencode")
	if err != nil {
		t.Fatal(err)
	}
	if len(info.CurlInstalls) == 0 {
		t.Fatalf("expected remote installer, got %+v", info)
	}
	joined := strings.Join(info.CurlInstalls, " ")
	if !strings.Contains(joined, "opencode.ai") {
		t.Fatalf("expected opencode URL in %v", info.CurlInstalls)
	}
}

func TestComponentCodexHasRemoteInstaller(t *testing.T) {
	root, err := rootfs.Resolve()
	if err != nil {
		t.Fatal(err)
	}
	info, err := inspect.Component(root, "debian", "trixie", "ai-codex")
	if err != nil {
		t.Fatal(err)
	}
	if len(info.CurlInstalls) == 0 {
		t.Fatalf("expected remote installer, got %+v", info)
	}
	joined := strings.Join(info.CurlInstalls, " ")
	if !strings.Contains(joined, "chatgpt.com/codex/install.sh") {
		t.Fatalf("expected chatgpt.com codex URL in %v", info.CurlInstalls)
	}
}

func TestComponentCodeInstallsVsDepends(t *testing.T) {
	root, err := rootfs.Resolve()
	if err != nil {
		t.Fatal(err)
	}
	info, err := inspect.Component(root, "debian", "trixie", "editors-code")
	if err != nil {
		t.Fatal(err)
	}
	hasPkg := map[string]bool{}
	for _, p := range info.AptPackages {
		hasPkg[p] = true
	}
	hasDep := map[string]bool{}
	for _, p := range info.AptDepends {
		hasDep[p] = true
	}
	if !hasPkg["code"] {
		t.Fatalf("expected code in Installs, got %v", info.AptPackages)
	}
	for _, boot := range []string{"wget", "gpg", "apt-transport-https"} {
		if hasPkg[boot] {
			t.Fatalf("%q should be in Depends, not Installs", boot)
		}
		if !hasDep[boot] {
			t.Fatalf("expected %q in Depends, got %v", boot, info.AptDepends)
		}
	}
	if strings.Contains(inspect.Format(info), "packages.microsoft.com/keys") {
		t.Fatal("Microsoft key URL should not appear in Info")
	}
}
