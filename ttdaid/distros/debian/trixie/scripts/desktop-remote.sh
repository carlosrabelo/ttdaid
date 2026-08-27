#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing Remote desktop and file transfer tools"
  apt_install remmina filezilla
  log_ok "Remote desktop and file transfer tools installed."
}

uninstall() {

  log_step "Removing Remote desktop and file transfer tools"
  apt_remove remmina filezilla
  log_ok "Remote desktop and file transfer tools removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
