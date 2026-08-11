#!/usr/bin/env bash
# Re-apply the dotfiles after a change. Safe to run any number of times.
#
# You do NOT need this to edit an existing config file - stow symlinks point at
# the files in this repo, so editing stow/.zshrc changes ~/.zshrc immediately.
# Run this when you ADD or REMOVE a file under stow/, or when you add a package
# to sh/installs.sh.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR"

export DOTFILES_DIR="$DIR"

# shellcheck source=sh/utils.sh
. sh/utils.sh
# shellcheck source=sh/installs.sh
. sh/installs.sh
# shellcheck source=sh/files.sh
. sh/files.sh

if ! in_cmd stow; then
  err "stow is not installed. Run ./setup.sh first."
  exit 1
fi

# -R restows: drops the old links, then relays them. That's what picks up
# deletions - a plain `stow .` would leave a symlink to a file you removed.
info "Restowing dotfiles..."
if ! stow -d "$DIR/stow" -t ~ -R .; then
  err "stow reported a conflict. Nothing was changed."
  err "Move or delete the file it named above, then re-run."
  exit 1
fi
success "Dotfiles restowed"

link_agents
success "Agent instructions linked"

# Cheap when everything is already present - each installer checks first.
info "Checking packages..."
install_stow
install_starship
install_cli_tools
install_zsh_plugins
install_casks
install_no_mistakes
install_lavish_skill
success "Packages up to date"

success "Complete! Run: source ~/.zshrc"
