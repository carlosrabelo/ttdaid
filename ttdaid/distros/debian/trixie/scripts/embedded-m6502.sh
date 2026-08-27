#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing 6502 development tools"
  apt_install cc65 xa65
  log_ok "6502 tools installed."
}

uninstall() {

  log_step "Removing 6502 development tools"
  apt_remove cc65 xa65
  log_ok "6502 tools removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
