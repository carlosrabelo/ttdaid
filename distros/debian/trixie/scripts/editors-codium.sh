#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing VSCodium (apt repo)"

  apt_install wget gpg apt-transport-https

  run_cmd mkdir -p /usr/share/keyrings
  run_cmd mkdir -p /etc/apt/sources.list.d

  if [[ "${DRY_RUN}" != "true" ]]; then
    wget -qO- https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
      | gpg --dearmor -o /usr/share/keyrings/vscodium-archive-keyring.gpg
    chmod a+r /usr/share/keyrings/vscodium-archive-keyring.gpg

    echo "deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main" \
      | tee /etc/apt/sources.list.d/vscodium.list > /dev/null
  else
    log_info "[DRY-RUN] Would download VSCodium GPG key and add repository"
  fi

  apt_update
  apt_install codium

  log_ok "VSCodium installed."
}

uninstall() {

  log_step "Uninstalling VSCodium"
  apt_remove codium
  run_cmd rm -f /etc/apt/sources.list.d/vscodium.list
  run_cmd rm -f /usr/share/keyrings/vscodium-archive-keyring.gpg
  log_ok "VSCodium removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
