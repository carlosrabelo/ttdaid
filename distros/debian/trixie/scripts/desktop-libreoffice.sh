#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing LibreOffice (apt)"
  apt_install libreoffice
  log_ok "LibreOffice installed."
}

uninstall() {

  log_step "Uninstalling LibreOffice"
  apt_remove libreoffice
  log_ok "LibreOffice removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
