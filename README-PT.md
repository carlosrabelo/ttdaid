# TTDAID

**Things To Do After Installing Debian** — hoje para **Debian 13 (Trixie)**; layout preparado para mais distros.

TUI Bubble Tea que sincroniza um checklist de scripts bash de componentes: detecta o que já existe e faz Apply para instalar ou remover.

## Destaques

- Checklist com Detect na abertura e um único **Apply** (marcado → instala, desmarcado → remove)
- Apply pede **Y/N** quando o plano inclui uninstalls
- Grupos: `system`, `editors`, `languages`, `gamedev`, `containers`, `desktop`, `ai`, `virt`, `ops`, `embedded`
- Componentes em `distros/<distro>/<release>/scripts/<grupo>-<nome>.sh` (`install` / `uninstall`)
- Sem Snap — APT, repositórios `.deb` oficiais ou Flatpak/Flathub
- Dry-run Apply para pré-visualizar sem alterar o sistema
- Setup bash always-run mantém o `~/.bashrc` / `~/.profile` stock e só injeta blocos marcados

## Pré-requisitos

- Debian 13 (Trixie) para a árvore de componentes atual
- Go 1.22+ (para compilar a partir do código)
- `sudo` para Apply real (`system-sudoers` ou `sudo -v` quando pedido)

## Início rápido

```bash
git clone https://github.com/carlosrabelo/ttdaid.git
cd ttdaid
make setup
make tui
```

Opcional: `make install` → `~/.local/bin`; `make install-system` → `/usr/local/bin` (sudo só na cópia).

## CLI

Sem flags de ação, `ttdaid` abre a TUI. Também dá para aplicar componentes direto:

```bash
ttdaid --list                              # nomes curtos + completos
ttdaid --install qemu,libvirt,sdl          # nomes curtos
ttdaid --install virt                      # grupo inteiro
ttdaid --install virt-qemu --dry-run
ttdaid --uninstall qemu
```

`--install` / `--uninstall` só mexem nos componentes listados (não limpam o resto do checklist). O always-run do bash ainda roda em todo apply.

## Teclas

| Tecla | Ação |
|-------|------|
| **D** | Detect |
| **A** | Apply (Y/N se houver uninstalls) |
| **R** | Dry-run |
| **I** | Info (pacotes / passos do item selecionado) |
| **X** | Cancelar Apply em andamento |
| **PgUp** / **PgDn** | Rolar Output |
| **Q** / **Esc** | Sair (cancela Apply antes; Ctrl+C força) |
| **↑/↓** / **j/k** | Mover |
| **Espaço** / **Enter** | Alternar |

## Estrutura

```
ttdaid/                              # Código Go (cmd/ + internal/)
distros/debian/trixie/scripts/       # Scripts de componente (<grupo>-<nome>.sh)
distros/debian/trixie/files/bash/    # Snippets para ~/.bashrc, ~/.profile, …
.make/                               # build, test, install
go.mod
```

Distros futuras ficam ao lado, ex.: `distros/ubuntu/noble/`.

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
make setup      # go mod download/tidy
make test
make quality    # format, vet, test
make build      # bin/ttdaid (embute distros/)
make tui        # DISTRO=debian RELEASE=trixie
```

Mais detalhes: [docs/GUIDE-PT.md](docs/GUIDE-PT.md) · [docs/GUIDE.md](docs/GUIDE.md)

## Licença

MIT — veja [LICENSE](LICENSE).
