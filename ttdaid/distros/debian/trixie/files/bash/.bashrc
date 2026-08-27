# =============================================================================
# TTDAID — .bashrc (snippet)
# Injected into the user's Debian stock ~/.bashrc.
# Stock already sources ~/.bash_aliases; we pull in ~/.bash_extras and PATH.
# =============================================================================

if [ -f "${HOME}/.bash_extras" ]; then
    # shellcheck source=/dev/null
    . "${HOME}/.bash_extras"
fi

# Desktop terminals are usually interactive non-login shells: they read
# ~/.bashrc but not ~/.profile. Load the same PATH file login shells get.
if [ -z "${TTDAID_ENV_SOURCED:-}" ] && [ -f "${HOME}/.config/ttdaid/env.sh" ]; then
    # shellcheck source=/dev/null
    . "${HOME}/.config/ttdaid/env.sh"
    TTDAID_ENV_SOURCED=1
    export TTDAID_ENV_SOURCED
fi
