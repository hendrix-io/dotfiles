#!/usr/bin/env bash

# The imperative layer: everything the declarative build can't own - curl and
# npm installers that live in $HOME, auth, and the firstmate clone. Every
# function is guarded, so re-running is cheap and safe.
#
# INTERACTIVE=1 (bootstrap) may stop and prompt; INTERACTIVE=0 (rebuild)
# warns instead, so a routine rebuild never blocks on input.

. sh/utils.sh

FIRSTMATE_DIR="${FIRSTMATE_DIR:-$HOME/code/firstmate}"

# `sudo darwin-rebuild` evaluates the flake as root; on a dirty tree git can
# leave root-owned entries in .git, which breaks every later `git add`. Hand
# them back while the switch's sudo credentials are still warm.
repair_git_ownership() {
  if [ -n "$(find "$DOTFILES_DIR/.git" -user 0 -print -quit 2>/dev/null)" ]; then
    info "Fixing root-owned files in .git (left by the sudo rebuild)..."
    sudo chown -R "$(id -un)" "$DOTFILES_DIR/.git" ||
      warn "Could not fix .git ownership. Run: sudo chown -R \"\$(whoami)\" $DOTFILES_DIR/.git"
  fi
}

# The old setup.sh renamed ~/.config wholesale, stranding gh's auth in
# ~/.config.pre-setup. Recover it while the real location is still empty.
migrate_gh_config() {
  if [ -d "$HOME/.config.pre-setup/gh" ] && [ ! -d "$HOME/.config/gh" ]; then
    info "Recovering gh config from ~/.config.pre-setup..."
    mkdir -p "$HOME/.config"
    mv "$HOME/.config.pre-setup/gh" "$HOME/.config/gh"
    success "gh config restored"
  fi
}

auth_github() {
  if ! in_cmd gh; then
    warn "gh is not installed yet. Re-run after a successful switch."
    return 0
  fi
  if gh auth status &> /dev/null; then
    info "gh is authenticated."
  elif [ "${INTERACTIVE:-0}" = "1" ]; then
    info "gh needs auth - handing over to gh auth login..."
    gh auth login || warn "gh auth login did not complete. Run it again later."
  else
    warn "gh is not authenticated. Run: gh auth login"
  fi
}

auth_gitlab() {
  in_cmd glab || return 0
  if glab auth status &> /dev/null; then
    info "glab is authenticated."
    return 0
  fi
  if [ "${INTERACTIVE:-0}" = "1" ]; then
    read -r -p "Authenticate glab (GitLab) too? [y/N] " REPLY
    if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
      glab auth login || warn "glab auth login did not complete."
    fi
  else
    warn "glab is not authenticated. Run: glab auth login (skip if you don't use GitLab)"
  fi
}

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
# CLIs survive node version switches instead of vanishing with the old prefix.
setup_default_packages() {
  local f="${NVM_DIR:-$HOME/.nvm}/default-packages"
  mkdir -p "$(dirname "$f")"
  touch "$f"
  local pkg
  for pkg in gnhf pnpm; do
    if ! grep -qx "$pkg" "$f"; then
      info "Adding $pkg to nvm default-packages..."
      echo "$pkg" >> "$f"
    fi
  done
}

# Node itself plus the npm/npx-dependent tools, in one subshell: nvm.sh is
# not clean under `set -u`, and npm/npx only reach PATH after it is sourced.
install_node_layer() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    warn "nvm is not installed. Skipping node, gnhf, and the lavish skill."
    return 0
  fi
  (
    set +eu
    . "$NVM_DIR/nvm.sh"

    if ! command -v node > /dev/null 2>&1; then
      info "Installing node LTS..."
      nvm install --lts && nvm alias default 'lts/*'
    fi

    # gnhf: overnight agent loop orchestrator (good night, have fun).
    if ! command -v gnhf > /dev/null 2>&1; then
      info "Installing gnhf..."
      npm install -g gnhf || warn "gnhf failed to install"
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

    # lavish: review agent-generated HTML in a browser. The CLI is
    # install-free (`npx -y lavish-axi`); only the skill gets installed, at
    # user level (-g) so it follows you across repos.
    if [ ! -d "$HOME/.claude/skills/lavish" ]; then
      info "Installing lavish skill..."
      npx -y skills add kunchenguid/lavish-axi --skill lavish -g ||
        warn "lavish skill failed to install"
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

# Claude Code, via its native installer - the brew cask is deliberately
# absent from configuration.nix because it would be a second, competing
# install. Lands in ~/.local/bin, which .zshrc already puts on PATH;
# pre-seeding PATH the same way keeps the installer from offering to edit
# the rc when it runs before a shell restart.
install_claude() {
  if in_cmd "claude" || [ -x "$HOME/.local/bin/claude" ]; then
    info "claude is already installed. Skipping."
    return 0
  fi
  info "Installing Claude Code..."
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://claude.ai/install.sh | PATH="$HOME/.local/bin:$PATH" bash ||
    warn "Claude Code failed to install"
}

# no-mistakes: local validation gate in front of the real remote.
#
# Not in Homebrew, so this runs the upstream install script. The in_cmd guard
# keeps it from re-downloading on every rebuild.
#
# The script puts its binary in ~/.no-mistakes/bin, then symlinks it into
# ~/.local/bin when that directory is already on PATH - and falls back to a
# sudo-owned link in /usr/local/bin when it isn't. Creating the directory and
# putting it on PATH for the duration of the install keeps it sudo-free and
# out of system directories. .zshrc adds the same entry permanently.
#
# Telemetry note: unlike a source build, this binary ships with an embedded
# telemetry website ID. Set NO_MISTAKES_UMAMI_WEBSITE_ID="" or check
# upstream's opt-out if you'd rather it stayed off.
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

setup_gitconfig_local() {
  if [ ! -f "$HOME/.gitconfig.local" ]; then
    info "Creating .gitconfig.local..."
    cp "$DOTFILES_DIR/home/.gitconfig.local.example" "$HOME/.gitconfig.local"
    warn "Edit ~/.gitconfig.local with your name and email - commits use a placeholder until you do."
  else
    info ".gitconfig.local already exists. Skipping."
  fi
}

setup_zshrc_local() {
  if [ ! -f "$HOME/.zshrc.local" ]; then
    info "Creating .zshrc.local..."
    cp "$DOTFILES_DIR/home/.zshrc.local.example" "$HOME/.zshrc.local"
    success "Created .zshrc.local (customize this for your machine)"
  else
    info ".zshrc.local already exists. Skipping."
  fi
}

# firstmate is an agent distro: the clone IS the install. Launch a harness
# inside it (`cd` there, then `claude`) and its AGENTS.md takes over. It
# needs gh authenticated at runtime, which auth_github above handles.
clone_firstmate() {
  if [ -d "$FIRSTMATE_DIR/.git" ]; then
    info "firstmate already cloned at $FIRSTMATE_DIR. Skipping."
    return 0
  fi
  info "Cloning firstmate to $FIRSTMATE_DIR..."
  mkdir -p "$(dirname "$FIRSTMATE_DIR")"
  git clone https://github.com/kunchenguid/firstmate "$FIRSTMATE_DIR" ||
    warn "firstmate clone failed"
}

run_imperative() {
  repair_git_ownership
  migrate_gh_config
  auth_github
  auth_gitlab
  install_nvm
  setup_default_packages
  install_node_layer
  install_bun
  install_claude
  install_no_mistakes
  setup_gitconfig_local
  setup_zshrc_local
  clone_firstmate
}
