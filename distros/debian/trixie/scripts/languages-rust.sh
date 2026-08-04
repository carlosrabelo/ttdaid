#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

_rust_installed() {
  [[ -x "${MAIN_HOME}/.cargo/bin/rustc" ]] || [[ -x "${MAIN_HOME}/.cargo/bin/rustup" ]]
}

_run_as_user() {
  if [[ $EUID -eq 0 ]]; then
    sudo -u "${MAIN_USER}" "$@"
  else
    "$@"
  fi
}


install() {

  log_step "Installing Rust (rustup)"

  apt_install curl ca-certificates

  if [[ "${DRY_RUN}" != "true" ]] && _rust_installed; then
    log_info "Rust already installed — ensuring profile PATH."
    ensure_profile_tool_bin cargo '.cargo/bin'
    log_ok "Rust already installed — skipping."
    return 0
  fi

  if [[ "${DRY_RUN}" != "true" ]]; then
    # -y: unattended; --no-modify-path: PATH owned by this component in env.sh.
    _run_as_user bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path"
    ensure_profile_tool_bin cargo '.cargo/bin'
    if [[ -x "${MAIN_HOME}/.cargo/bin/rustc" ]]; then
      log_ok "Rust installed: $("${MAIN_HOME}/.cargo/bin/rustc" --version)"
    else
      log_ok "Rust installed."
    fi
  else
    log_info "[DRY-RUN] curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path"
    ensure_profile_tool_bin cargo '.cargo/bin'
    log_ok "Rust installed."
  fi
}

uninstall() {

  log_step "Removing Rust (rustup)"

  local rustup_bin="${MAIN_HOME}/.cargo/bin/rustup"
  local cargo_dir="${MAIN_HOME}/.cargo"
  local rustup_dir="${MAIN_HOME}/.rustup"

  if [[ "${DRY_RUN}" != "true" ]]; then
    if [[ -x "${rustup_bin}" ]]; then
      _run_as_user "${rustup_bin}" self uninstall -y
      log_info "Ran: rustup self uninstall -y"
    elif [[ -d "${cargo_dir}" ]] || [[ -d "${rustup_dir}" ]]; then
      rm -rf "${cargo_dir}" "${rustup_dir}"
      log_info "Removed ${cargo_dir} and/or ${rustup_dir}"
    else
      log_info "Rust not found — nothing to remove."
    fi
  else
    log_info "[DRY-RUN] rustup self uninstall -y (or rm -rf ${cargo_dir} ${rustup_dir})"
  fi

  remove_profile_tool_bin cargo

  log_ok "Rust removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
