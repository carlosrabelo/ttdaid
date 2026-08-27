#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing QEMU / KVM"
  apt_install qemu-kvm virt-manager bridge-utils cpu-checker
  log_ok "QEMU installed."
}

uninstall() {

  log_step "Removing QEMU / KVM"
  apt_remove qemu-kvm virt-manager bridge-utils cpu-checker
  log_ok "QEMU removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
