#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing OpenCode (native installer)"

  if [[ "${DRY_RUN}" != "true" ]] && { command -v opencode &>/dev/null || [[ -x "${MAIN_HOME}/.opencode/bin/opencode" ]]; }; then
    log_info "OpenCode already installed — ensuring profile PATH."
    ensure_profile_tool_bin opencode '.opencode/bin'
    log_ok "OpenCode already installed — skipping."
    return 0
  fi

  # Official: https://opencode.ai/docs — curl|bash → ~/.opencode/bin
  # --no-modify-path: PATH owned by ensure_profile_tool_bin / env.sh
  if [[ "${DRY_RUN}" != "true" ]]; then
    if [[ $EUID -eq 0 ]]; then
      sudo -u "${MAIN_USER}" bash -c 'curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path'
    else
      bash -c 'curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path'
    fi
  else
    log_info "[DRY-RUN] curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path"
  fi

  ensure_profile_tool_bin opencode '.opencode/bin'
  log_ok "OpenCode installed."
}

uninstall() {

  log_step "Removing OpenCode"

  local opencode_dir="${MAIN_HOME}/.opencode"
  local opencode_bin
  opencode_bin=$(sudo -u "${MAIN_USER}" which opencode 2>/dev/null || true)
  [[ -z "${opencode_bin}" && -x "${opencode_dir}/bin/opencode" ]] && opencode_bin="${opencode_dir}/bin/opencode"

  if [[ "${DRY_RUN}" != "true" ]]; then
    if [[ -n "${opencode_bin}" && -e "${opencode_bin}" ]]; then
      rm -f "${opencode_bin}"
      log_info "Removed: ${opencode_bin}"
    fi
    if [[ -d "${opencode_dir}" ]]; then
      rm -rf "${opencode_dir}"
      log_info "Removed: ${opencode_dir}"
    elif [[ -z "${opencode_bin}" ]]; then
      log_info "OpenCode not found — nothing to remove."
    fi
  else
    log_info "[DRY-RUN] rm -f ${opencode_bin:-<opencode>} ; rm -rf ${opencode_dir}"
  fi

  remove_profile_tool_bin opencode
  log_ok "OpenCode removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
