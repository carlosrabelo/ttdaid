package catalog_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/carlosrabelo/ttdaid/ttdaid/internal/catalog"
	"github.com/carlosrabelo/ttdaid/ttdaid/internal/rootfs"
)

func TestResolveComponentsEmpty(t *testing.T) {
	names := catalog.ResolveComponents("")
	has := map[string]bool{}
	for _, n := range names {
		has[n] = true
	}
	if !has["containers-docker"] || !has["editors-code"] {
		t.Fatalf("expected catalog components, got %v", names)
	}
	if has["apt-upgrade"] {
		t.Fatal("apt-upgrade should not be in catalog")
	}
}

func TestResolveGroup(t *testing.T) {
	names := catalog.ResolveComponents("containers")
	want := catalog.Groups["containers"]
	if len(names) != len(want) {
		t.Fatalf("got %v want %v", names, want)
	}
	for i := range want {
		if names[i] != want[i] {
			t.Fatalf("got %v want %v", names, want)
		}
	}
}

func TestResolveEditors(t *testing.T) {
	names := catalog.ResolveComponents("editors")
	has := map[string]bool{}
	for _, n := range names {
		has[n] = true
	}
	if !has["editors-code"] || has["languages-golang"] {
		t.Fatalf("unexpected editors resolution: %v", names)
	}
}

func TestDevelopmentAlias(t *testing.T) {
	names := catalog.ResolveComponents("development")
	has := map[string]bool{}
	for _, n := range names {
		has[n] = true
	}
	if !has["editors-code"] || !has["languages-golang"] || !has["gamedev-godot"] {
		t.Fatalf("development alias incomplete: %v", names)
	}
	if has["containers-docker"] {
		t.Fatal("containers should not be in development alias")
	}
}

func TestMixedTokens(t *testing.T) {
	names := catalog.ResolveComponents("ai,containers-docker")
	has := map[string]bool{}
	for _, n := range names {
		has[n] = true
	}
	if !has["containers-docker"] || !has["ai-claude"] {
		t.Fatalf("mixed tokens failed: %v", names)
	}
}

func TestResolveSpecShortNames(t *testing.T) {
	names, err := catalog.ResolveSpec("qemu,libvirt,sdl")
	if err != nil {
		t.Fatal(err)
	}
	has := map[string]bool{}
	for _, n := range names {
		has[n] = true
	}
	if !has["virt-qemu"] || !has["virt-libvirt"] || !has["gamedev-sdl"] {
		t.Fatalf("got %v", names)
	}
}

func TestResolveSpecGroup(t *testing.T) {
	names, err := catalog.ResolveSpec("virt")
	if err != nil {
		t.Fatal(err)
	}
	if len(names) != len(catalog.Groups["virt"]) {
		t.Fatalf("got %v", names)
	}
}

func TestResolveSpecUnknown(t *testing.T) {
	if _, err := catalog.ResolveSpec("no-such-thing"); err == nil {
		t.Fatal("expected error")
	}
}

func TestDiscoverTrixie(t *testing.T) {
	root, err := rootfs.Resolve()
	if err != nil {
		t.Fatal(err)
	}
	names, err := catalog.DiscoverComponents(root, "debian", "trixie")
	if err != nil {
		t.Fatal(err)
	}
	has := map[string]bool{}
	for _, n := range names {
		has[n] = true
	}
	if !has["containers-docker"] && !has["system-build-tools"] {
		t.Fatalf("expected trixie scripts under %s, got %v", filepath.Join(root, "distros/debian/trixie/scripts"), names)
	}
	if has["lib"] {
		t.Fatal("lib should not appear as component")
	}
	if has["system-bash"] {
		t.Fatal("system-bash is always-run, not a checklist component")
	}
}

func TestCatalogScriptParity(t *testing.T) {
	root, err := rootfs.Resolve()
	if err != nil {
		t.Fatal(err)
	}
	dir := catalog.ScriptsDir(root, "debian", "trixie")
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}
	onDisk := map[string]bool{}
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".sh") {
			continue
		}
		if _, skip := catalog.LibraryScripts[e.Name()]; skip {
			continue
		}
		stem := strings.TrimSuffix(e.Name(), ".sh")
		onDisk[stem] = true
	}
	for _, name := range catalog.AllComponents() {
		if !onDisk[name] {
			t.Errorf("catalog component %q has no script in %s", name, dir)
		}
	}
	for name := range catalog.AlwaysRunScripts {
		if !onDisk[name] {
			t.Errorf("always-run %q has no script in %s", name, dir)
		}
	}
	catalogued := map[string]bool{}
	for _, name := range catalog.AllComponents() {
		catalogued[name] = true
	}
	for name := range onDisk {
		if catalogued[name] {
			continue
		}
		if _, always := catalog.AlwaysRunScripts[name]; always {
			continue
		}
		t.Errorf("script %q.sh is not in catalog Groups or AlwaysRunScripts", name)
	}
}

func TestExpandDevtools(t *testing.T) {
	names := catalog.ExpandToken("devtools")
	has := map[string]bool{}
	for _, n := range names {
		has[n] = true
	}
	if !has["languages-golang"] || !has["containers-docker"] {
		t.Fatalf("devtools alias failed: %v", names)
	}
}

func TestExpandNetwork(t *testing.T) {
	names := catalog.ExpandToken("network")
	want := catalog.Groups["ops"]
	if len(names) != len(want) {
		t.Fatalf("got %v want %v", names, want)
	}
}

func TestDisplayName(t *testing.T) {
	if got := catalog.ComponentDisplayName("editors-code", "editors"); got != "code" {
		t.Fatalf("got %q", got)
	}
	if got := catalog.ComponentDisplayName("desktop-utils", "desktop"); got != "utils" {
		t.Fatalf("got %q", got)
	}
	if got := catalog.ComponentDisplayName("system-build-tools", "system"); got != "build-tools" {
		t.Fatalf("got %q", got)
	}
}
