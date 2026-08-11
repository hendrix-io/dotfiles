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
install_ghostty
install_cli_tools
install_zsh_plugins
install_nerd_font
success "Core tools installed"

install_nvm
install_pnpm
install_bun
success "Node.js tools installed"

# Order matters: .zshrc.local has to exist before the new .zshrc sources it,
# and rename_files has to run before stow so stow isn't blocked by the old one.
setup_zshrc_local
rename_files
sym_stow
link_agents
info "Symlinking dotfiles complete"

clean_up

success "Complete!"
echo ""
info "Next steps:"
echo "  1. Move any secrets and machine-specific PATH entries out of"
echo "     ~/.zshrc.pre-setup and into ~/.zshrc.local"
echo "  2. Edit AGENTS.md - it is now the single source for every agent"
echo "  3. Restart your terminal or run: source ~/.zshrc"
echo ""
info "From now on, use ./rebuild.sh instead of ./setup.sh"
