// Package orchestrator plans and applies component sync actions.
package orchestrator

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"

	"github.com/carlosrabelo/ttdaid/ttdaid/internal/catalog"
	"github.com/carlosrabelo/ttdaid/ttdaid/internal/detector"
	"github.com/carlosrabelo/ttdaid/ttdaid/internal/runner"
)

// ApplyOptions configures a sync run.
type ApplyOptions struct {
	Distro      string // e.g. "debian"
	Release     string // e.g. "trixie"
	Desired     map[string]struct{}
	Scope       []string
	DryRun      bool
	SkipOSCheck bool
	RepoRoot    string
	UseSudo     bool
	Ctx         context.Context // optional; cancel aborts the current/next step
}

// Error is returned for orchestration failures.
type Error struct {
	Msg string
}

func (e *Error) Error() string { return e.Msg }

// DetectOS returns VERSION_ID and VERSION_CODENAME best-effort.
func DetectOS() (version, codename string) {
	version, codename = "unknown", "unknown"
	if out, err := exec.Command("lsb_release", "-sr").Output(); err == nil {
		version = strings.TrimSpace(string(out))
	}
	if out, err := exec.Command("lsb_release", "-sc").Output(); err == nil {
		codename = strings.TrimSpace(string(out))
	}
	return version, codename
}

// AssertSupportedOS ensures the host matches the target distro/release tree.
func AssertSupportedOS(distro, release string) error {
	version, codename := DetectOS()
	if distro == "debian" && release == "trixie" {
		if codename != "trixie" && version != "13" && version != "13.0" {
			return &Error{Msg: fmt.Sprintf(
				"This setup targets Debian 13 Trixie. Detected: %s (%s)", version, codename)}
		}
	}
	return nil
}

// PlanActions builds (component, action) pairs for sync.
func PlanActions(desired map[string]struct{}, components []string) [][2]string {
	actions := make([][2]string, 0)
	for _, name := range components {
		_, want := desired[name]
		present := detector.IsInstalled(name)
		if want && !present {
			actions = append(actions, [2]string{name, "install"})
		} else if !want && present {
			actions = append(actions, [2]string{name, "uninstall"})
		}
	}
	return actions
}

// SplitActions returns install and uninstall component lists from a plan.
func SplitActions(actions [][2]string) (toInstall, toRemove []string) {
	for _, a := range actions {
		if a[1] == "install" {
			toInstall = append(toInstall, a[0])
		} else {
			toRemove = append(toRemove, a[0])
		}
	}
	return toInstall, toRemove
}

// Apply syncs the system to the desired checkbox state. Returns process-style exit code.
func Apply(opts ApplyOptions, log runner.LogFn, onStep func(name, action string, index, total int)) int {
	emit := log
	if emit == nil {
		emit = func(line string) {
			if !strings.HasSuffix(line, "\n") {
				line += "\n"
			}
			fmt.Fprint(os.Stdout, line)
		}
	}
	ctx := opts.Ctx
	if ctx == nil {
		ctx = context.Background()
	}
	if opts.Distro == "" {
		opts.Distro = "debian"
	}
	if opts.Release == "" {
		opts.Release = "trixie"
	}
	root := opts.RepoRoot
	vdir := catalog.TargetDir(root, opts.Distro, opts.Release)
	if st, err := os.Stat(vdir); err != nil || !st.IsDir() {
		emit(fmt.Sprintf("[ERROR] Directory not found: %s\n", vdir))
		return 1
	}
	if !opts.SkipOSCheck && !opts.DryRun {
		if err := AssertSupportedOS(opts.Distro, opts.Release); err != nil {
			emit(fmt.Sprintf("[ERROR] %v\n", err))
			return 1
		}
	}
	components := opts.Scope
	if len(components) == 0 {
		var err error
		components, err = catalog.DiscoverComponents(root, opts.Distro, opts.Release)
		if err != nil {
			emit(fmt.Sprintf("[ERROR] %v\n", err))
			return 1
		}
	}
	if len(components) == 0 {
		emit("[ERROR] No components found.\n")
		return 1
	}
	rank := map[string]int{}
	for i, n := range catalog.AllComponents() {
		rank[n] = i
	}
	sort.SliceStable(components, func(i, j int) bool {
		ri, okI := rank[components[i]]
		rj, okJ := rank[components[j]]
		if !okI {
			ri = 10_000
		}
		if !okJ {
			rj = 10_000
		}
		return ri < rj
	})
	actions := PlanActions(opts.Desired, components)
	alwaysRun := alwaysRunPresent(root, opts.Distro, opts.Release)
	version, codename := DetectOS()
	emit("\n==> TTDAID — apply (sync desired state)\n")
	emit(fmt.Sprintf("[INFO]  OS version  : %s (%s)\n", version, codename))
	emit(fmt.Sprintf("[INFO]  Target      : %s/%s\n", opts.Distro, opts.Release))
	emit(fmt.Sprintf("[INFO]  Directory   : %s\n", vdir))
	emit(fmt.Sprintf("[INFO]  Desired ON  : %d components\n", len(opts.Desired)))
	emit(fmt.Sprintf("[INFO]  Scope       : %d components\n", len(components)))
	emit(fmt.Sprintf("[INFO]  Dry-run     : %v\n", opts.DryRun))
	if len(alwaysRun) > 0 {
		emit(fmt.Sprintf("[INFO]  Always-run  : %s\n", strings.Join(alwaysRun, " ")))
	}
	if len(actions) == 0 && len(alwaysRun) == 0 {
		emit("[OK]    Already in sync — nothing to do.\n")
		return 0
	}
	toInstall, toRemove := SplitActions(actions)
	emit(fmt.Sprintf("[INFO]  Will install   : %s\n", orNone(toInstall)))
	emit(fmt.Sprintf("[INFO]  Will uninstall : %s\n", orNone(toRemove)))

	cancelled := func(code int) bool {
		if code == runner.ExitCancelled {
			emit("\n[WARN] Apply cancelled — already-finished steps are not rolled back.\n")
			return true
		}
		return false
	}

	// Bash/profile hooks and similar: always install first (idempotent).
	for _, name := range alwaysRun {
		if ctx.Err() != nil {
			emit("\n[WARN] Apply cancelled — already-finished steps are not rolled back.\n")
			return runner.ExitCancelled
		}
		if onStep != nil {
			onStep(name, "install", 0, len(actions)+len(alwaysRun))
		}
		code := runner.RunComponent(ctx, root, opts.Distro, opts.Release, name, "install", opts.DryRun, opts.UseSudo, emit)
		if cancelled(code) {
			return code
		}
		if code != 0 {
			emit(fmt.Sprintf("[ERROR] Always-run '%s' (install) failed with exit code %d\n", name, code))
			return code
		}
	}

	if len(actions) == 0 {
		emit("\n==> Done!\n")
		emit("[OK]    TTDAID apply complete (always-run only).\n")
		if opts.DryRun {
			emit("[WARN]  Dry-run mode: no changes were made.\n")
		}
		return 0
	}

	if len(toInstall) > 0 {
		if code := runner.AptUpdate(ctx, opts.DryRun, opts.UseSudo, emit); code != 0 {
			if cancelled(code) {
				return code
			}
			return code
		}
	}
	total := len(actions)
	for i, a := range actions {
		if ctx.Err() != nil {
			emit("\n[WARN] Apply cancelled — already-finished steps are not rolled back.\n")
			return runner.ExitCancelled
		}
		name, action := a[0], a[1]
		if onStep != nil {
			onStep(name, action, i+1, total)
		}
		code := runner.RunComponent(ctx, root, opts.Distro, opts.Release, name, action, opts.DryRun, opts.UseSudo, emit)
		if cancelled(code) {
			return code
		}
		if code != 0 {
			emit(fmt.Sprintf("[ERROR] Component '%s' (%s) failed with exit code %d\n", name, action, code))
			return code
		}
	}
	emit("\n==> Done!\n")
	emit("[OK]    TTDAID apply complete.\n")
	if opts.DryRun {
		emit("[WARN]  Dry-run mode: no changes were made.\n")
	}
	return 0
}

// alwaysRunPresent returns AlwaysRunScripts that exist on disk, in stable name order.
func alwaysRunPresent(repoRoot, distro, release string) []string {
	names := make([]string, 0, len(catalog.AlwaysRunScripts))
	for name := range catalog.AlwaysRunScripts {
		script := filepath.Join(catalog.ScriptsDir(repoRoot, distro, release), name+".sh")
		if st, err := os.Stat(script); err == nil && !st.IsDir() {
			names = append(names, name)
		}
	}
	sort.Strings(names)
	return names
}

func orNone(items []string) string {
	if len(items) == 0 {
		return "(none)"
	}
	return strings.Join(items, " ")
}
