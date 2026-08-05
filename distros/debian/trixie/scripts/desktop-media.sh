#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing media packages"

  apt_install \
    vlc audacity lmms ffmpeg libspeechd2

  log_ok "Media packages installed."
}

uninstall() {

  log_step "Uninstalling media packages"

  apt_remove \
    vlc audacity lmms ffmpeg libspeechd2

  log_ok "Media packages uninstalled."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
