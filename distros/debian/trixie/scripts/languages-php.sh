#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing PHP development packages"
  apt_install php-cli php-gd php-imagick php-mysql php-snmp
  log_ok "PHP development packages installed."
}

uninstall() {

  log_step "Removing PHP development packages"
  apt_remove php-cli php-gd php-imagick php-mysql php-snmp
  log_ok "PHP development packages removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
