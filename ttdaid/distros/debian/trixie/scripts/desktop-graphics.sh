#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing graphics packages"

  # Accept Microsoft core fonts EULA non-interactively (contrib package).
  if [[ "${DRY_RUN}" != "true" ]]; then
    echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" \
      | debconf-set-selections
  else
    log_info "[DRY-RUN] debconf-set-selections for ttf-mscorefonts-installer EULA"
  fi

  apt_install \
    gimp inkscape imagemagick \
    xfonts-75dpi xfonts-100dpi \
    fontconfig ttf-mscorefonts-installer

  log_ok "Graphics packages installed."
}

uninstall() {

  log_step "Uninstalling graphics packages"

  # Keep fontconfig — shared desktop dependency.
  apt_remove \
    gimp inkscape imagemagick \
    xfonts-75dpi xfonts-100dpi \
    ttf-mscorefonts-installer

  log_ok "Graphics packages uninstalled."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
