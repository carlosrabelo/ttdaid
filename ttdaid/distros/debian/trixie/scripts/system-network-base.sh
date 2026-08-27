#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing basic network packages"
  apt_install \
    net-tools nmap openssh-server rclone rsync
  log_ok "basic network packages installed."
}

uninstall() {

  log_step "Removing basic network packages"
  apt_remove \
    net-tools nmap openssh-server rclone rsync
  log_ok "basic network packages removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
