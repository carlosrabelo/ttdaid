# =============================================================================
# TTDAID — load PATH extras from ~/.config/ttdaid/env.sh
# Injected into ~/.profile (login shells). ~/.bashrc loads the same file for
# interactive non-login terminals (GNOME Terminal, VS Code, etc.).
# =============================================================================

if [ -z "${TTDAID_ENV_SOURCED:-}" ] && [ -f "${HOME}/.config/ttdaid/env.sh" ]; then
    # shellcheck source=/dev/null
    . "${HOME}/.config/ttdaid/env.sh"
    TTDAID_ENV_SOURCED=1
    export TTDAID_ENV_SOURCED
fi
