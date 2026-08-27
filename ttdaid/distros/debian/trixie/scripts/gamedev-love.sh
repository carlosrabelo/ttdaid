#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing LÖVE (Love2D)"
  apt_install love
  log_ok "LÖVE installed."
}

uninstall() {

  log_step "Removing LÖVE (Love2D)"
  apt_remove love
  log_ok "LÖVE removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
