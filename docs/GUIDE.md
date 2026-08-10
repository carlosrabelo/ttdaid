# TTDAID - Detailed Guide

## Make Targets

| Target | Description |
|--------|-------------|
| `make setup` | Download Go module dependencies |
| `make build` | Build `bin/ttdaid` |
| `make tui` | Open the Bubble Tea checklist (Detect + Apply) |
| `make test` | Run `go test ./...` |
| `make quality` | Format, vet, and test |
| `make install` | Build as user, install to `~/.local/bin` |
| `make install-system` | Build as user, copy to `/usr/local/bin` (sudo only for install) |
| `make uninstall` | Remove from `~/.local/bin` and `/usr/local/bin` |
| `make help` | Show usage summary |

Product entrypoint is `bin/ttdaid`: no flags → TUI; `--install` / `--uninstall` → headless Apply. There is no remote SSH path and no Make targets for component install/uninstall (use the binary or TUI).

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DISTRO` | `debian` | Distribution under `distros/` |
| `RELEASE` | `trixie` | Release/codename under `distros/<distro>/` |
| `DEBIAN_VERSION` | — | Legacy alias for `RELEASE` |

## How the TUI works

1. Opens with Detect (marks what looks installed)
2. You adjust the checklist
3. **Apply** syncs:
   - checked + missing → `*.sh install`
   - unchecked + present → `*.sh uninstall`
4. **Dry-run** previews the same plan without changes

Groups (toggle via section headers): `system`, `editors`, `languages`, `gamedev`, `containers`, `desktop`, `ai`, `virt`, `ops`, `embedded`  
Aliases: `development` → editors+languages+gamedev · `devtools` → languages+containers · `network` → ops

Catalog source of truth: `ttdaid/internal/catalog`.

## Component scripts

Each component is `distros/debian/trixie/scripts/<group>-<name>.sh` with `install` / `uninstall`. Run directly if needed:

```bash
sudo bash distros/debian/trixie/scripts/containers-docker.sh install
DRY_RUN=true sudo bash distros/debian/trixie/scripts/languages-node.sh install
```

## Bash dotfiles (`system-bash`, always-run)

Not a checklist component. Apply always runs `install` for this script so PATH/aliases stay injected.

Templates live in `distros/debian/trixie/files/bash/` and are **snippets**, not full replacements.

1. Missing `~/.bashrc` / `~/.profile` → copy from `/etc/skel` first.
2. Inject/update only marked blocks (`# >>> ttdaid … start >>>` … `end <<<`).
3. Uninstall removes those blocks; stock files stay.

| File | Role |
|------|------|
| `.bashrc` | Stock Debian + `~/.bash_extras` + loads `~/.config/ttdaid/env.sh` (PATH) |
| `.profile` | Stock Debian + loader for `~/.config/ttdaid/env.sh` (login shells) |
| `~/.config/ttdaid/env.sh` | Canonical PATH (`~/bin`, `~/.local/bin`, Go, tool bins, …) |
| `.bash_aliases` | TTDAID aliases (sourced by stock `.bashrc`) |
| `.bash_extras` | Prompt / interactive extras |

## Troubleshooting

### sudo password / keys stop working after Apply

The TUI caches sudo with `sudo -v` (briefly leaves the alt screen). Prefer passwordless sudo (`system-sudoers` component) or run `sudo -v` beforehand.

### Flatpak apps missing after Apply

Ensure Flathub is configured (mark `flatpak` and Apply) and reload the session.

### npm globals / `ttdaid` not found in a new terminal

Desktop terminals are usually non-login (they read `~/.bashrc`, which loads `env.sh`). Open a new tab or:

```bash
source ~/.config/ttdaid/env.sh
npm config get prefix   # expect ~/.npm-global
command -v ttdaid
```

### Docker permission denied

```bash
newgrp docker
```

## License

MIT — see [LICENSE](../LICENSE).
