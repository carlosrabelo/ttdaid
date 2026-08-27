#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing PostgreSQL"
  apt_install postgresql-client
  log_ok "PostgreSQL installed."
}

uninstall() {

  log_step "Removing PostgreSQL"
  apt_remove postgresql-client
  log_ok "PostgreSQL removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
