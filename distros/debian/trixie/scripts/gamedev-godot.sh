#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing Godot Engine"

  if ! command -v curl &>/dev/null; then
    apt_install curl
  fi

  if ! command -v unzip &>/dev/null; then
    apt_install unzip
  fi

  # Dry-run must not touch the network (tag resolve + ~80MB zip).
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would fetch latest Godot from GitHub and install to /usr/local/bin/godot"
    log_ok "Godot installed."
    return 0
  fi

  log_info "Fetching latest Godot release…"
  # Avoid api.github.com — unauthenticated rate limit (60/h) is easy to burn
  # (and returns 403). Resolve the tag via the HTML "releases/latest" redirect.
  local curl_ua=( -A "ttdaid/godot" )
  local tag url_effective
  url_effective=$(curl -fsSLI "${curl_ua[@]}" --connect-timeout 15 --max-time 60 \
    -o /dev/null -w '%{url_effective}' \
    "https://github.com/godotengine/godot/releases/latest")
  tag="${url_effective%/}"
  tag="${tag##*/}"

  if [[ -z "${tag}" || "${tag}" == "latest" ]]; then
    log_error "Could not determine latest Godot version from GitHub releases page"
    exit 1
  fi

  local version="${tag%-stable}"
  local filename="Godot_v${version}-stable_linux.x86_64.zip"
  local url="https://github.com/godotengine/godot/releases/download/${tag}/${filename}"

  local tmpdir
  tmpdir=$(mktemp -d)
  local zip_path="${tmpdir}/${filename}"

  # No curl -#: progress uses \r and the TUI line reader never advances.
  # Zip is large (~80MB+); emit start/end so Apply does not look wedged.
  log_info "Downloading Godot ${version} from GitHub (large zip, may take a while)…"
  curl -fL "${curl_ua[@]}" --connect-timeout 15 --retry 3 --retry-delay 2 \
    "${url}" -o "${zip_path}"
  log_info "Download complete ($(du -h "${zip_path}" | cut -f1))."

  log_info "Extracting…"
  unzip -q "${zip_path}" -d "${tmpdir}"

  local binary_path="${tmpdir}/Godot_v${version}-stable_linux.x86_64"

  # Must use `command install` — this script defines install(), which would
  # recurse forever if we call bare `install` (coreutils).
  if [[ ! -f "${binary_path}" ]]; then
    log_error "Binary not found after extraction"
    rm -rf "${tmpdir}"
    exit 1
  fi

  command install -m 0755 "${binary_path}" /usr/local/bin/godot
  rm -rf "${tmpdir}"

  # Never run bare `godot --version`: it can init the display and hang the TUI.
  local ver
  ver=$(timeout 10 godot --headless --version 2>/dev/null || true)
  if [[ -n "${ver}" ]]; then
    log_ok "Godot installed: ${ver}"
  else
    log_ok "Godot ${version} installed at /usr/local/bin/godot"
  fi
}

uninstall() {

  log_step "Removing Godot Engine"

  if [[ -f /usr/local/bin/godot ]]; then
    run_cmd rm -f /usr/local/bin/godot
    log_ok "Godot removed."
  else
    log_info "Godot is not installed — nothing to do."
  fi
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
