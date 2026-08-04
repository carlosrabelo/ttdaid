#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing Distrobox"

  # Distrobox is packaged in Debian (pulls a container runtime dependency).
  apt_install distrobox

  if command -v docker &>/dev/null; then
    log_info "Docker detected — Distrobox can use it as container runtime."
  elif command -v podman &>/dev/null; then
    log_info "Podman detected — Distrobox can use it as container runtime."
  else
    log_warn "No container runtime found. Install the 'containers-docker' component or ensure podman is available."
  fi

  log_ok "Distrobox installed."
}

uninstall() {

  log_step "Removing Distrobox"
  apt_remove distrobox
  log_ok "Distrobox removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
