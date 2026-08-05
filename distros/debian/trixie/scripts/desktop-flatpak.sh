#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing Flatpak"
  apt_install flatpak gnome-software-plugin-flatpak
  ensure_flathub
  log_ok "Flatpak installed (Flathub remote configured)."
}

uninstall() {

  log_step "Removing Flatpak"
  apt_remove flatpak gnome-software-plugin-flatpak
  log_ok "Flatpak removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
