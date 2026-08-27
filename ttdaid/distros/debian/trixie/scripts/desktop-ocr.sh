#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing Tesseract OCR"
  apt_install tesseract-ocr tesseract-ocr-por
  log_ok "Tesseract OCR installed."
}

uninstall() {

  log_step "Removing Tesseract OCR"
  apt_remove tesseract-ocr tesseract-ocr-por
  log_ok "Tesseract OCR removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
