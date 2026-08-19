#!/usr/bin/env bash

# The base developer toolchain - useful with or without the agent fleet.
# Every function is guarded, so re-running is cheap and safe.

. sh/utils.sh

# nvm's installer wants to append its source lines to ~/.zshrc, but skips any
# rc file that already mentions nvm.sh - ours does, so the symlinked repo
# file stays untouched.
install_nvm() {
  if [ -d "$HOME/.nvm" ]; then
    info "nvm is already installed. Skipping."
  else
    info "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | bash
    success "nvm installed"
  fi
}

# nvm reinstalls everything in this file on every `nvm install`, so global
# CLIs survive node version switches instead of vanishing with the old
# prefix. gnhf's entry is added by agent-installs.sh, gated with the fleet.
setup_default_packages() {
  local f="${NVM_DIR:-$HOME/.nvm}/default-packages"
  mkdir -p "$(dirname "$f")"
  touch "$f"
  local pkg
  for pkg in pnpm @fission-ai/openspec; do
    if ! grep -qx "$pkg" "$f"; then
      info "Adding $pkg to nvm default-packages..."
      echo "$pkg" >> "$f"
    fi
  done
}

# Node itself plus the npm-dependent tools, in one subshell: nvm.sh is not
# clean under `set -u`, and npm only reaches PATH after it is sourced.
install_node_layer() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    warn "nvm is not installed. Skipping node, pnpm, and openspec."
    return 0
  fi
  (
    set +eu
    . "$NVM_DIR/nvm.sh"

    if ! command -v node > /dev/null 2>&1; then
      info "Installing node LTS..."
      nvm install --lts && nvm alias default 'lts/*'
    fi

    # pnpm, via npm rather than get.pnpm.io: the standalone installer ends
    # with `pnpm setup --force`, which unconditionally writes a PNPM_HOME
    # block into ~/.zshrc - a symlink into this repo. npm keeps it out of
    # the rc entirely; default-packages keeps it across node upgrades, and
    # .zshrc already puts PNPM_HOME on PATH.
    if ! command -v pnpm > /dev/null 2>&1; then
      info "Installing pnpm..."
      npm install -g pnpm || warn "pnpm failed to install"
    fi

    # openspec: the daily spec-workflow CLI. npm global (not bun) so it
    # rides default-packages across node upgrades like pnpm does.
    if ! command -v openspec > /dev/null 2>&1; then
      info "Installing OpenSpec..."
      npm install -g @fission-ai/openspec || warn "openspec failed to install"
    fi
  ) || warn "node layer had errors - re-run ./rebuild.sh"
}

# bun's installer edits ~/.zshrc only when `bun` doesn't resolve in its own
# shell after the install - so pre-seeding PATH with the install target makes
# that check succeed and the rc edit (into this repo, via the symlink) never
# happens. .zshrc already has the equivalent guarded block.
install_bun() {
  if in_cmd "bun"; then
    info "bun is already installed. Skipping."
  else
    info "Installing bun..."
    curl -fsSL https://bun.sh/install | PATH="$HOME/.bun/bin:$PATH" bash
    success "bun installed"
  fi
}

run_tool_installs() {
  install_nvm
  setup_default_packages
  install_node_layer
  install_bun
}
