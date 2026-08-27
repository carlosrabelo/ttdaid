# TTDAID

Interactive Bubble Tea checklist that installs and removes Debian component scripts after a fresh install (**Things To Do After Installing Debian**). Current tree is Debian 13 (Trixie); the layout is ready for more distros.

## Highlights

- Checklist with Detect on open and one Apply (checked → install, unchecked → uninstall)
- Apply asks Y/N when the plan includes uninstalls
- Groups: `system`, `editors`, `languages`, `gamedev`, `containers`, `desktop`, `ai`, `virt`, `ops`, `embedded`
- Components are `ttdaid/distros/<distro>/<release>/scripts/<group>-<name>.sh` (`install` / `uninstall`)
- No Snap — APT, official `.deb` repos, or Flatpak/Flathub
- Dry-run Apply to preview without changing the system
- Always-run bash setup keeps Debian’s stock `~/.bashrc` / `~/.profile` and only injects marked blocks

## Prerequisites

- **Debian 13 (Trixie)** — current component tree
- **Go 1.24+** — required to build from source; [download](https://go.dev/dl/)
- **sudo** — required for a real Apply (`system-sudoers` or run `sudo -v` when prompted)

## Installation

### Build from Source

```bash
git clone https://github.com/carlosrabelo/ttdaid.git
cd ttdaid
make setup
make build
```

Install to `~/.local/bin` (default), or system-wide to `/usr/local/bin` (sudo only for the copy):

```bash
make install
make install-system
make uninstall
make uninstall-system
```

### Using Go Install

```bash
go install github.com/carlosrabelo/ttdaid/ttdaid/cmd/ttdaid@latest
```

## Quick Start

```bash
make build
make tui
```

## Usage

Without action flags, `ttdaid` opens the TUI. You can also apply components directly:

```bash
ttdaid --list                              # short + full names
ttdaid --install qemu,libvirt,sdl          # short names
ttdaid --install virt                      # whole group
ttdaid --install virt-qemu --dry-run
ttdaid --uninstall qemu
```

`--install` / `--uninstall` only touch the listed components (they do not wipe the rest of the checklist). Always-run bash setup still runs on every apply.

### Keys

| Key | Action |
|-----|--------|
| **D** | Detect |
| **A** | Apply (Y/N if uninstalls are planned) |
| **R** | Dry-run |
| **I** | Info (packages / steps for the selected item) |
| **X** | Cancel running Apply |
| **PgUp** / **PgDn** | Scroll Output |
| **Q** / **Esc** | Quit (cancels Apply first; Ctrl+C force) |
| **↑/↓** / **j/k** | Move |
| **Space** / **Enter** | Toggle |

## Project Layout

```
ttdaid/cmd/ttdaid/                         # Go entry point
ttdaid/internal/                           # Private packages
ttdaid/distros/debian/trixie/scripts/      # Component scripts (<group>-<name>.sh)
ttdaid/distros/debian/trixie/files/bash/   # Snippets for ~/.bashrc, ~/.profile, …
bin/                                       # Compiled binaries (git-ignored)
.make/                                     # Build and install scripts
```

Future distros land beside Debian, e.g. `ttdaid/distros/ubuntu/noble/`.

### Bash policy (`system-bash`, always-run)

Not a TUI checklist item. Every Apply runs `system-bash` install (idempotent) to keep snippets current.

1. If `~/.bashrc` or `~/.profile` is missing → copy from `/etc/skel` (Debian stock).
2. Never replace an existing stock file wholesale.
3. Append/update only `# >>> ttdaid …` blocks from `files/bash/`:
   - PATH lives in `~/.config/ttdaid/env.sh` (sourced by `.profile` and `.bashrc`)
   - `.bashrc` → `~/.bash_extras` + env.sh (so desktop terminals get PATH)
   - `.bash_aliases` / `.bash_extras` → TTDAID-owned additions (skel has no copies)

## Development

```bash
make setup               # Download and tidy Go module dependencies
make build               # Compile binary to bin/ttdaid
make test                # Run all tests
make quality             # Format, vet, and lint
make tui                 # DISTRO=debian RELEASE=trixie
make install             # Install binary to ~/.local/bin
make install-system      # Install binary to /usr/local/bin
make uninstall           # Remove from ~/.local/bin
make uninstall-system    # Remove from /usr/local/bin
```

More detail: [docs/GUIDE.md](docs/GUIDE.md) · [docs/GUIDE-PT.md](docs/GUIDE-PT.md)

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.
