#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

FILES_DIR="${SCRIPTS_DIR}/../files/sysctl"
CONF_NAME="99-ttdaid-swappiness.conf"
DEST="/etc/sysctl.d/${CONF_NAME}"


install() {

  log_step "Configuring sysctl (vm.swappiness=10)"

  local src="${FILES_DIR}/${CONF_NAME}"
  if [[ ! -f "${src}" ]]; then
    log_error "Sysctl config not found: ${src}"
    exit 1
  fi

  run_cmd mkdir -p /etc/sysctl.d

  if [[ "${DRY_RUN}" != "true" ]]; then
    command install -m 644 "${src}" "${DEST}"
    log_info "Installed ${DEST}"
    sysctl -p "${DEST}"
  else
    log_info "[DRY-RUN] install -m 644 ${src} ${DEST}"
    log_info "[DRY-RUN] sysctl -p ${DEST}"
  fi

  log_ok "sysctl configured (vm.swappiness=10)."
}

uninstall() {

  log_step "Removing sysctl configuration"

  if [[ "${DRY_RUN}" != "true" ]]; then
    if [[ -f "${DEST}" ]]; then
      rm -f "${DEST}"
      log_info "Removed ${DEST}"
      sysctl --system >/dev/null 2>&1 || true
    else
      log_info "No TTDAID sysctl config found — nothing to remove."
    fi
  else
    log_info "[DRY-RUN] rm -f ${DEST}"
  fi

  log_ok "sysctl configuration removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
