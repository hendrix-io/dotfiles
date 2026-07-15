#!/usr/bin/env bash

if [[ $1 == "--help" ]]; then
  echo ""
  echo "setup.sh"
  echo "  Sets up dotfiles with stow"
  echo ""
  exit 0
fi

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
success "Core tools installed"

install_nvm
install_pnpm
install_bun
success "Node.js tools installed"

rename_files
rename_folders
sym_stow
setup_zshrc_local
info "Symlinking dotfiles complete"

clean_up

success "Complete!"
echo ""
info "Next steps:"
echo "  1. Edit ~/.zshrc.local with your machine-specific config"
echo "  2. Restart your terminal or run: source ~/.zshrc"
