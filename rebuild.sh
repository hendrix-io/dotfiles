#!/usr/bin/env bash

# Re-apply the config after a change. Safe to run any number of times.
#
# You do NOT need this to edit an already-linked config file - the symlinks
# point into this repo, so editing home/.zshrc IS editing ~/.zshrc. Run this
# when you change a package list or a system default, add or remove a linked
# file, or want the guarded installers re-checked.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR"
export DOTFILES_DIR="$DIR"

. sh/utils.sh
. sh/installs.sh

if ! in_cmd darwin-rebuild; then
  err "darwin-rebuild not found. Run ./bootstrap.sh first."
  exit 1
fi

ln -sfn "$DIR" ~/.dotfiles

info "Applying the declarative config..."
sudo darwin-rebuild switch --flake ~/.dotfiles#mac
success "System config applied"

# INTERACTIVE=0: auth problems warn instead of prompting, so a routine
# rebuild never blocks on input.
INTERACTIVE=0 run_imperative

success "Complete!"
