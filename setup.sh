#!/usr/bin/env bash

if [[ ${1:-} == "--help" ]]; then
  echo ""
  echo "setup.sh"
  echo "  Sets up dotfiles with stow"
  echo ""
  exit 0
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR"
export DOTFILES_DIR="$DIR"

. sh/utils.sh
. sh/installs.sh
. sh/files.sh

# Might as well get it now
sudo -v

install_brew

info "Updating existing packages..."
update_pkgs
success "Packages updated"

install_stow
install_starship
install_cli_tools
install_zsh_plugins
install_casks
install_no_mistakes
success "Core tools installed"

install_nvm
install_pnpm
install_bun
success "Node.js tools installed"

# Needs npx, so it has to come after the Node tools above.
install_lavish_skill

# Order matters: .zshrc.local has to exist before the new .zshrc sources it,
# and rename_files has to run before stow so stow isn't blocked by the old one.
setup_zshrc_local
rename_files
if ! sym_stow; then
  restore_files
  err "Aborted. Your original ~/.zshrc has been put back."
  err "Resolve the conflict above, then re-run ./setup.sh."
  err "To keep the existing file and pull it into the repo instead:"
  err "  stow -d \"$DIR/stow\" -t ~ --adopt ."
  exit 1
fi
link_agents
info "Symlinking dotfiles complete"

clean_up

success "Complete!"

report_migration

info "Also worth doing:"
echo "  - Edit AGENTS.md - it is now the single source for every agent"
echo "  - Restart your terminal or run: source ~/.zshrc"
echo ""
info "From now on, use ./rebuild.sh instead of ./setup.sh"
