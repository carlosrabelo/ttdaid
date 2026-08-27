#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing Z80 development tools"
  apt_install z80asm z80dasm
  log_ok "Z80 tools installed."
}

uninstall() {

  log_step "Removing Z80 development tools"
  apt_remove z80asm z80dasm
  log_ok "Z80 tools removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
