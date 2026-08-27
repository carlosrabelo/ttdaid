#!/usr/bin/env bash
# node for Debian 13 Trixie
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

NODE_VERSION="${NODE_VERSION:-22.x}"
NODE_NPM_PREFIX="${MAIN_HOME}/.npm-global"
NODE_DESIRED_NPM_VERSION="${NODE_DESIRED_NPM_VERSION:-11}"

install() {

  log_step "Installing Node.js ${NODE_VERSION}"

  apt_install apt-transport-https ca-certificates curl gnupg

  run_cmd mkdir -p /usr/share/keyrings

  # NodeSource GPG key
  if [[ "${DRY_RUN}" != "true" ]]; then
    if [[ ! -f /usr/share/keyrings/nodesource.gpg ]]; then
      log_info "Downloading NodeSource GPG key..."
      curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg
      chmod 644 /usr/share/keyrings/nodesource.gpg
    else
      log_info "NodeSource GPG key already present."
    fi

    # NodeSource repository
    echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION} nodistro main" \
      | tee /etc/apt/sources.list.d/nodesource.list > /dev/null
  else
    log_info "[DRY-RUN] Would download GPG key and add NodeSource repository"
  fi

  apt_update
  apt_install nodejs build-essential python3 make g++ pkg-config

  # Enable Corepack
  run_cmd corepack enable

  # Prepare pnpm and yarn via Corepack
  if [[ "${DRY_RUN}" != "true" ]]; then
    sudo -u "${MAIN_USER}" corepack prepare pnpm@latest --activate
    sudo -u "${MAIN_USER}" corepack prepare yarn@stable --activate
  else
    log_info "[DRY-RUN] Would prepare pnpm and yarn via Corepack"
  fi

  # npm global directories
  run_cmd mkdir -p "${NODE_NPM_PREFIX}/bin" "${NODE_NPM_PREFIX}/lib/node_modules"
  run_cmd chown -R "${MAIN_USER}:${MAIN_USER}" "${NODE_NPM_PREFIX}"

  # Set npm prefix
  if [[ "${DRY_RUN}" != "true" ]]; then
    local current_prefix
    current_prefix=$(sudo -u "${MAIN_USER}" npm config get prefix 2>/dev/null || echo "")
    if [[ "${current_prefix}" != "${NODE_NPM_PREFIX}" ]]; then
      sudo -u "${MAIN_USER}" npm config set prefix "${NODE_NPM_PREFIX}"
      log_info "npm prefix set to ${NODE_NPM_PREFIX}"
    fi
  else
    log_info "[DRY-RUN] Would set npm prefix to ${NODE_NPM_PREFIX}"
  fi

  # PATH for ~/.npm-global/bin — owned by this component in env.sh.
  ensure_profile_tool_bin npm-global '.npm-global/bin'

  # Fix ~/.npm permissions
  run_cmd mkdir -p "${MAIN_HOME}/.npm"
  run_cmd chown -R "${MAIN_USER}:${MAIN_USER}" "${MAIN_HOME}/.npm" || true

  # Update npm
  if [[ "${DRY_RUN}" != "true" ]]; then
    sudo -u "${MAIN_USER}" npm i -g "npm@${NODE_DESIRED_NPM_VERSION}"
    log_ok "Node.js $(node -v) / npm $(npm -v) installed."
  else
    log_info "[DRY-RUN] Would update npm to version ${NODE_DESIRED_NPM_VERSION}"
    log_ok "Node.js installed."
  fi
}

uninstall() {

  log_step "Removing Node.js"

  apt_remove nodejs build-essential

  # Remove repository and GPG key
  if [[ "${DRY_RUN}" != "true" ]]; then
    rm -f /etc/apt/sources.list.d/nodesource.list
    rm -f /usr/share/keyrings/nodesource.gpg
    log_info "Removed NodeSource repository and GPG key."
  else
    log_info "[DRY-RUN] rm -f /etc/apt/sources.list.d/nodesource.list /usr/share/keyrings/nodesource.gpg"
  fi

  # Remove npm global directory
  local npm_global="${MAIN_HOME}/.npm-global"
  if [[ "${DRY_RUN}" != "true" ]]; then
    if [[ -d "${npm_global}" ]]; then
      rm -rf "${npm_global}"
      log_info "Removed: ${npm_global}"
    fi
  else
    log_info "[DRY-RUN] rm -rf ${npm_global}"
  fi

  remove_profile_tool_bin npm-global

  log_ok "Node.js removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
