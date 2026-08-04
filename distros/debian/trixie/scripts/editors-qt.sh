#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing Qt 6 development packages"
  apt_install qtcreator qt6-base-dev qt6-declarative-dev qt6-tools-dev
  log_ok "Qt 6 development packages installed."
}

uninstall() {

  log_step "Removing Qt 6 development packages"
  apt_remove qtcreator qt6-base-dev qt6-declarative-dev qt6-tools-dev
  log_ok "Qt 6 development packages removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
