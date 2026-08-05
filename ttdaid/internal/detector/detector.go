// Package detector provides best-effort heuristics for installed components.
package detector

import (
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"strings"
)

func whichAny(names ...string) bool {
	for _, n := range names {
		if _, err := exec.LookPath(n); err == nil {
			return true
		}
	}
	return false
}

func whichAll(names ...string) bool {
	if len(names) == 0 {
		return false
	}
	for _, n := range names {
		if _, err := exec.LookPath(n); err != nil {
			return false
		}
	}
	return true
}

func dpkgAny(packages ...string) bool {
	for _, pkg := range packages {
		if dpkgInstalled(pkg) {
			return true
		}
	}
	return false
}

func dpkgAll(packages ...string) bool {
	if len(packages) == 0 {
		return false
	}
	for _, pkg := range packages {
		if !dpkgInstalled(pkg) {
			return false
		}
	}
	return true
}

func dpkgInstalled(pkg string) bool {
	out, err := exec.Command("dpkg-query", "-W", "-f=${Status}", pkg).Output()
	if err != nil {
		return false
	}
	return strings.HasPrefix(strings.TrimSpace(string(out)), "install ok installed")
}

func pathExists(paths ...string) bool {
	for _, p := range paths {
		if _, err := os.Stat(p); err == nil {
			return true
		}
	}
	return false
}

func homeDir() string {
	if os.Geteuid() == 0 {
		if u := os.Getenv("SUDO_USER"); u != "" {
			if pu, err := user.Lookup(u); err == nil && pu.HomeDir != "" {
				return pu.HomeDir
			}
			if u == "root" {
				return "/root"
			}
			return filepath.Join("/home", u)
		}
	}
	if h, err := os.UserHomeDir(); err == nil {
		return h
	}
	return os.Getenv("HOME")
}

// IsInstalled reports whether a component appears present on the system.
// Multi-package components use AND on primary markers so a partial install
// is not treated as fully synced.
func IsInstalled(component string) bool {
	home := homeDir()
	checks := map[string]func() bool{
		"system-build-tools":  func() bool { return dpkgInstalled("build-essential") },
		"system-network-base": func() bool { return dpkgAll("openssh-server", "nmap") },
		"system-sysutils":     func() bool { return dpkgAll("htop", "neovim", "btop") },
		"system-sysctl":       func() bool { return pathExists("/etc/sysctl.d/99-ttdaid-swappiness.conf") },
		"system-sudoers":      func() bool { return pathExists("/etc/sudoers.d/99-ttdaid-nopasswd") },
		"editors-code":        func() bool { return whichAny("code") },
		"editors-codium":      func() bool { return whichAny("codium") },
		"editors-qt":          func() bool { return whichAny("qtcreator") || dpkgInstalled("qtcreator") },
		"languages-golang":    func() bool { return whichAny("go") },
		"languages-rust": func() bool {
			return pathExists(filepath.Join(home, ".cargo", "bin", "rustc"))
		},
		"languages-node":       func() bool { return whichAny("node") },
		"languages-java":       func() bool { return whichAny("javac") },
		"languages-php":        func() bool { return whichAny("php") },
		"languages-github":     func() bool { return whichAny("gh") },
		"languages-postgres":   func() bool { return whichAny("psql") },
		"gamedev-godot":        func() bool { return whichAny("godot") },
		"gamedev-love":         func() bool { return whichAny("love") },
		"gamedev-sdl":          func() bool { return dpkgInstalled("libsdl2-dev") },
		"containers-docker":    func() bool { return whichAny("docker") },
		"containers-distrobox": func() bool { return whichAny("distrobox") },
		"desktop-chromium":     func() bool { return whichAny("chromium", "chromium-browser") },
		"desktop-libreoffice":  func() bool { return whichAny("libreoffice") },
		"desktop-graphics":     func() bool { return whichAll("gimp", "inkscape") },
		"desktop-media":        func() bool { return whichAll("vlc", "ffmpeg") },
		"desktop-utils":        func() bool { return whichAll("meld", "bleachbit") },
		"desktop-flatpak":      func() bool { return whichAny("flatpak") },
		"desktop-ocr":          func() bool { return whichAny("tesseract") },
		"desktop-remote":       func() bool { return whichAll("remmina", "filezilla") },
		"desktop-latex":        func() bool { return whichAny("pdflatex", "xelatex") },
		"ai-claude": func() bool {
			return pathExists(filepath.Join(home, ".local", "bin", "claude")) || whichAny("claude")
		},
		"ai-codex": func() bool {
			return pathExists(filepath.Join(home, ".local", "bin", "codex")) || whichAny("codex")
		},
		"ai-gemini": func() bool {
			return pathExists(filepath.Join(home, ".npm-global", "bin", "gemini")) || whichAny("gemini")
		},
		"ai-opencode": func() bool {
			return pathExists(filepath.Join(home, ".opencode", "bin", "opencode")) || whichAny("opencode")
		},
		"virt-qemu": func() bool {
			return whichAny("qemu-system-x86_64") || dpkgAny("qemu-system-x86", "qemu-kvm")
		},
		"virt-libvirt":      func() bool { return dpkgAll("libvirt-daemon-system", "libvirt-clients") },
		"ops-network-extra": func() bool { return dpkgAll("arp-scan", "tor") },
		"ops-ansible":       func() bool { return whichAny("ansible") },
		"embedded-arm":      func() bool { return whichAny("arm-none-eabi-gcc") },
		"embedded-sdcc":     func() bool { return whichAny("sdcc") },
		"embedded-z80":      func() bool { return whichAny("z80asm") },
		"embedded-m6502":    func() bool { return whichAny("cl65") || dpkgInstalled("cc65") },
	}
	if fn, ok := checks[component]; ok {
		return fn()
	}
	parts := strings.Split(component, "-")
	short := parts[len(parts)-1]
	return whichAny(short)
}

// DetectInstalled returns presence for each component name.
func DetectInstalled(components []string) map[string]bool {
	out := make(map[string]bool, len(components))
	for _, name := range components {
		out[name] = IsInstalled(name)
	}
	return out
}
