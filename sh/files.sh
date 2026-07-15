#!/usr/bin/env bash

. sh/utils.sh

files=(
  ~/.zshrc
)

folders=(
  ~/.config
)

mk_folders=(
  ~/.config
  ~/.config/starship
  ~/.config/ghostty
)

# Rename the old config files before we symlink the new ones
rename_files() {
  for f in "${files[@]}"; do
    if file_exists "$f"; then
      info "$f exists. Renaming to $f.pre-setup"
      mv "$f" "$f.pre-setup"
    else
      info "$f doesn't exist. Skipping."
    fi
  done
}

# Rename the old .config folder before running stow
# Also manually create the needed folders so there is
# no symlinked folders
rename_folders() {
  for f in "${folders[@]}"; do
    if folder_exists "$f"; then
      info "$f exists. Renaming to $f.pre-setup"
      mv "$f" "$f.pre-setup"
    else
      info "$f doesn't exist. Skipping."
    fi
  done

  for m in "${mk_folders[@]}"; do
    info "Making new folder $m."
    mkdir -p "$m"
  done
}

# Run stow command
sym_stow() {
  info "Symlinking dot files..."
  stow -d ~/dotfiles/stow -t ~ .
}

# Create .zshrc.local if it doesn't exist
setup_zshrc_local() {
  if [ ! -f "$HOME/.zshrc.local" ]; then
    info "Creating .zshrc.local..."
    cp "$HOME/.zshrc.local.example" "$HOME/.zshrc.local"
    success "Created .zshrc.local (customize this for your machine)"
  else
    info ".zshrc.local already exists. Skipping."
  fi
}
