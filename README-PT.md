# TTDAID

Checklist interativo Bubble Tea que instala e remove scripts de componentes Debian após uma instalação nova (**Things To Do After Installing Debian**). A árvore atual é Debian 13 (Trixie); o layout já admite mais distros.

## Destaques

- Checklist com Detect na abertura e um único Apply (marcado → instala, desmarcado → remove)
- Apply pede Y/N quando o plano inclui uninstalls
- Grupos: `system`, `editors`, `languages`, `gamedev`, `containers`, `desktop`, `ai`, `virt`, `ops`, `embedded`
- Componentes em `ttdaid/distros/<distro>/<release>/scripts/<grupo>-<nome>.sh` (`install` / `uninstall`)
- Sem Snap — APT, repositórios `.deb` oficiais ou Flatpak/Flathub
- Dry-run Apply para pré-visualizar sem alterar o sistema
- Setup bash always-run mantém o `~/.bashrc` / `~/.profile` stock do Debian e só injeta blocos marcados

## Pré-requisitos

- **Debian 13 (Trixie)** — árvore de componentes atual
- **Go 1.24+** — necessário para compilar a partir do código; [download](https://go.dev/dl/)
- **sudo** — necessário para Apply real (`system-sudoers` ou `sudo -v` quando pedido)

## Instalação

### Compilar a partir do código

```bash
git clone https://github.com/carlosrabelo/ttdaid.git
cd ttdaid
make setup
make build
```

Instala em `~/.local/bin` (padrão), ou em `/usr/local/bin` no sistema (sudo só na cópia):

```bash
make install
make install-system
make uninstall
make uninstall-system
```

### Via go install

```bash
go install github.com/carlosrabelo/ttdaid/ttdaid/cmd/ttdaid@latest
```

## Início Rápido

```bash
make build
make tui
```

## Uso

Sem flags de ação, `ttdaid` abre a TUI. Também dá para aplicar componentes direto:

```bash
ttdaid --list                              # short + full names
ttdaid --install qemu,libvirt,sdl          # short names
ttdaid --install virt                      # whole group
ttdaid --install virt-qemu --dry-run
ttdaid --uninstall qemu
```

`--install` / `--uninstall` só mexem nos componentes listados (não limpam o resto do checklist). O always-run do bash ainda roda em todo apply.

### Teclas

| Tecla | Ação |
|-----|--------|
| **D** | Detect |
| **A** | Apply (Y/N se houver uninstalls) |
| **R** | Dry-run |
| **I** | Info (pacotes / passos do item selecionado) |
| **X** | Cancelar Apply em andamento |
| **PgUp** / **PgDn** | Rolar Output |
| **Q** / **Esc** | Sair (cancela Apply antes; Ctrl+C força) |
| **↑/↓** / **j/k** | Mover |
| **Espaço** / **Enter** | Alternar |

## Estrutura do Projeto

```
ttdaid/cmd/ttdaid/                         # ponto de entrada Go
ttdaid/internal/                           # pacotes privados
ttdaid/distros/debian/trixie/scripts/      # scripts de componente (<grupo>-<nome>.sh)
ttdaid/distros/debian/trixie/files/bash/   # snippets para ~/.bashrc, ~/.profile, …
bin/                                       # binários compilados (git-ignored)
.make/                                     # scripts de build e install
```

Distros futuras ficam ao lado do Debian, ex.: `ttdaid/distros/ubuntu/noble/`.

### Política bash (`system-bash`, always-run)

Não é item do checklist da TUI. Cada Apply executa o `install` de `system-bash` (idempotente) para manter os snippets atualizados.

1. Se faltar `~/.bashrc` ou `~/.profile` → copia de `/etc/skel` (stock Debian).
2. Nunca substitui o arquivo stock inteiro se ele já existir.
3. Só acrescenta/atualiza blocos `# >>> ttdaid …` a partir de `files/bash/`:
   - PATH em `~/.config/ttdaid/env.sh` (sourced por `.profile` e `.bashrc`)
   - `.bashrc` → `~/.bash_extras` + env.sh (terminais desktop também pegam o PATH)
   - `.bash_aliases` / `.bash_extras` → acréscimos do TTDAID (não existem no skel)

## Desenvolvimento

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

Mais detalhes: [docs/GUIDE-PT.md](docs/GUIDE-PT.md) · [docs/GUIDE.md](docs/GUIDE.md)

## Licença

Este projeto está licenciado sob a MIT License — veja [LICENSE](LICENSE) para detalhes.
