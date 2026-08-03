# =============================================================================
# TTDAID — .bash_aliases
# Sourced by Debian stock ~/.bashrc when the file exists.
# =============================================================================

# --- Git identity (edit to match your accounts) -------------------------------

alias set-git-config-home='git config user.name "Carlos Rabelo" && git config user.email "developer@carlosrabelo.com.br"'
alias set-git-config-work='git config user.name "Carlos Rabelo" && git config user.email "carlos.rabelo@ifmt.edu.br"'

# --- Git workflow -------------------------------------------------------------

alias git-fetch-all-pull='git fetch --all --prune && git pull origin $(git branch | sed -n -e "s/^\* \(.*\)/\1/p")'
alias git-clean-reset-fetch='git fetch origin && git reset --hard origin/$(git branch | sed -n -e "s/^\* \(.*\)/\1/p") && git clean -f -d'
alias git-add-commit-time='git add . && git commit -m "`date \"+%Y-%m-%d %H:%M\"`" && git push origin master'
alias git-squash-commit='git reset $(git commit-tree HEAD^{tree} -m "Initial commit")'

# --- Docker cleanup -----------------------------------------------------------

alias docker-clear-containers='docker ps --no-trunc -aqf "status=exited" | xargs -r docker rm'
alias docker-clear-images='docker images --no-trunc -aqf "dangling=true" | xargs -r docker rmi'
alias docker-clear-volumes='docker volume ls -qf "dangling=true" | xargs -r docker volume rm'
alias docker-clear-networks='docker network ls -qf "type=custom" | xargs -r docker network rm'
