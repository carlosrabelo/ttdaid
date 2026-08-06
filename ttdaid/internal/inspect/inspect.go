// Package inspect summarizes what a component script would install.
package inspect

import (
	"os"
	"os/exec"
	"regexp"
	"strings"

	"github.com/carlosrabelo/ttdaid/ttdaid/internal/runner"
)

// Info is a human-readable summary of a component's install side effects.
type Info struct {
	Name         string
	Script       string
	Steps        []string
	AptPackages  []string // product packages the component delivers
	AptDepends   []string // bootstrap deps (wget, curl, gpg, …)
	Flatpaks     []string
	CurlInstalls []string
	Notes        []string
}

var (
	reLogStep   = regexp.MustCompile(`log_step\s+"([^"]+)"`)
	reAptInst   = regexp.MustCompile(`apt_install\s+(.+)`)
	reFlatpak   = regexp.MustCompile(`flatpak_install\s+(.+)`)
	reHTTPURL   = regexp.MustCompile(`https?://[^\s'"]+`)
	reEnsureBin = regexp.MustCompile(`ensure_profile_tool_bin\s+(\S+)`)

	bootstrapApt = map[string]struct{}{
		"wget":                {},
		"curl":                {},
		"gpg":                 {},
		"gnupg":               {},
		"ca-certificates":     {},
		"apt-transport-https": {},
		"lsb-release":         {},
	}
)

// Component reads the component script and extracts install-related details.
func Component(repoRoot, distro, release, name string) (Info, error) {
	script := runner.ComponentScript(repoRoot, distro, release, name)
	info := Info{Name: name, Script: script}
	data, err := os.ReadFile(script)
	if err != nil {
		return info, err
	}
	body := extractFunction(string(data), "install")
	if body == "" {
		body = string(data)
		info.Notes = append(info.Notes, "install() not found — scanned whole script")
	}
	parseBody(body, &info)
	return info, nil
}

// Format renders Info for the TUI output pane.
func Format(info Info) string {
	var b strings.Builder
	b.WriteString("==> Info: " + info.Name + "\n")
	b.WriteString("Script: " + info.Script + "\n")
	if len(info.Steps) > 0 {
		b.WriteString("\nSteps:\n")
		for _, s := range info.Steps {
			b.WriteString("  • " + s + "\n")
		}
	}
	if len(info.AptPackages) > 0 {
		b.WriteString("\nInstalls (APT):\n")
		for _, p := range info.AptPackages {
			b.WriteString("  • " + p + pkgStatusSuffix(p) + "\n")
		}
	}
	if len(info.AptDepends) > 0 {
		b.WriteString("\nDepends (bootstrap — skipped if already present):\n")
		for _, p := range info.AptDepends {
			b.WriteString("  • " + p + pkgStatusSuffix(p) + "\n")
		}
	}
	if len(info.Flatpaks) > 0 {
		b.WriteString("\nFlatpak:\n")
		for _, p := range info.Flatpaks {
			b.WriteString("  • " + p + "\n")
		}
	}
	if len(info.CurlInstalls) > 0 {
		b.WriteString("\nRemote installers:\n")
		for _, p := range info.CurlInstalls {
			b.WriteString("  • " + p + "\n")
		}
	}
	if len(info.Notes) > 0 {
		b.WriteString("\nNotes:\n")
		for _, p := range info.Notes {
			b.WriteString("  • " + p + "\n")
		}
	}
	if len(info.Steps) == 0 && len(info.AptPackages) == 0 &&
		len(info.AptDepends) == 0 && len(info.Flatpaks) == 0 &&
		len(info.CurlInstalls) == 0 {
		b.WriteString("\n(no apt/flatpak/curl install lines detected — see script)\n")
	}
	return b.String()
}

func pkgStatusSuffix(pkg string) string {
	if aptInstalled(pkg) {
		return " [installed]"
	}
	return " [missing]"
}

func aptInstalled(pkg string) bool {
	out, err := exec.Command("dpkg-query", "-W", "-f=${Status}", pkg).Output()
	if err != nil {
		return false
	}
	return strings.HasPrefix(strings.TrimSpace(string(out)), "install ok installed")
}

func isBootstrapApt(pkg string) bool {
	_, ok := bootstrapApt[pkg]
	return ok
}

func isKeyOrRepoURL(s string) bool {
	low := strings.ToLower(s)
	markers := []string{
		"gpg", "keyring", ".asc", ".gpg", "/keys/", "gpgkey",
	}
	for _, m := range markers {
		if strings.Contains(low, m) {
			return true
		}
	}
	return false
}

// isRemoteInstaller reports software installers (curl|bash), not key fetches.
func isRemoteInstaller(line string) bool {
	low := strings.ToLower(line)
	if !strings.Contains(low, "http://") && !strings.Contains(low, "https://") {
		return false
	}
	if !strings.Contains(low, "curl") && !strings.Contains(low, "wget") {
		return false
	}
	url := reHTTPURL.FindString(line)
	if url != "" && isKeyOrRepoURL(url) {
		return false
	}
	if isKeyOrRepoURL(line) && !strings.Contains(low, "| bash") && !strings.Contains(low, "| sh") {
		return false
	}
	if strings.Contains(low, "| bash") || strings.Contains(low, "| sh") {
		return true
	}
	if strings.Contains(low, "install.sh") || strings.Contains(low, "rustup") ||
		strings.Contains(low, "/install") || strings.Contains(low, "sh.rustup.rs") {
		return !isKeyOrRepoURL(line)
	}
	return false
}

func extractFunction(src, name string) string {
	needle := name + "()"
	idx := strings.Index(src, needle)
	if idx < 0 {
		return ""
	}
	rest := src[idx+len(needle):]
	brace := strings.Index(rest, "{")
	if brace < 0 {
		return ""
	}
	rest = rest[brace+1:]
	depth := 1
	for i, r := range rest {
		switch r {
		case '{':
			depth++
		case '}':
			depth--
			if depth == 0 {
				return rest[:i]
			}
		}
	}
	return rest
}

func parseBody(body string, info *Info) {
	joined := joinContinuations(body)
	seenApt := map[string]struct{}{}
	seenDep := map[string]struct{}{}
	seenFlat := map[string]struct{}{}
	seenCurl := map[string]struct{}{}
	seenStep := map[string]struct{}{}

	for _, line := range strings.Split(joined, "\n") {
		trim := strings.TrimSpace(line)
		if trim == "" || strings.HasPrefix(trim, "#") {
			continue
		}
		if m := reLogStep.FindStringSubmatch(trim); len(m) == 2 {
			if _, ok := seenStep[m[1]]; !ok {
				seenStep[m[1]] = struct{}{}
				info.Steps = append(info.Steps, m[1])
			}
		}
		if m := reAptInst.FindStringSubmatch(trim); len(m) == 2 {
			for _, pkg := range tokenize(m[1]) {
				if isBootstrapApt(pkg) {
					if _, ok := seenDep[pkg]; ok {
						continue
					}
					seenDep[pkg] = struct{}{}
					info.AptDepends = append(info.AptDepends, pkg)
					continue
				}
				if _, ok := seenApt[pkg]; ok {
					continue
				}
				seenApt[pkg] = struct{}{}
				info.AptPackages = append(info.AptPackages, pkg)
			}
		}
		if m := reFlatpak.FindStringSubmatch(trim); len(m) == 2 {
			for _, pkg := range tokenize(m[1]) {
				if _, ok := seenFlat[pkg]; ok {
					continue
				}
				seenFlat[pkg] = struct{}{}
				info.Flatpaks = append(info.Flatpaks, pkg)
			}
		}
		if isRemoteInstaller(trim) {
			url := reHTTPURL.FindString(trim)
			key := url
			if key == "" {
				key = trim
			}
			if _, ok := seenCurl[key]; !ok {
				seenCurl[key] = struct{}{}
				info.CurlInstalls = append(info.CurlInstalls, key)
			}
		}
		if m := reEnsureBin.FindStringSubmatch(trim); len(m) == 2 {
			note := "PATH tool bin: " + m[1]
			info.Notes = append(info.Notes, note)
		}
	}
}

func joinContinuations(s string) string {
	lines := strings.Split(s, "\n")
	var out []string
	var buf string
	for _, line := range lines {
		t := strings.TrimRight(line, " \t")
		if strings.HasSuffix(t, "\\") {
			buf += strings.TrimSuffix(t, "\\") + " "
			continue
		}
		if buf != "" {
			out = append(out, buf+t)
			buf = ""
			continue
		}
		out = append(out, line)
	}
	if buf != "" {
		out = append(out, buf)
	}
	return strings.Join(out, "\n")
}

func tokenize(s string) []string {
	s = strings.TrimSpace(s)
	if i := strings.Index(s, "#"); i >= 0 {
		s = strings.TrimSpace(s[:i])
	}
	fields := strings.Fields(s)
	out := make([]string, 0, len(fields))
	for _, f := range fields {
		f = strings.Trim(f, `"'`)
		if f == "" || f == "\\" {
			continue
		}
		out = append(out, f)
	}
	return out
}
