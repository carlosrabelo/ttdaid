#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing GitHub CLI (gh)"

  # wget/curl are only needed to fetch the GitHub apt keyring.
  if ! command -v wget &>/dev/null && ! command -v curl &>/dev/null; then
    log_info "Neither wget nor curl found — installing wget"
    apt_install wget
  fi

  run_cmd mkdir -p /etc/apt/keyrings
  run_cmd mkdir -p /etc/apt/sources.list.d

  log_info "Downloading GitHub CLI GPG key..."
  if [[ "${DRY_RUN}" != "true" ]]; then
    if command -v wget &>/dev/null; then
      wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    else
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    fi
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  else
    log_info "[DRY-RUN] Would download GPG key and add GitHub CLI repository"
  fi

  apt_update
  apt_install gh

  log_ok "GitHub CLI installed."
}

uninstall() {

  log_step "Removing GitHub CLI"

  apt_remove gh

  if [[ "${DRY_RUN}" != "true" ]]; then
    rm -f /etc/apt/sources.list.d/github-cli.list
    rm -f /etc/apt/keyrings/githubcli-archive-keyring.gpg
    log_info "Removed GitHub CLI repository and GPG key."
  else
    log_info "[DRY-RUN] rm -f /etc/apt/sources.list.d/github-cli.list /etc/apt/keyrings/githubcli-archive-keyring.gpg"
  fi

  log_ok "GitHub CLI removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
