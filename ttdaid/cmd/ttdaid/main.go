package main

import (
	"flag"
	"os"
)

func main() {
	showVersion := flag.Bool("version", false, "print version and exit")
	list := flag.Bool("list", false, "list components (short and full names) and exit")
	install := flag.String("install", "", "comma-separated components to install (e.g. qemu,libvirt,sdl)")
	uninstall := flag.String("uninstall", "", "comma-separated components to uninstall")
	dryRun := flag.Bool("dry-run", false, "with --install/--uninstall: print actions only")
	distro := flag.String("distro", "debian", "distribution tree under distros/")
	release := flag.String("release", "trixie", "release/codename under distros/<distro>/")
	debianVersion := flag.String("debian-version", "", "deprecated: use --release")
	flag.Usage = usage
	flag.Parse()
	os.Exit(dispatch(*showVersion, *list, *install, *uninstall, *dryRun, *distro, *release, *debianVersion))
}
