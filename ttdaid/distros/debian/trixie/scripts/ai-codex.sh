#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing Codex (native installer)"

  if [[ "${DRY_RUN}" != "true" ]] && {
    command -v codex &>/dev/null || [[ -x "${MAIN_HOME}/.local/bin/codex" ]]
  }; then
    log_ok "Codex already installed — skipping."
    return 0
  fi

  # Official: https://github.com/openai/codex — curl|sh → ~/.local/bin/codex
  # CODEX_NON_INTERACTIVE skips prompts for TUI/CI apply.
  if [[ "${DRY_RUN}" != "true" ]]; then
    if [[ $EUID -eq 0 ]]; then
      sudo -u "${MAIN_USER}" env CODEX_NON_INTERACTIVE=1 \
        bash -c 'curl -fsSL https://chatgpt.com/codex/install.sh | sh'
    else
      CODEX_NON_INTERACTIVE=1 bash -c 'curl -fsSL https://chatgpt.com/codex/install.sh | sh'
    fi
  else
    log_info "[DRY-RUN] CODEX_NON_INTERACTIVE=1 curl -fsSL https://chatgpt.com/codex/install.sh | sh"
  fi

  # Drop installer export PATH=… lines; ~/.local/bin is already in stock .profile.
  strip_ad_hoc_tool_path_rc

  log_ok "Codex installed."
}

uninstall() {

  log_step "Removing Codex"

  local codex_bin="${MAIN_HOME}/.local/bin/codex"
  local host_bin="${MAIN_HOME}/.local/bin/codex-code-mode-host"
  local found=false

  if [[ -e "${codex_bin}" || -L "${codex_bin}" ]]; then
    found=true
  else
    codex_bin=$(sudo -u "${MAIN_USER}" which codex 2>/dev/null || true)
    [[ -n "${codex_bin}" ]] && found=true
  fi

  if [[ "${found}" != "true" ]]; then
    log_info "Codex not found — nothing to remove."
    return 0
  fi

  if [[ "${DRY_RUN}" != "true" ]]; then
    rm -f "${codex_bin}" "${host_bin}"
    log_info "Removed: ${codex_bin}"
  else
    log_info "[DRY-RUN] rm -f ${codex_bin} ${host_bin}"
  fi

  strip_ad_hoc_tool_path_rc
  log_ok "Codex removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
