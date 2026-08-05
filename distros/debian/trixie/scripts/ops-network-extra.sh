#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing network extra packages"

  apt_install \
    arp-scan avahi-autoipd avahi-utils \
    network-manager-l2tp network-manager-l2tp-gnome \
    network-manager-openconnect network-manager-openconnect-gnome \
    ssh-askpass sshpass gufw tor

  log_ok "Network extra packages installed."
}

uninstall() {

  log_step "Uninstalling network extra packages"

  apt_remove \
    arp-scan avahi-autoipd avahi-utils \
    network-manager-l2tp network-manager-l2tp-gnome \
    network-manager-openconnect network-manager-openconnect-gnome \
    ssh-askpass sshpass gufw tor

  log_ok "Network extra packages uninstalled."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
