#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing system utility packages"
  apt_install \
    btop cpu-x htop lm-sensors \
    neovim preload screen smartmontools \
    supervisor tmpreaper tree
  log_ok "system utility packages installed."
}

uninstall() {

  log_step "Removing system utility packages"
  apt_remove \
    btop cpu-x htop lm-sensors \
    neovim preload screen smartmontools \
    supervisor tmpreaper tree
  log_ok "system utility packages removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
