#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing Desktop utility packages"
  apt_install meld bleachbit mc evince gnome-tweaks qrencode yadm
  log_ok "Desktop utility packages installed."
}

uninstall() {

  log_step "Removing Desktop utility packages"
  apt_remove meld bleachbit mc evince gnome-tweaks qrencode yadm
  log_ok "Desktop utility packages removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
