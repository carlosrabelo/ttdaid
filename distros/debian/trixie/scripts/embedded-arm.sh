#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing GCC ARM embedded toolchain"
  apt_install gcc-arm-none-eabi
  log_ok "GCC ARM embedded toolchain installed."
}

uninstall() {

  log_step "Removing GCC ARM embedded toolchain"
  apt_remove gcc-arm-none-eabi
  log_ok "GCC ARM embedded toolchain removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
