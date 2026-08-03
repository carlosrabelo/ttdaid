#!/usr/bin/env bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

FILES_DIR="${SCRIPTS_DIR}/../files/bash"
SKEL_DIR="/etc/skel"

# Seed missing Debian stock files from /etc/skel (never overwrite existing).
seed_from_skel() {
  local name="$1"
  local dest="${MAIN_HOME}/${name}"
  local src="${SKEL_DIR}/${name}"

  if [[ -f "${dest}" ]]; then
    return 0
  fi
  if [[ ! -f "${src}" ]]; then
    log_warn "No ${src} to seed ${dest} — creating empty file"
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] touch ${dest}"
      return 0
    fi
    touch "${dest}"
    chown "${MAIN_USER}:${MAIN_USER}" "${dest}"
    return 0
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] cp ${src} ${dest}"
    return 0
  fi
  log_info "Seeding ${name} from ${SKEL_DIR} (Debian stock)"
  cp -a "${src}" "${dest}"
  chown "${MAIN_USER}:${MAIN_USER}" "${dest}"
}

install() {

  log_step "Installing bash additions (Debian stock preserved)"

  if [[ ! -d "${FILES_DIR}" ]]; then
    log_error "Dotfiles directory not found: ${FILES_DIR}"
    exit 1
  fi

  # Keep / restore Debian originals; TTDAID only appends marked blocks.
  seed_from_skel ".bashrc"
  seed_from_skel ".profile"

  # Snippets under files/bash/ are injected into the matching home files.
  # .bash_aliases / .bash_extras are TTDAID-owned additions (not in skel).
  # .profile PATH lives in ~/.config/ttdaid/env.sh (loader injected below).
  local dotfiles=(.bashrc .bash_aliases .bash_extras)

  for file in "${dotfiles[@]}"; do
    local src="${FILES_DIR}/${file}"
    local dest="${MAIN_HOME}/${file}"

    if [[ ! -f "${src}" ]]; then
      log_warn "Dotfile template not found: ${src} — skipping"
      continue
    fi

    local marker search_str
    case "${file}" in
      .bashrc)
        marker="bashrc_extras"
        search_str="bash_extras"
        ;;
      .bash_aliases)
        marker="aliases"
        search_str="alias set-git-config-home="
        ;;
      .bash_extras)
        marker="extras"
        search_str="__git_ps1"
        ;;
      *)
        log_error "Unknown dotfile type: ${file}"
        exit 1
        ;;
    esac

    inject_block_if_missing "${marker}" "${dest}" "${src}" "${search_str}"
  done

  # PATH: write env.sh (migrates tool bins from legacy fat .profile) + inject loader.
  ensure_profile_paths_base

  # Drop installer ad-hoc RC snippets. Tool PATH lines (npm/cargo/opencode)
  # are owned by their components via ensure_profile_tool_bin — not here.
  strip_ad_hoc_tool_path_rc

  log_ok "Bash additions installed (stock .bashrc/.profile kept)."
}

uninstall() {

  log_step "Removing bash TTDAID blocks (stock files left in place)"

  remove_injected_block "bashrc_extras" "${MAIN_HOME}/.bashrc"
  remove_injected_block "profile_paths" "${MAIN_HOME}/.profile"
  remove_injected_block "aliases" "${MAIN_HOME}/.bash_aliases"
  remove_injected_block "extras" "${MAIN_HOME}/.bash_extras"

  local env_file="${MAIN_HOME}/.config/ttdaid/env.sh"
  if [[ -f "${env_file}" ]]; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] Would remove ${env_file}"
    else
      rm -f "${env_file}"
      log_info "Removed ${env_file}"
    fi
  fi

  # Clean up empty addition files we own (never delete .bashrc/.profile).
  local extras=(.bash_aliases .bash_extras)
  for file in "${extras[@]}"; do
    local path="${MAIN_HOME}/${file}"
    if [[ -f "${path}" ]]; then
      if ! grep -q '[^[:space:]]' "${path}"; then
        if [[ "${DRY_RUN}" == "true" ]]; then
          printf "${_YELLOW}[DRY-RUN]${_RESET} Would remove empty file %s\n" "${path}"
        else
          log_info "Removing empty file: ${file}"
          rm -f "${path}"
        fi
      fi
    fi
  done

  log_ok "Bash TTDAID blocks removed."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  *)
    echo "Usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
