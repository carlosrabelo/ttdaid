package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"text/tabwriter"

	"github.com/carlosrabelo/ttdaid/ttdaid/internal/catalog"
	"github.com/carlosrabelo/ttdaid/ttdaid/internal/orchestrator"
	"github.com/carlosrabelo/ttdaid/ttdaid/internal/rootfs"
	"github.com/carlosrabelo/ttdaid/ttdaid/internal/tui"
	"github.com/carlosrabelo/ttdaid/ttdaid/internal/version"
)

func usage() {
	fmt.Fprintf(os.Stderr, "Usage: %s [flags]\n\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "No install/uninstall flags → interactive TUI.\n\n")
	fmt.Fprintf(os.Stderr, "Examples:\n")
	fmt.Fprintf(os.Stderr, "  %s\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "  %s --list\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "  %s --install qemu,libvirt,sdl\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "  %s --install virt --dry-run\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "  %s --uninstall qemu\n\n", os.Args[0])
	flag.PrintDefaults()
}

func dispatch(showVersion, list bool, install, uninstall string, dryRun bool, distro, release, debianVersion string) int {
	if showVersion {
		fmt.Printf("ttdaid %s\n", version.Version)
		return 0
	}

	rel := release
	if debianVersion != "" {
		rel = debianVersion
	}

	repoRoot, err := rootfs.Resolve()
	if err != nil {
		fmt.Fprintf(os.Stderr, "ttdaid: %v\n", err)
		return 1
	}

	if list {
		if err := printComponentList(); err != nil {
			fmt.Fprintf(os.Stderr, "ttdaid: %v\n", err)
			return 1
		}
		return 0
	}

	if install != "" && uninstall != "" {
		fmt.Fprintf(os.Stderr, "ttdaid: use only one of --install or --uninstall\n")
		return 2
	}

	if install != "" || uninstall != "" {
		spec := install
		wantOn := true
		if uninstall != "" {
			spec = uninstall
			wantOn = false
		}
		return runCLI(repoRoot, distro, rel, spec, wantOn, dryRun)
	}

	return tui.Run(distro, rel, repoRoot)
}

func printComponentList() error {
	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "SHORT\tFULL\tGROUP")
	for _, g := range catalog.AllGroups {
		for _, c := range catalog.Groups[g] {
			fmt.Fprintf(w, "%s\t%s\t%s\n", catalog.ComponentDisplayName(c, g), c, g)
		}
	}
	return w.Flush()
}

func runCLI(repoRoot, distro, release, spec string, wantOn, dryRun bool) int {
	comps, err := catalog.ResolveSpec(spec)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ttdaid: %v\n", err)
		return 2
	}

	desired := map[string]struct{}{}
	if wantOn {
		for _, c := range comps {
			desired[c] = struct{}{}
		}
	}

	action := "install"
	if !wantOn {
		action = "uninstall"
	}
	fmt.Printf("TTDAID CLI %s: %s\n", action, strings.Join(comps, ", "))
	if dryRun {
		fmt.Println("(dry-run)")
	}

	if !dryRun {
		if err := ensureSudo(); err != nil {
			fmt.Fprintf(os.Stderr, "ttdaid: %v\n", err)
			return 1
		}
	}

	return orchestrator.Apply(orchestrator.ApplyOptions{
		Distro:      distro,
		Release:     release,
		Desired:     desired,
		Scope:       comps,
		DryRun:      dryRun,
		SkipOSCheck: dryRun,
		RepoRoot:    repoRoot,
		UseSudo:     !dryRun,
	}, nil, nil)
}

func ensureSudo() error {
	if os.Geteuid() == 0 {
		return nil
	}
	if exec.Command("sudo", "-n", "true").Run() == nil {
		return nil
	}
	fmt.Fprintln(os.Stderr, "ttdaid: sudo required — enter password if prompted")
	cmd := exec.Command("sudo", "-v")
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("sudo auth failed: %w", err)
	}
	return nil
}
