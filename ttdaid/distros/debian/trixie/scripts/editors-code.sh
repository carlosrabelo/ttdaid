#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing Visual Studio Code (Microsoft apt repo)"

  apt_install wget gpg apt-transport-https

  run_cmd mkdir -p /etc/apt/keyrings
  run_cmd mkdir -p /etc/apt/sources.list.d

  if [[ "${DRY_RUN}" != "true" ]]; then
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg
    chmod a+r /etc/apt/keyrings/packages.microsoft.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
      | tee /etc/apt/sources.list.d/vscode.list > /dev/null
  else
    log_info "[DRY-RUN] Would download Microsoft GPG key and add VS Code repository"
  fi

  apt_update
  apt_install code

  log_ok "VS Code installed."
}

uninstall() {

  log_step "Uninstalling Visual Studio Code"
  apt_remove code
  run_cmd rm -f /etc/apt/sources.list.d/vscode.list
  run_cmd rm -f /etc/apt/keyrings/packages.microsoft.gpg
  log_ok "VS Code removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
