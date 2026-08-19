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
    if [ "$(ask_yn "Authenticate glab (GitLab) too? [y/N] " n)" = "y" ]; then
      glab auth login || warn "glab auth login did not complete."
    fi
  else
    warn "glab is not authenticated. Run: glab auth login (skip if you don't use GitLab)"
  fi
}

# ~/.claude/settings.json is deliberately a real file, not a repo symlink:
# Claude Code writes runtime config into it, and a live symlink would land
# those writes in this public repo's working tree (that nearly leaked
# fr8factory internals once). Runs unconditionally - even with agents off -
# so a machine migrating from the old symlinked layout never loses its
# settings; only the template seeding is gated on the fleet.
setup_claude_settings() {
  local live="$HOME/.claude/settings.json"
  local snapshot="$HOME/.claude/settings.json.pre-migration"
  local old_repo_copy="$DOTFILES_DIR/home/.claude/settings.json"

  # A surviving symlink means Claude still writes into the repo - the exact
  # leak this layout exists to prevent. Capture its content (if it still
  # resolves) and remove the link no matter what.
  if [ -L "$live" ]; then
    if [ -e "$live" ]; then
      cp -L "$live" "$snapshot"
    fi
    rm -f "$live"
  fi

  if [ -f "$live" ]; then
    return 0
  fi

  if [ -f "$snapshot" ]; then
    info "Migrating ~/.claude/settings.json out of the repo..."
    mkdir -p "$HOME/.claude"
    mv "$snapshot" "$live"
  elif [ -f "$old_repo_copy" ] && [ ! -L "$old_repo_copy" ]; then
    # Old-layout machines kept the live content at this (now untracked)
    # repo path; adopt it instead of resetting to the template.
    info "Migrating ~/.claude/settings.json out of the repo..."
    mkdir -p "$HOME/.claude"
    mv "$old_repo_copy" "$live"
  elif [ "${AGENTS_ENABLED:-1}" = "1" ]; then
    info "Seeding ~/.claude/settings.json from the template..."
    mkdir -p "$HOME/.claude"
    cp "$DOTFILES_DIR/home/.claude/settings.template.json" "$live"
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
  setup_claude_settings
}
