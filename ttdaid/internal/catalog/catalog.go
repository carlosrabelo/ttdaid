// Package catalog defines TTDAID component groups and discovery.
package catalog

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// AlwaysRunScripts are not checklist components. Apply always runs install
// on them (idempotent setup, e.g. bash dotfile injection).
var AlwaysRunScripts = map[string]struct{}{
	"system-bash": {},
}

// Groups maps group id → component ids (script stems).
var Groups = map[string][]string{
	"system": {
		"system-build-tools",
		"system-network-base",
		"system-sysutils",
		"system-sysctl",
		"system-sudoers",
	},
	"editors": {"editors-code", "editors-codium", "editors-qt"},
	"languages": {
		"languages-golang",
		"languages-rust",
		"languages-node",
		"languages-java",
		"languages-php",
		"languages-github",
		"languages-postgres",
	},
	"gamedev":    {"gamedev-godot", "gamedev-love", "gamedev-sdl"},
	"containers": {"containers-docker", "containers-distrobox"},
	"desktop": {
		"desktop-chromium",
		"desktop-libreoffice",
		"desktop-graphics",
		"desktop-media",
		"desktop-utils",
		"desktop-flatpak",
		"desktop-ocr",
		"desktop-remote",
		"desktop-latex",
	},
	"ai":   {"ai-claude", "ai-codex", "ai-gemini", "ai-opencode"},
	"virt": {"virt-qemu", "virt-libvirt"},
	"ops":  {"ops-network-extra", "ops-ansible"},
	"embedded": {
		"embedded-arm",
		"embedded-sdcc",
		"embedded-z80",
		"embedded-m6502",
	},
}

// GroupLabels are human-readable section titles for the TUI.
var GroupLabels = map[string]string{
	"system":     "System",
	"editors":    "Editors & IDEs",
	"languages":  "Languages & CLIs",
	"gamedev":    "Game development",
	"containers": "Containers",
	"desktop":    "Desktop & office",
	"ai":         "AI CLIs",
	"virt":       "Virtualization",
	"ops":        "Network & ops",
	"embedded":   "Embedded",
}

// GroupAliases expand legacy/filter tokens to component lists.
var GroupAliases = map[string][]string{
	"development": append(append(append([]string{}, Groups["editors"]...), Groups["languages"]...), Groups["gamedev"]...),
	"devtools":    append(append([]string{}, Groups["languages"]...), Groups["containers"]...),
	"network":     append([]string{}, Groups["ops"]...),
}

// AllGroups is catalog group order for the TUI.
var AllGroups = []string{
	"system", "editors", "languages", "gamedev", "containers",
	"desktop", "ai", "virt", "ops", "embedded",
}

// LibraryScripts are shared helpers, not components.
var LibraryScripts = map[string]struct{}{
	"lib.sh": {},
}

// AllComponents is the flat catalog order.
func AllComponents() []string {
	out := make([]string, 0, 64)
	for _, g := range AllGroups {
		out = append(out, Groups[g]...)
	}
	return out
}

// ComponentDisplayName strips the leading "<group>-" prefix for TUI labels.
func ComponentDisplayName(component string, group string) string {
	if group != "" {
		prefix := group + "-"
		if strings.HasPrefix(component, prefix) {
			return component[len(prefix):]
		}
	}
	for _, g := range AllGroups {
		prefix := g + "-"
		if strings.HasPrefix(component, prefix) {
			return component[len(prefix):]
		}
	}
	return component
}

// TargetDir returns repoRoot/distros/<distro>/<release>.
func TargetDir(repoRoot, distro, release string) string {
	return filepath.Join(repoRoot, "distros", distro, release)
}

// VersionDir is an alias for TargetDir with distro "debian" (legacy name).
func VersionDir(repoRoot, release string) string {
	return TargetDir(repoRoot, "debian", release)
}

// ScriptsDir returns repoRoot/distros/<distro>/<release>/scripts.
func ScriptsDir(repoRoot, distro, release string) string {
	return filepath.Join(TargetDir(repoRoot, distro, release), "scripts")
}

// DiscoverComponents lists scripts on disk in catalog order, then orphans.
func DiscoverComponents(repoRoot, distro, release string) ([]string, error) {
	dir := ScriptsDir(repoRoot, distro, release)
	entries, err := os.ReadDir(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("scripts directory not found: %s", dir)
		}
		return nil, err
	}
	onDisk := map[string]struct{}{}
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := e.Name()
		if !strings.HasSuffix(name, ".sh") {
			continue
		}
		if _, skip := LibraryScripts[name]; skip {
			continue
		}
		stem := strings.TrimSuffix(name, ".sh")
		if _, skip := AlwaysRunScripts[stem]; skip {
			continue
		}
		onDisk[stem] = struct{}{}
	}
	all := AllComponents()
	allSet := map[string]struct{}{}
	for _, n := range all {
		allSet[n] = struct{}{}
	}
	ordered := make([]string, 0, len(onDisk))
	for _, n := range all {
		if _, ok := onDisk[n]; ok {
			ordered = append(ordered, n)
		}
	}
	orphans := make([]string, 0)
	for n := range onDisk {
		if _, known := allSet[n]; !known {
			if _, always := AlwaysRunScripts[n]; !always {
				orphans = append(orphans, n)
			}
		}
	}
	sort.Strings(orphans)
	return append(ordered, orphans...), nil
}

// ExpandToken expands a group, alias, full id, or unique short name.
// Unknown tokens are returned unchanged (legacy); prefer ResolveToken for CLI.
func ExpandToken(token string) []string {
	names, err := ResolveToken(token)
	if err != nil {
		token = strings.TrimSpace(token)
		if token == "" {
			return nil
		}
		return []string{token}
	}
	return names
}

// ResolveToken expands one token into component ids.
// Accepts: group (virt), alias (development), full id (virt-qemu),
// or unique short name (qemu → virt-qemu).
func ResolveToken(token string) ([]string, error) {
	token = strings.TrimSpace(token)
	if token == "" {
		return nil, nil
	}
	if members, ok := GroupAliases[token]; ok {
		return append([]string{}, members...), nil
	}
	if members, ok := Groups[token]; ok {
		return append([]string{}, members...), nil
	}
	all := AllComponents()
	for _, c := range all {
		if c == token {
			return []string{c}, nil
		}
	}
	var matches []string
	for _, c := range all {
		short := ComponentDisplayName(c, "")
		if short == token || strings.EqualFold(short, token) {
			matches = append(matches, c)
		}
	}
	switch len(matches) {
	case 0:
		return nil, fmt.Errorf("unknown component %q (try --list)", token)
	case 1:
		return matches, nil
	default:
		return nil, fmt.Errorf("ambiguous name %q matches %s", token, strings.Join(matches, ", "))
	}
}

// ResolveComponents expands a comma-separated filter. Empty → full catalog.
// Unknown tokens are kept as-is (legacy ExpandToken behavior).
func ResolveComponents(scriptsFilter string) []string {
	if strings.TrimSpace(scriptsFilter) == "" {
		return AllComponents()
	}
	resolved := make([]string, 0)
	seen := map[string]struct{}{}
	for _, raw := range strings.Split(scriptsFilter, ",") {
		for _, item := range ExpandToken(raw) {
			if item == "" {
				continue
			}
			if _, ok := seen[item]; ok {
				continue
			}
			seen[item] = struct{}{}
			resolved = append(resolved, item)
		}
	}
	return resolved
}

// ResolveSpec expands a comma-separated CLI spec (install/uninstall).
// Empty is an error. Unknown or ambiguous tokens fail.
func ResolveSpec(spec string) ([]string, error) {
	spec = strings.TrimSpace(spec)
	if spec == "" {
		return nil, fmt.Errorf("empty component list")
	}
	resolved := make([]string, 0)
	seen := map[string]struct{}{}
	for _, raw := range strings.Split(spec, ",") {
		raw = strings.TrimSpace(raw)
		if raw == "" {
			continue
		}
		names, err := ResolveToken(raw)
		if err != nil {
			return nil, err
		}
		for _, item := range names {
			if _, ok := seen[item]; ok {
				continue
			}
			seen[item] = struct{}{}
			resolved = append(resolved, item)
		}
	}
	if len(resolved) == 0 {
		return nil, fmt.Errorf("empty component list")
	}
	return resolved, nil
}
