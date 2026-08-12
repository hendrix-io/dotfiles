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

# GUI apps and fonts.
#
# font-hack-nerd-font: Ghostty already embeds JetBrains Mono with Nerd Font
#   fallback, so this only matters because stow/.config/ghostty/config sets an
#   explicit font-family.
# opensuperwhisper: local Whisper/Parakeet dictation. arm64 + macOS >= 14 only,
#   so brew declines it on Intel - the warn below keeps that from failing setup.
casks=(
  ghostty
  font-hack-nerd-font
  opensuperwhisper
)

install_casks() {
  for c in "${casks[@]}"; do
    if brew list --cask "$c" &>/dev/null; then
      info "$c is already installed. Skipping."
    else
      info "Installing $c..."
      brew install --cask "$c" || warn "$c failed to install"
    fi
  done
}

# Everyday CLI tools. Keyed by command name so an already-present binary from
# any source (brew, cargo, work-managed install) is left alone.
cli_tools=(
  # Declared deliberately: macOS ships an older git via Xcode Command Line
  # Tools, and .zshrc puts $HOMEBREW_PREFIX/bin ahead of /usr/bin, so this is
  # the one that actually runs.
  "git:git"
  "rg:ripgrep"    # fast search
  "fd:fd"         # fast find
  "fzf:fzf"       # fuzzy finder
  "lazygit:lazygit"
  "nvim:neovim"
  "treehouse:treehouse"   # pool of reusable git worktrees, warm deps intact
  "tmux:tmux"
  "gh:gh"
  "glab:glab"
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

# no-mistakes: local validation gate in front of the real remote.
#
# Not in Homebrew, so this runs the upstream install script. The in_cmd guard
# above keeps it from re-downloading on every rebuild.
#
# The script puts its binary in ~/.no-mistakes/bin, then symlinks it into
# ~/.local/bin when that directory is already on PATH - and falls back to a
# sudo-owned link in /usr/local/bin when it isn't. Creating the directory and
# putting it on PATH for the duration of the install keeps it sudo-free and out
# of system directories. .zshrc adds the same entry permanently.
#
# Telemetry note: unlike a source build, this binary ships with an embedded
# telemetry website ID. Set NO_MISTAKES_UMAMI_WEBSITE_ID="" or check upstream's
# opt-out if you'd rather it stayed off.
# lavish: opens agent-generated HTML in a local browser so you can click
# elements, annotate text, and edit Mermaid diagrams as whiteboards, then send
# that back to the agent instead of describing changes in prose.
#
# The CLI itself is deliberately install-free - `npx -y lavish-axi` fetches it
# on demand. Only the skill gets installed, and at user level (-g) so it follows
# you across repos rather than landing in one project's .claude/skills.
install_lavish_skill() {
  if [ -d "$HOME/.claude/skills/lavish" ]; then
    info "lavish skill is already installed. Skipping."
    return 0
  fi

  if ! in_cmd "npx"; then
    warn "npx not found - skipping lavish skill."
    return 0
  fi

  info "Installing lavish skill..."
  npx -y skills add kunchenguid/lavish-axi --skill lavish -g ||
    warn "lavish skill failed to install"
}

install_no_mistakes() {
  if in_cmd "no-mistakes"; then
    info "no-mistakes is already installed. Skipping."
    return 0
  fi

  info "Installing no-mistakes..."
  mkdir -p "$HOME/.local/bin"
  (
    export PATH="$HOME/.local/bin:$PATH"
    curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh
  ) || warn "no-mistakes failed to install"
}

