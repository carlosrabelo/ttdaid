// Package rootfs resolves the on-disk distros/ tree from a live checkout.
package rootfs

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"
)

var (
	mu       sync.Mutex
	resolved string
)

// Resolve returns an absolute path whose child "distros/" holds component scripts.
// Scaffold: checkout / TTDAID_ROOT only (embed lands in a later commit).
func Resolve() (string, error) {
	mu.Lock()
	defer mu.Unlock()
	if resolved != "" {
		return resolved, nil
	}
	if env := os.Getenv("TTDAID_ROOT"); env != "" {
		if hasDistros(env) {
			resolved = env
			return resolved, nil
		}
		return "", fmt.Errorf("TTDAID_ROOT=%s has no distros/ tree", env)
	}
	if root, ok := findCheckout(); ok {
		resolved = root
		return resolved, nil
	}
	return "", fmt.Errorf("distros/ not found (set TTDAID_ROOT or run from a checkout)")
}

func hasDistros(root string) bool {
	st, err := os.Stat(filepath.Join(root, "distros"))
	return err == nil && st.IsDir()
}

func findCheckout() (string, bool) {
	candidates := []string{}
	if wd, err := os.Getwd(); err == nil {
		candidates = append(candidates, wd)
	}
	if exe, err := os.Executable(); err == nil {
		candidates = append(candidates, filepath.Dir(exe))
	}
	for _, start := range candidates {
		dir := start
		for {
			if hasDistros(dir) {
				return dir, true
			}
			parent := filepath.Dir(dir)
			if parent == dir {
				break
			}
			dir = parent
		}
	}
	return "", false
}
