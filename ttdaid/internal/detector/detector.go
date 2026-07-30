// Package detector provides best-effort heuristics for installed components.
package detector

import (
	"os/exec"
	"strings"
)

// IsInstalled reports whether a component appears present on the system.
// Scaffold: only a PATH (which) check on the short name; real dpkg heuristics
// land in a later commit.
func IsInstalled(component string) bool {
	short := component
	if i := strings.LastIndex(component, "-"); i >= 0 {
		short = component[i+1:]
	}
	_, err := exec.LookPath(short)
	return err == nil
}
