#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing libvirt"
  apt_install libvirt-clients libvirt-daemon-system libvirt-dev
  log_ok "libvirt installed."
}

uninstall() {

  log_step "Removing libvirt"
  apt_remove libvirt-clients libvirt-daemon-system libvirt-dev
  log_ok "libvirt removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
