# =============================================================================
# TTDAID — PATH env (canonical)
# Written to ~/.config/ttdaid/env.sh and sourced from ~/.profile + ~/.bashrc.
# Desktop terminals are non-login (bashrc only), so user bins that stock Debian
# puts only in ~/.profile must also live here.
# Per-tool bin dirs are injected by their components (see ensure_profile_tool_bin).
# =============================================================================

# Prepend $1 to PATH once (no duplicates).
_ttdaid_path_prepend() {
    case ":${PATH}:" in
        *":$1:"*) ;;
        *) PATH="$1${PATH:+:$PATH}" ;;
    esac
}

# --- User bins (stock ~/.profile; needed again for non-login shells) ----------

[ -d "${HOME}/bin" ] && _ttdaid_path_prepend "${HOME}/bin"
[ -d "${HOME}/.local/bin" ] && _ttdaid_path_prepend "${HOME}/.local/bin"

# --- Go -----------------------------------------------------------------------
# Toolchain: APT golang-go · workspace: ~/go or ~/.local/go

if [ -d "${HOME}/go" ]; then
    export GOPATH="${HOME}/go"
elif [ -d "${HOME}/.local/go" ]; then
    export GOPATH="${HOME}/.local/go"
fi
if [ -n "${GOPATH:-}" ] && [ -d "${GOPATH}/bin" ]; then
    _ttdaid_path_prepend "${GOPATH}/bin"
fi

unset -f _ttdaid_path_prepend
