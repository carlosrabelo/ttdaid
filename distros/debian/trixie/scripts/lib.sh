#!/usr/bin/env bash
# lib.sh — shared functions for all TTDAID scripts
# Source this file at the top of each component script

# Prevent direct execution
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { echo "This is a library. Use: source lib.sh"; exit 1; }

# =============================================================================
# Colors and logging
# =============================================================================

# Disable ANSI when piped (TUI/CI) or when NO_COLOR is set.
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
  _RED='' ; _GREEN='' ; _YELLOW='' ; _BLUE='' ; _BOLD='' ; _RESET=''
else
  _RED='\033[0;31m'
  _GREEN='\033[0;32m'
  _YELLOW='\033[1;33m'
  _BLUE='\033[0;34m'
  _BOLD='\033[1m'
  _RESET='\033[0m'
fi

log_info()  { printf "${_BLUE}[INFO]${_RESET}  %s\n" "$*"; }
log_ok()    { printf "${_GREEN}[OK]${_RESET}    %s\n" "$*"; }
log_warn()  { printf "${_YELLOW}[WARN]${_RESET}  %s\n" "$*"; }
log_error() { printf "${_RED}[ERROR]${_RESET} %s\n" "$*" >&2; }
log_step()  { printf "\n${_BOLD}==> %s${_RESET}\n" "$*"; }

# =============================================================================
# Dry-run
# =============================================================================

# Set by the Go runner / manual invocation: DRY_RUN=true|false
DRY_RUN="${DRY_RUN:-false}"

# run_cmd — execute a command, or print it in dry-run mode
run_cmd() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf "${_YELLOW}[DRY-RUN]${_RESET} %s\n" "$*"
    return 0
  fi
  "$@"
}

# =============================================================================
# Environment detection
# =============================================================================

# Detect WSL — sets IS_WSL=true/false
detect_wsl() {
  IS_WSL=false
  if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
    IS_WSL=true
  elif [[ -f /usr/bin/wslpath ]]; then
    IS_WSL=true
  fi
  export IS_WSL
}

# Detect systemd — sets HAS_SYSTEMD=true/false
detect_systemd() {
  HAS_SYSTEMD=false
  if [[ -d /run/systemd/system ]]; then
    HAS_SYSTEMD=true
  fi
  export HAS_SYSTEMD
}

# Determine user and home — sets MAIN_USER and MAIN_HOME
# Works both when running as root (via sudo) and as a regular user.
# If the Go runner already exported both, keep them.
get_main_user() {
  if [[ -n "${MAIN_USER:-}" && -n "${MAIN_HOME:-}" ]]; then
    export MAIN_USER MAIN_HOME
    return 0
  fi
  if [[ $EUID -eq 0 ]]; then
    MAIN_USER="${MAIN_USER:-${SUDO_USER:-root}}"
  else
    MAIN_USER="${MAIN_USER:-${USER:-$(whoami)}}"
  fi
  if [[ -z "${MAIN_HOME:-}" ]]; then
    local ent=""
    if command -v getent >/dev/null 2>&1; then
      ent=$(getent passwd "${MAIN_USER}" 2>/dev/null | cut -d: -f6 || true)
    fi
    if [[ -n "${ent}" ]]; then
      MAIN_HOME="${ent}"
    elif [[ "${MAIN_USER}" == "root" ]]; then
      MAIN_HOME="/root"
    else
      MAIN_HOME="/home/${MAIN_USER}"
    fi
  fi
  export MAIN_USER MAIN_HOME
}

# Get OS version — sets OS_VERSION (e.g. "13") and OS_CODENAME (e.g. "trixie")
get_os_version() {
  OS_VERSION=$(lsb_release -sr 2>/dev/null || echo "unknown")
  OS_CODENAME=$(lsb_release -sc 2>/dev/null || echo "unknown")
  export OS_VERSION OS_CODENAME
}

# =============================================================================
# Retry
# =============================================================================

# retry <attempts> <delay_seconds> <command...>
retry() {
  local attempts=$1 delay=$2
  shift 2
  local i=0
  until "$@"; do
    i=$((i + 1))
    if [[ $i -ge $attempts ]]; then
      log_error "Command failed after $attempts attempts: $*"
      return 1
    fi
    log_warn "Attempt $i/$attempts failed. Retrying in ${delay}s..."
    sleep "$delay"
  done
}

# =============================================================================
# APT
# =============================================================================

apt_install() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf "${_YELLOW}[DRY-RUN]${_RESET} apt-get install -y %s\n" "$*"
    return 0
  fi
  retry 3 5 apt-get install -y "$@"
}

apt_update() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf "${_YELLOW}[DRY-RUN]${_RESET} apt-get update\n"
    return 0
  fi
  retry 3 5 apt-get update -q
}

apt_remove() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf "${_YELLOW}[DRY-RUN]${_RESET} apt-get remove -y %s\n" "$*"
    return 0
  fi
  apt-get remove -y "$@" || true
  apt-get autoremove -y || true
}

# =============================================================================
# Flatpak
# =============================================================================

ensure_flathub() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf "${_YELLOW}[DRY-RUN]${_RESET} ensure flatpak + flathub remote\n"
    return 0
  fi
  if ! command -v flatpak &>/dev/null; then
    apt_install flatpak
  fi
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

flatpak_install() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf "${_YELLOW}[DRY-RUN]${_RESET} flatpak install -y flathub %s\n" "$*"
    return 0
  fi
  ensure_flathub
  retry 3 10 flatpak install -y flathub "$@"
}

flatpak_remove() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf "${_YELLOW}[DRY-RUN]${_RESET} flatpak uninstall -y %s\n" "$*"
    return 0
  fi
  if ! command -v flatpak &>/dev/null; then
    log_warn "flatpak not found — skipping flatpak remove $*"
    return 0
  fi
  flatpak uninstall -y "$@" || true
}

# =============================================================================
# npm global (as MAIN_USER)
# =============================================================================

_npm_as_user() {
  if [[ $EUID -eq 0 ]]; then
    sudo -u "${MAIN_USER}" "$@"
  else
    "$@"
  fi
}

npm_global() {
  local prefix="${MAIN_HOME}/.npm-global"
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf "${_YELLOW}[DRY-RUN]${_RESET} npm install -g %s\n" "$*"
    return 0
  fi
  mkdir -p "${prefix}/bin" "${prefix}/lib/node_modules"
  [[ $EUID -eq 0 ]] && chown -R "${MAIN_USER}:${MAIN_USER}" "${prefix}"
  # Ensure the prefix is configured before installing
  _npm_as_user npm config set prefix "${prefix}"
  _npm_as_user npm install -g "$@"
}

# Check if an npm global package is already installed
npm_global_installed() {
  local pkg="$1"
  _npm_as_user npm list -g --depth=0 "${pkg}" &>/dev/null
}

npm_global_remove() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf "${_YELLOW}[DRY-RUN]${_RESET} npm uninstall -g %s\n" "$*"
    return 0
  fi
  _npm_as_user npm uninstall -g "$@" || true
}

# =============================================================================
# Systemd
# =============================================================================

enable_service() {
  local svc="$1"
  if [[ "${HAS_SYSTEMD:-false}" == "true" ]]; then
    run_cmd systemctl enable --now "${svc}"
  else
    log_warn "systemd not available — service '${svc}' not enabled"
  fi
}

disable_service() {
  local svc="$1"
  if [[ "${HAS_SYSTEMD:-false}" == "true" ]]; then
    run_cmd systemctl disable --now "${svc}" || true
  else
    log_warn "systemd not available — cannot disable service '${svc}'"
  fi
}

# =============================================================================
# Checks
# =============================================================================

require_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)."
    exit 1
  fi
}

# =============================================================================
# Dotfiles Injection
# =============================================================================

# Directory of this library (scripts/); used to locate files/bash templates.
_TTDAID_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Body written to ~/.config/ttdaid/env.sh (sourced by .profile + .bashrc).
_TTDAID_ENV_TEMPLATE="${_TTDAID_SCRIPTS_DIR}/../files/bash/.profile"
# Thin loader injected into ~/.profile.
_TTDAID_PROFILE_LOADER="${_TTDAID_SCRIPTS_DIR}/../files/bash/profile-loader.sh"

ttdaid_env_file() {
  echo "${MAIN_HOME}/.config/ttdaid/env.sh"
}

# Strip ad-hoc PATH snippets written by tool installers (rustup, opencode,
# Antigravity, node, …). Canonical PATH entries live in ~/.config/ttdaid/env.sh
# (sourced from .profile / .bashrc). Only removes `export PATH=…` /
# source forms and known installer comments — not the `if [ -d … ]; PATH=…`
# style used by Debian/ttdaid templates.
strip_ad_hoc_tool_path_rc() {
  local f
  # Match installer-style lines only (`export PATH=…`, source cargo/env, comments).
  # Do not match ttdaid/Debian `if [ -d … ]; PATH=…` blocks in .profile.
  # Do not strip ~/.local/bin — that is a normal user path (also in env.sh).
  local needle='\.cargo/env|Antigravity CLI|^[[:space:]]*#[[:space:]]*opencode[[:space:]]*$|^[[:space:]]*export PATH=.*(\.opencode/bin|\.npm-global/bin)'
  for f in "${MAIN_HOME}/.profile" "${MAIN_HOME}/.bashrc" "${MAIN_HOME}/.bash_profile"; do
    [[ -f "${f}" ]] || continue
    if ! grep -qE "${needle}" "${f}" 2>/dev/null; then
      continue
    fi
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] Would strip ad-hoc tool PATH lines from ${f}"
      continue
    fi
    sed -i -E \
      -e '/\.cargo\/env/d' \
      -e '/^[[:space:]]*#[[:space:]]*opencode[[:space:]]*$/d' \
      -e '/^[[:space:]]*export PATH=.*\.opencode\/bin/d' \
      -e '/Added by Antigravity CLI installer/d' \
      -e '/^[[:space:]]*export PATH=.*\.npm-global\/bin/d' \
      "${f}"
    chown "${MAIN_USER}:${MAIN_USER}" "${f}"
    log_info "Removed ad-hoc tool PATH lines from ${f}"
  done
}

# Back-compat alias
strip_rustup_cargo_env_rc() { strip_ad_hoc_tool_path_rc; }

# Extract `# ttdaid-path:<id>` + following line from a file (env.sh or legacy block).
_extract_tool_bin_lines() {
  local file="$1"
  [[ -f "${file}" ]] || return 0
  awk '
    /^# ttdaid-path:/ {
      print
      if ((getline line) > 0) print line
    }
  ' "${file}"
}

# Extract tool bins from a marked profile_paths block (legacy fat .profile).
_extract_profile_tool_bins() {
  local file="$1"
  local start_marker="# >>> ttdaid profile_paths start >>>"
  local end_marker="# <<< ttdaid profile_paths end <<<"
  [[ -f "${file}" ]] || return 0
  awk -v s="${start_marker}" -v e="${end_marker}" '
    $0 == s { inblock=1; next }
    $0 == e { inblock=0; next }
    inblock && /^# ttdaid-path:/ {
      print
      if ((getline line) > 0) print line
    }
  ' "${file}"
}

# Merge preserved tool-bin entries into an env.sh body (before unset -f).
_merge_profile_tool_bins() {
  local paths_file="$1"
  if [[ ! -s "${paths_file}" ]]; then
    cat
    return 0
  fi
  awk -v pf="${paths_file}" '
    /^unset -f _ttdaid_path_prepend/ {
      print "# --- Tool bins (managed by components) ---"
      while ((getline line < pf) > 0) print line
      close(pf)
      print ""
      print
      next
    }
    { print }
  '
}

# Collect tool-bin lines from env.sh and/or legacy .profile block (dedupe by id).
_collect_tool_bin_lines() {
  local env_file profile tmp
  env_file="$(ttdaid_env_file)"
  profile="${MAIN_HOME}/.profile"
  tmp=$(mktemp)
  {
    _extract_tool_bin_lines "${env_file}"
    _extract_profile_tool_bins "${profile}"
  } > "${tmp}"
  # Dedupe by "# ttdaid-path:<id>" keeping first occurrence + its path line.
  awk '
    /^# ttdaid-path:/ {
      id=$0
      if ((getline line) <= 0) next
      if (seen[id]++) next
      print id
      print line
      next
    }
  ' "${tmp}"
  rm -f "${tmp}"
}

# Write ~/.config/ttdaid/env.sh from template + preserved tool bins.
_write_ttdaid_env_file() {
  local template="${_TTDAID_ENV_TEMPLATE}"
  local env_file preserved body
  env_file="$(ttdaid_env_file)"

  if [[ ! -f "${template}" ]]; then
    log_error "env template not found: ${template}"
    return 1
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would write ${env_file}"
    return 0
  fi

  mkdir -p "$(dirname "${env_file}")"
  preserved=$(mktemp)
  body=$(mktemp)
  _collect_tool_bin_lines > "${preserved}"
  if [[ -s "${preserved}" ]]; then
    _merge_profile_tool_bins "${preserved}" < "${template}" > "${body}"
  else
    cat "${template}" > "${body}"
  fi
  [[ "$(tail -c1 "${body}" 2>/dev/null || true)" != $'\n' ]] && echo "" >> "${body}"
  cat "${body}" > "${env_file}"
  rm -f "${preserved}" "${body}"
  chown -R "${MAIN_USER}:${MAIN_USER}" "$(dirname "${env_file}")"
  log_info "Wrote ${env_file}"
}

inject_block() {
  local marker="$1"
  local target_file="$2"
  local source_file="$3"

  local start_marker="# >>> ttdaid ${marker} start >>>"
  local end_marker="# <<< ttdaid ${marker} end <<<"

  if [[ "${DRY_RUN}" == "true" ]]; then
    printf "${_YELLOW}[DRY-RUN]${_RESET} Would inject block '${marker}' from ${source_file} into ${target_file}\n"
    return 0
  fi

  # Ensure target file exists and has correct ownership if newly created
  if [[ ! -f "${target_file}" ]]; then
    touch "${target_file}"
    chown "${MAIN_USER}:${MAIN_USER}" "${target_file}"
  fi

  local body_file preserved_file
  body_file=$(mktemp)
  preserved_file=$(mktemp)
  cat "${source_file}" > "${body_file}"
  [[ "$(tail -c1 "${body_file}" 2>/dev/null || true)" != $'\n' ]] && echo "" >> "${body_file}"

  # Legacy: fat profile_paths bodies carried tool bins. Loaders do not — env.sh does.
  if [[ "${marker}" == "profile_paths" ]] && grep -q '^unset -f _ttdaid_path_prepend' "${body_file}" \
    && grep -qF "${start_marker}" "${target_file}"; then
    _extract_profile_tool_bins "${target_file}" > "${preserved_file}"
    if [[ -s "${preserved_file}" ]]; then
      local merged
      merged=$(mktemp)
      _merge_profile_tool_bins "${preserved_file}" < "${body_file}" > "${merged}"
      mv "${merged}" "${body_file}"
    fi
  fi

  if grep -qF "${start_marker}" "${target_file}"; then
    log_info "Updating block '${marker}' in ${target_file}"
    local temp_file
    temp_file=$(mktemp)

    # Everything before the start marker
    sed "/${start_marker}/,\$d" "${target_file}" > "${temp_file}"

    # The new block
    echo "${start_marker}" >> "${temp_file}"
    cat "${body_file}" >> "${temp_file}"
    [[ "$(tail -c1 "${temp_file}")" != $'\n' ]] && echo "" >> "${temp_file}"
    echo "${end_marker}" >> "${temp_file}"

    # Everything after the end marker
    sed -n "/${end_marker}/,\$p" "${target_file}" | tail -n +2 >> "${temp_file}"

    cat "${temp_file}" > "${target_file}"
    rm -f "${temp_file}"
  else
    log_info "Adding block '${marker}' to ${target_file}"
    # Ensure file ends with newline before appending
    [[ -s "${target_file}" && "$(tail -c1 "${target_file}")" != $'\n' ]] && echo "" >> "${target_file}"
    echo "${start_marker}" >> "${target_file}"
    cat "${body_file}" >> "${target_file}"
    [[ "$(tail -c1 "${target_file}")" != $'\n' ]] && echo "" >> "${target_file}"
    echo "${end_marker}" >> "${target_file}"
  fi
  rm -f "${body_file}" "${preserved_file}"
  chown "${MAIN_USER}:${MAIN_USER}" "${target_file}"
}

remove_injected_block() {
  local marker="$1"
  local target_file="$2"

  local start_marker="# >>> ttdaid ${marker} start >>>"
  local end_marker="# <<< ttdaid ${marker} end <<<"

  if [[ "${DRY_RUN}" == "true" ]]; then
    printf "${_YELLOW}[DRY-RUN]${_RESET} Would remove block '${marker}' from ${target_file}\n"
    return 0
  fi

  if [[ -f "${target_file}" ]] && grep -qF "${start_marker}" "${target_file}"; then
    log_info "Removing block '${marker}' from ${target_file}"
    local temp_file
    temp_file=$(mktemp)
    sed "/${start_marker}/,/${end_marker}/d" "${target_file}" > "${temp_file}"
    cat "${temp_file}" > "${target_file}"
    rm -f "${temp_file}"
    chown "${MAIN_USER}:${MAIN_USER}" "${target_file}"
  fi
}

inject_block_if_missing() {
  local marker="$1"
  local target_file="$2"
  local source_file="$3"
  local search_str="$4"

  local start_marker="# >>> ttdaid ${marker} start >>>"

  # If the file already has the start marker, update it (normalize to ours).
  if [[ -f "${target_file}" ]] && grep -qF "${start_marker}" "${target_file}"; then
    inject_block "${marker}" "${target_file}" "${source_file}"
    return 0
  fi

  # search_str without our marker: normalize — strip installer PATH noise and inject.
  if [[ -f "${target_file}" ]] && [[ -n "${search_str}" ]] && grep -qF "${search_str}" "${target_file}"; then
    log_info "Found '${search_str}' without ttdaid marker in ${target_file} — normalizing"
    if [[ "${marker}" == "profile_paths" ]]; then
      strip_ad_hoc_tool_path_rc
      # Drop orphan helper left outside a ttdaid block so we do not duplicate it.
      if [[ "${DRY_RUN}" != "true" ]] && [[ -f "${target_file}" ]]; then
        sed -i \
          -e '/^_ttdaid_path_prepend() {.*}$/d' \
          -e '/^_ttdaid_path_prepend() {$/,/^}$/d' \
          "${target_file}"
        chown "${MAIN_USER}:${MAIN_USER}" "${target_file}"
      fi
    fi
    inject_block "${marker}" "${target_file}" "${source_file}"
    return 0
  fi

  inject_block "${marker}" "${target_file}" "${source_file}"
}

# Ensure ~/.config/ttdaid/env.sh exists and ~/.profile sources it.
ensure_profile_paths_base() {
  local loader="${_TTDAID_PROFILE_LOADER}"
  local profile="${MAIN_HOME}/.profile"

  if [[ ! -f "${loader}" ]]; then
    log_error "profile loader not found: ${loader}"
    return 1
  fi

  _write_ttdaid_env_file
  inject_block "profile_paths" "${profile}" "${loader}"
}

# Add/update a component-owned PATH entry in ~/.config/ttdaid/env.sh.
# Usage: ensure_profile_tool_bin <id> <bindir-relative-to-HOME>
# Example: ensure_profile_tool_bin opencode '.opencode/bin'
ensure_profile_tool_bin() {
  local id="$1"
  local rel="$2"
  rel="${rel#./}"
  rel="${rel#/}"

  strip_ad_hoc_tool_path_rc
  ensure_profile_paths_base

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would ensure PATH '${id}' -> \$HOME/${rel}"
    return 0
  fi

  local env_file tag path_line tmp tmp2
  env_file="$(ttdaid_env_file)"
  tag="# ttdaid-path:${id}"
  path_line="[ -d \"\${HOME}/${rel}\" ] && _ttdaid_path_prepend \"\${HOME}/${rel}\""
  tmp=$(mktemp)
  tmp2=$(mktemp)

  awk -v tag="${tag}" '
    $0 == tag { skip=1; next }
    skip { skip=0; next }
    { print }
  ' "${env_file}" > "${tmp}"

  if grep -q '^unset -f _ttdaid_path_prepend' "${tmp}"; then
    awk -v tag="${tag}" -v pl="${path_line}" '
      /^unset -f _ttdaid_path_prepend/ {
        print tag
        print pl
        print ""
      }
      { print }
    ' "${tmp}" > "${tmp2}"
  else
    log_error "env.sh incomplete (${env_file}) — cannot add PATH '${id}'"
    rm -f "${tmp}" "${tmp2}"
    return 1
  fi

  cat "${tmp2}" > "${env_file}"
  rm -f "${tmp}" "${tmp2}"
  chown "${MAIN_USER}:${MAIN_USER}" "${env_file}"
  log_info "Ensured PATH entry '${id}' (-> \$HOME/${rel}) in ${env_file}"
}

# Remove a component-owned PATH entry from env.sh; leaves the base intact.
remove_profile_tool_bin() {
  local id="$1"
  local env_file profile tag tmp
  env_file="$(ttdaid_env_file)"
  profile="${MAIN_HOME}/.profile"
  tag="# ttdaid-path:${id}"

  strip_ad_hoc_tool_path_rc

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would remove PATH '${id}' from ${env_file}"
    return 0
  fi

  for f in "${env_file}" "${profile}"; do
    [[ -f "${f}" ]] || continue
    grep -qF "${tag}" "${f}" || continue
    tmp=$(mktemp)
    awk -v tag="${tag}" '
      $0 == tag { skip=1; next }
      skip { skip=0; next }
      { print }
    ' "${f}" > "${tmp}"
    cat "${tmp}" > "${f}"
    rm -f "${tmp}"
    chown "${MAIN_USER}:${MAIN_USER}" "${f}"
    log_info "Removed PATH entry '${id}' from ${f}"
  done
}


