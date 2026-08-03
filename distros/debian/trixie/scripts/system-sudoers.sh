#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

# Managed drop-in (does not touch hand-made files like /etc/sudoers.d/<user>).
DEST="/etc/sudoers.d/99-ttdaid-nopasswd"


install() {

  log_step "Configuring passwordless sudo for current user"

  get_main_user

  if [[ "${MAIN_USER}" == "root" ]]; then
    log_warn "MAIN_USER is root — skipping sudoers drop-in."
    return 0
  fi

  # Validate username (sudoers-safe: must look like a normal account name).
  if [[ ! "${MAIN_USER}" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    log_error "Refusing to write sudoers for unsafe username: ${MAIN_USER}"
    exit 1
  fi

  local line="${MAIN_USER} ALL=(ALL) NOPASSWD: ALL"
  local tmp
  tmp="$(mktemp)"

  cat > "${tmp}" <<DROPIN
# Managed by TTDAID — passwordless sudo for the installing user
${line}
DROPIN

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] would install ${DEST} with:"
    log_info "[DRY-RUN]   ${line}"
    rm -f "${tmp}"
    log_ok "sudoers dry-run complete."
    return 0
  fi

  if ! visudo -cf "${tmp}" >/dev/null 2>&1; then
    log_error "Generated sudoers content failed visudo validation"
    rm -f "${tmp}"
    exit 1
  fi

  command install -m 440 "${tmp}" "${DEST}"
  rm -f "${tmp}"

  if ! visudo -cf "${DEST}" >/dev/null 2>&1; then
    log_error "Installed ${DEST} failed validation — removing it"
    rm -f "${DEST}"
    exit 1
  fi

  log_info "Installed ${DEST}"
  log_info "Rule: ${line}"
  log_ok "Passwordless sudo configured for '${MAIN_USER}'."
}

uninstall() {

  log_step "Removing TTDAID sudoers drop-in"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] rm -f ${DEST}"
    log_ok "sudoers dry-run complete."
    return 0
  fi

  if [[ -f "${DEST}" ]]; then
    rm -f "${DEST}"
    log_info "Removed ${DEST}"
  else
    log_info "No TTDAID sudoers drop-in found — nothing to remove."
  fi

  log_ok "TTDAID sudoers configuration removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
