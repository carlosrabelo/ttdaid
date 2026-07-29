package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/carlosrabelo/ttdaid/ttdaid/internal/version"
)

func main() {
	showVersion := flag.Bool("version", false, "print version and exit")
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: %s [flags]\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "Things To Do After Installing Debian.\n\n")
		flag.PrintDefaults()
	}
	flag.Parse()

	if *showVersion {
		fmt.Printf("ttdaid %s\n", version.Version)
		os.Exit(0)
	}

	fmt.Fprintf(os.Stderr, "ttdaid: no action flags yet; try --version\n")
	os.Exit(0)
}
