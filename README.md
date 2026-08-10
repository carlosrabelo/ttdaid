# TTDAID

**Things To Do After Installing Debian** — for **Debian 13 (Trixie)** today; layout ready for more distros.

Interactive Bubble Tea TUI that syncs a checklist of bash component scripts: detect what is already there, then Apply to install or remove.

## Highlights

- Checklist with Detect on open and one **Apply** (checked → install, unchecked → uninstall)
- Apply asks **Y/N** when the plan includes uninstalls
- Groups: `system`, `editors`, `languages`, `gamedev`, `containers`, `desktop`, `ai`, `virt`, `ops`, `embedded`
- Components are `distros/<distro>/<release>/scripts/<group>-<name>.sh` (`install` / `uninstall`)
- No Snap — APT, official `.deb` repos, or Flatpak/Flathub
- Dry-run Apply to preview without changing the system
- Always-run bash setup keeps Debian’s stock `~/.bashrc` / `~/.profile` and only injects marked blocks

## Prerequisites

- Debian 13 (Trixie) for the current component tree
- Go 1.22+ (to build from source)
- `sudo` for real Apply (`system-sudoers` or run `sudo -v` when prompted)

## Quick start

```bash
git clone https://github.com/carlosrabelo/ttdaid.git
cd ttdaid
make setup
make tui
```

Optional: `make install` → `~/.local/bin`; `make install-system` → `/usr/local/bin` (sudo only for the copy).

## CLI

Without action flags, `ttdaid` opens the TUI. You can also apply components directly:

```bash
ttdaid --list                              # short + full names
ttdaid --install qemu,libvirt,sdl          # short names
ttdaid --install virt                      # whole group
ttdaid --install virt-qemu --dry-run
ttdaid --uninstall qemu
```

`--install` / `--uninstall` only touch the listed components (they do not wipe the rest of the checklist). Always-run bash setup still runs on every apply.

## Keys

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

## Layout

```
ttdaid/                              # Go sources (cmd/ + internal/)
distros/debian/trixie/scripts/       # Component scripts (<group>-<name>.sh)
distros/debian/trixie/files/bash/    # Snippets for ~/.bashrc, ~/.profile, …
.make/                               # build, test, install
go.mod
```

Future distros land beside Debian, e.g. `distros/ubuntu/noble/`.

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
make setup      # go mod download/tidy
make test
make quality    # format, vet, test
make build      # bin/ttdaid (embeds distros/)
make tui        # DISTRO=debian RELEASE=trixie
```

More detail: [docs/GUIDE.md](docs/GUIDE.md) · [docs/GUIDE-PT.md](docs/GUIDE-PT.md)

## License

MIT — see [LICENSE](LICENSE).
