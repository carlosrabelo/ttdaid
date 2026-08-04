#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing Go (apt)"

  apt_install golang-go

  # Create GOPATH workspace
  local gopath="${MAIN_HOME}/go"
  for dir in src bin pkg; do
    run_cmd mkdir -p "${gopath}/${dir}"
    run_cmd chown "${MAIN_USER}:${MAIN_USER}" "${gopath}/${dir}"
  done

  if [[ "${DRY_RUN}" != "true" ]] && command -v go &>/dev/null; then
    log_ok "Go installed: $(go version)"
  else
    log_ok "Go installed."
  fi
}

uninstall() {

  log_step "Uninstalling Go"
  apt_remove golang-go
  log_ok "Go removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
