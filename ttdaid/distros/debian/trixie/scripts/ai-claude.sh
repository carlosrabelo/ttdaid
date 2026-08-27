#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing Claude Code (native installer)"

  # Official: https://code.claude.com/docs/en/install
  # curl -fsSL https://claude.ai/install.sh | bash → ~/.local/bin/claude
  if [[ "${DRY_RUN}" != "true" ]] && {
    command -v claude &>/dev/null || [[ -x "${MAIN_HOME}/.local/bin/claude" ]]
  }; then
    log_ok "Claude already installed — skipping."
    return 0
  fi

  if [[ "${DRY_RUN}" != "true" ]]; then
    if [[ $EUID -eq 0 ]]; then
      sudo -u "${MAIN_USER}" bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
    else
      bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
    fi
  else
    log_info "[DRY-RUN] curl -fsSL https://claude.ai/install.sh | bash"
  fi

  # Drop installer export PATH=… lines; ~/.local/bin is already in stock .profile.
  strip_ad_hoc_tool_path_rc

  log_ok "Claude Code installed."
}

uninstall() {

  log_step "Removing Claude Code"

  local claude_bin="${MAIN_HOME}/.local/bin/claude"
  local found=false

  if [[ -e "${claude_bin}" || -L "${claude_bin}" ]]; then
    found=true
  else
    claude_bin=$(sudo -u "${MAIN_USER}" which claude 2>/dev/null || true)
    [[ -n "${claude_bin}" ]] && found=true
  fi

  if [[ "${found}" != "true" ]]; then
    log_info "Claude binary not found — nothing to remove."
    return 0
  fi

  if [[ "${DRY_RUN}" != "true" ]]; then
    rm -f "${claude_bin}"
    log_info "Removed: ${claude_bin}"
  else
    log_info "[DRY-RUN] rm -f ${claude_bin}"
  fi

  strip_ad_hoc_tool_path_rc
  log_ok "Claude Code removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
