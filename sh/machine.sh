#!/usr/bin/env bash

# Machine housekeeping - nothing in this file installs a tool. Git-ownership
# repair, recovering stranded config, auth, and seeding the machine-local
# files that never get committed.

. sh/utils.sh

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

run_machine_setup() {
  repair_git_ownership
  migrate_gh_config
  auth_github
  auth_gitlab
  setup_gitconfig_local
  setup_zshrc_local
}
