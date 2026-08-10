// Package rootfs resolves the on-disk distros/ tree (checkout or extracted embed).
package rootfs

import (
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/carlosrabelo/ttdaid"
	"github.com/carlosrabelo/ttdaid/ttdaid/internal/version"
)

var (
	mu       sync.Mutex
	resolved string
)

// Resolve returns an absolute path whose child "distros/" holds component scripts.
// Prefer a live checkout; otherwise extract the embedded FS into the user cache.
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
	cache, err := extractEmbed()
	if err != nil {
		return "", err
	}
	resolved = cache
	return resolved, nil
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

func extractEmbed() (string, error) {
	base := os.Getenv("XDG_CACHE_HOME")
	if base == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		base = filepath.Join(home, ".cache")
	}
	dest := filepath.Join(base, "ttdaid")
	marker := filepath.Join(dest, ".embed-version")
	if hasDistros(dest) {
		if data, err := os.ReadFile(marker); err == nil && strings.TrimSpace(string(data)) == version.Version {
			return dest, nil
		}
	}

	tmp := filepath.Join(base, fmt.Sprintf("ttdaid-extract-%d", os.Getpid()))
	_ = os.RemoveAll(tmp)
	if err := os.MkdirAll(tmp, 0o755); err != nil {
		return "", err
	}
	defer os.RemoveAll(tmp)

	err := fs.WalkDir(distrosfs.FS, "distros", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		target := filepath.Join(tmp, path)
		if d.IsDir() {
			return os.MkdirAll(target, 0o755)
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			return err
		}
		in, err := distrosfs.FS.Open(path)
		if err != nil {
			return err
		}
		defer in.Close()
		out, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o755)
		if err != nil {
			return err
		}
		defer out.Close()
		_, err = io.Copy(out, in)
		return err
	})
	if err != nil {
		return "", fmt.Errorf("extract embedded distros/: %w", err)
	}

	if err := os.MkdirAll(dest, 0o755); err != nil {
		return "", err
	}
	distrosDest := filepath.Join(dest, "distros")
	distrosTmp := filepath.Join(tmp, "distros")
	if err := os.RemoveAll(distrosDest); err != nil {
		return "", err
	}
	if err := os.Rename(distrosTmp, distrosDest); err != nil {
		return "", err
	}
	if err := os.WriteFile(marker, []byte(version.Version+"\n"), 0o644); err != nil {
		return "", err
	}
	return dest, nil
}
