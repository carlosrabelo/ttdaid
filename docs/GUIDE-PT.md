# TTDAID - Guia Detalhado

## Targets do Make

| Target | Descrição |
|--------|-----------|
| `make setup` | Baixa dependências do módulo Go |
| `make build` | Compila `bin/ttdaid` |
| `make tui` | Abre o checklist Bubble Tea (Detect + Apply) |
| `make test` | Roda `go test ./...` |
| `make quality` | Formata, vet e testa |
| `make install` | Build como usuário, instala em `~/.local/bin` |
| `make install-system` | Build como usuário, copia para `/usr/local/bin` (sudo só no install) |
| `make uninstall` | Remove de `~/.local/bin` e `/usr/local/bin` |
| `make help` | Mostra resumo de uso |

Entrypoint do produto é `bin/ttdaid`: sem flags → TUI; `--install` / `--uninstall` → Apply headless. Não há path remoto SSH nem targets Make de install/uninstall de componentes (use o binário ou a TUI).

## Variáveis

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `DISTRO` | `debian` | Distribuição sob `distros/` |
| `RELEASE` | `trixie` | Release/codinome sob `distros/<distro>/` |
| `DEBIAN_VERSION` | — | Alias legado de `RELEASE` |

## Como a TUI funciona

1. Abre com Detect (marca o que parece instalado)
2. Você ajusta o checklist
3. **Apply** sincroniza:
   - marcado + ausente → `*.sh install`
   - desmarcado + presente → `*.sh uninstall`
4. **Dry-run** mostra o plano sem alterar nada

Grupos (toggle pelos cabeçalhos): `system`, `editors`, `languages`, `gamedev`, `containers`, `desktop`, `ai`, `virt`, `ops`, `embedded`  
Aliases: `development` → editors+languages+gamedev · `devtools` → languages+containers · `network` → ops

Fonte do catálogo: `ttdaid/internal/catalog`.

## Scripts de componente

Cada componente é `distros/debian/trixie/scripts/<grupo>-<nome>.sh` com `install` / `uninstall`. Direto se precisar:

```bash
sudo bash distros/debian/trixie/scripts/containers-docker.sh install
DRY_RUN=true sudo bash distros/debian/trixie/scripts/languages-node.sh install
```

## Dotfiles bash (`system-bash`, always-run)

Não é componente do checklist. O Apply sempre roda `install` neste script para manter PATH/aliases injetados.

Os templates em `distros/debian/trixie/files/bash/` são **snippets**, não substitutos completos.

1. Se faltar `~/.bashrc` / `~/.profile` → copia de `/etc/skel` primeiro.
2. Só injeta/atualiza blocos marcados (`# >>> ttdaid … start >>>` … `end <<<`).
3. Uninstall remove esses blocos; os arquivos stock permanecem.

| Arquivo | Papel |
|---------|--------|
| `.bashrc` | Stock Debian + `~/.bash_extras` + carrega `~/.config/ttdaid/env.sh` (PATH) |
| `.profile` | Stock Debian + loader de `~/.config/ttdaid/env.sh` (login) |
| `~/.config/ttdaid/env.sh` | PATH canônico (`~/bin`, `~/.local/bin`, Go, bins de tools, …) |
| `.bash_aliases` | Aliases TTDAID (já sourced pelo `.bashrc` stock) |
| `.bash_extras` | Prompt / extras interativos |

## Solução de problemas

### sudo / teclas após Apply

A TUI faz cache com `sudo -v` (sai brevemente da alt-screen). Prefira sudo sem senha (componente `system-sudoers`) ou rode `sudo -v` antes.

### Apps Flatpak faltando

Marque `flatpak`, Apply, e recarregue a sessão.

### npm globais / `ttdaid` não encontrados num terminal novo

Terminais desktop costumam ser non-login (leem `~/.bashrc`, que carrega `env.sh`). Abra um novo tab ou:

```bash
source ~/.config/ttdaid/env.sh
npm config get prefix   # esperado: ~/.npm-global
command -v ttdaid
```

### Docker permission denied

```bash
newgrp docker
```

## Licença

MIT — veja [LICENSE](../LICENSE).
