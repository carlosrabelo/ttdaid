#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing SDCC (Small Device C Compiler) suite"
  apt_install sdcc sdcc-doc gputils
  log_ok "SDCC suite installed."
}

uninstall() {

  log_step "Removing SDCC (Small Device C Compiler) suite"
  apt_remove sdcc sdcc-doc gputils
  log_ok "SDCC suite removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
