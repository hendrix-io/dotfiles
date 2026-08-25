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

if [ "${1:-}" = "--help" ]; then
  echo ""
  echo "rebuild.sh - re-apply the config after a change. Never prompts."
  echo ""
  echo "Run after editing a package list, a macOS default, or the set of"
  echo "linked files. Editing an already-linked file needs no rebuild - the"
  echo "symlinks point into this repo, so those edits are live immediately."
  echo ""
  exit 0
fi

if ! in_cmd darwin-rebuild; then
  err "darwin-rebuild not found. Run ./bootstrap.sh first."
  exit 1
fi

ln -sfn "$DIR" ~/.dotfiles

# Migration aid for machines coming from the old layout, where the live
# Claude settings were a symlink into this repo: the switch is about to
# remove that link, so save the content first. sh/machine.sh adopts the
# snapshot afterwards.
if [ -L "$HOME/.claude/settings.json" ] && [ -e "$HOME/.claude/settings.json" ]; then
  cp -L "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.pre-migration"
fi

if ! MACHINE="$(machine_label)"; then
  err "Login \"$(whoami)\" matches no machine in flake.nix's machines block."
  err "Pick one by hand: echo <label> > ~/.dotfiles-machine"
  exit 1
fi

info "Applying the declarative config for machine \"$MACHINE\"..."
sudo darwin-rebuild switch --flake ~/.dotfiles#"$MACHINE"
success "System config applied"

# INTERACTIVE=0: auth problems warn instead of prompting, so a routine
# rebuild never blocks on input.
INTERACTIVE=0 run_imperative

success "Complete!"
