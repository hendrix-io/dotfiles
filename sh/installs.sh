#!/usr/bin/env bash

. sh/utils.sh

# Make sure Brew is installed
install_brew() {
  if in_cmd "brew"; then
    info "brew is already installed. Skipping."
  else
    info "Installing brew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew update
    brew upgrade
    success "Brew installed"
  fi
}

# Install stow for dotfile management
install_stow() {
  if in_cmd "stow"; then
    info "stow is already installed. Skipping."
  else
    info "Installing stow..."
    install_pkg stow
    success "stow installed"
  fi
}

# Install starship prompt
install_starship() {
  if in_cmd "starship"; then
    info "starship is already installed. Skipping."
  else
    info "Installing starship..."
    install_pkg starship
    success "starship installed"
  fi
}

# Install nvm (Node Version Manager)
install_nvm() {
  if [ -d "$HOME/.nvm" ]; then
    info "nvm is already installed. Skipping."
  else
    info "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    success "nvm installed"
  fi
}

# Install pnpm
install_pnpm() {
  if in_cmd "pnpm"; then
    info "pnpm is already installed. Skipping."
  else
    info "Installing pnpm..."
    curl -fsSL https://get.pnpm.io/install.sh | sh -
    success "pnpm installed"
  fi
}

# Install bun
install_bun() {
  if in_cmd "bun"; then
    info "bun is already installed. Skipping."
  else
    info "Installing bun..."
    curl -fsSL https://bun.sh/install | bash
    success "bun installed"
  fi
}
