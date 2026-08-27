#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing LaTeX"

  apt_install \
    texlive texlive-lang-portuguese texlive-latex-extra texlive-publishers \
    texstudio texstudio-doc texstudio-l10n

  log_ok "LaTeX installed."
}

uninstall() {

  log_step "Uninstalling LaTeX"

  apt_remove \
    texlive texlive-lang-portuguese texlive-latex-extra texlive-publishers \
    texstudio texstudio-doc texstudio-l10n

  log_ok "LaTeX uninstalled."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
