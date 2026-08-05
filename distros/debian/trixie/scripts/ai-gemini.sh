#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing Gemini CLI (npm global)"

  # Official: https://geminicli.com/docs/get-started/installation
  # npm install -g @google/gemini-cli → ~/.npm-global/bin/gemini (our prefix)
  if [[ "${DRY_RUN}" != "true" ]] && ! command -v npm &>/dev/null; then
    log_error "npm not found — install the languages-node component first."
    exit 1
  fi

  if [[ "${DRY_RUN}" != "true" ]] && npm_global_installed "@google/gemini-cli"; then
    ensure_profile_tool_bin npm-global '.npm-global/bin'
    log_ok "Gemini CLI already installed — skipping."
    return 0
  fi

  npm_global @google/gemini-cli@latest
  ensure_profile_tool_bin npm-global '.npm-global/bin'
  log_ok "Gemini CLI installed."
}

uninstall() {

  log_step "Removing Gemini CLI"
  npm_global_remove @google/gemini-cli
  log_ok "Gemini CLI removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
