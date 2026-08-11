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

# Install ghostty terminal
install_ghostty() {
  if in_cmd "ghostty"; then
    info "ghostty is already installed. Skipping."
  else
    info "Installing ghostty..."
    brew install --cask ghostty
    success "ghostty installed"
  fi
}

# Everyday CLI tools. Keyed by command name so an already-present binary from
# any source (brew, cargo, work-managed install) is left alone.
cli_tools=(
  "rg:ripgrep"    # fast search
  "fd:fd"         # fast find
  "fzf:fzf"       # fuzzy finder
  "lazygit:lazygit"
  "nvim:neovim"
)

install_cli_tools() {
  for entry in "${cli_tools[@]}"; do
    local cmd="${entry%%:*}"
    local pkg="${entry#*:}"

    if in_cmd "$cmd"; then
      info "$pkg is already installed. Skipping."
    else
      info "Installing $pkg..."
      install_pkg "$pkg"
    fi
  done
}

# zsh autosuggestions + syntax highlighting. .zshrc sources these from
# $HOMEBREW_PREFIX/share and silently skips them if they aren't installed.
zsh_plugins=(
  zsh-autosuggestions
  zsh-syntax-highlighting
)

install_zsh_plugins() {
  for pkg in "${zsh_plugins[@]}"; do
    if in_brew "$pkg"; then
      info "$pkg is already installed. Skipping."
    else
      info "Installing $pkg..."
      install_pkg "$pkg"
    fi
  done
}

# Hack Nerd Font.
#
# Ghostty already embeds JetBrains Mono with Nerd Font symbol fallback, so the
# starship git glyphs render without this. It only matters if you set an
# explicit font-family - see stow/.config/ghostty/config.
install_nerd_font() {
  if brew list --cask font-hack-nerd-font &>/dev/null; then
    info "font-hack-nerd-font is already installed. Skipping."
  else
    info "Installing font-hack-nerd-font..."
    brew install --cask font-hack-nerd-font || warn "font-hack-nerd-font failed to install"
  fi
}
