#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

install() {

  log_step "Installing Docker (apt)"

  # Prerequisites
  apt_install apt-transport-https ca-certificates curl gnupg lsb-release

  if [[ "${DRY_RUN}" != "true" ]]; then
    # Detect architecture
    local arch
    arch=$(dpkg --print-architecture)

    # GPG key
    run_cmd mkdir -p /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/debian/gpg" \
      | gpg --dearmor -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Repository
    local codename
    codename=$(. /etc/os-release && echo "${VERSION_CODENAME}")
    # Remove potential deb822-format duplicate to avoid APT warnings
    run_cmd rm -f /etc/apt/sources.list.d/docker.sources
    echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${codename} stable" \
      | tee /etc/apt/sources.list.d/docker.list > /dev/null
  else
    log_info "[DRY-RUN] Would download GPG key and add Docker repository"
  fi

  apt_update
  apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Add user to docker group
  run_cmd usermod -aG docker "${MAIN_USER}"
  log_info "User '${MAIN_USER}' added to docker group."

  # Enable service
  enable_service docker

  # Verify installation
  if [[ "${DRY_RUN}" != "true" ]]; then
    log_info "Installed: $(docker --version)"
    if docker run --rm hello-world &>/dev/null; then
      log_ok "Docker OK (hello-world ran successfully)."
    else
      log_warn "hello-world failed — you may need to re-login for the docker group to apply."
    fi
  fi

  log_ok "Docker installed."
}

uninstall() {

  log_step "Removing Docker"

  # Remove user from docker group
  if getent group docker &>/dev/null; then
    if id -nG "${MAIN_USER}" | grep -qw docker; then
      run_cmd gpasswd -d "${MAIN_USER}" docker || true
      log_info "User '${MAIN_USER}' removed from docker group."
    fi
  fi

  # Disable service
  disable_service docker

  # Remove packages
  apt_remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Remove repository and GPG key
  if [[ "${DRY_RUN}" != "true" ]]; then
    rm -f /etc/apt/sources.list.d/docker.list
    rm -f /etc/apt/keyrings/docker.asc
    log_info "Removed Docker repository and GPG key."
  else
    log_info "[DRY-RUN] rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.asc"
  fi

  log_ok "Docker removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
