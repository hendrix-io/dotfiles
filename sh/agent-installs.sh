#!/usr/bin/env bash

# The agent fleet: everything specific to running AI agents on this machine.
# The orchestrator skips this whole file when agents = false in flake.nix;
# the same flag gates the herdr brew and the AGENTS.md links on the nix side.

. sh/utils.sh

FIRSTMATE_DIR="${FIRSTMATE_DIR:-$HOME/code/firstmate}"

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

# gnhf: overnight agent loop orchestrator (good night, have fun). Its
# default-packages entry lives here rather than in tool-installs.sh so a
# no-agents machine never reinstalls it on node upgrades.
install_gnhf() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    warn "nvm is not installed. Skipping gnhf."
    return 0
  fi
  local f="$NVM_DIR/default-packages"
  touch "$f"
  if ! grep -qx "gnhf" "$f"; then
    info "Adding gnhf to nvm default-packages..."
    echo "gnhf" >> "$f"
  fi
  (
    set +eu
    . "$NVM_DIR/nvm.sh"
    if ! command -v gnhf > /dev/null 2>&1; then
      info "Installing gnhf..."
      npm install -g gnhf || warn "gnhf failed to install"
    fi
  ) || warn "gnhf install had errors - re-run ./rebuild.sh"
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

# firstmate is an agent distro: the clone IS the install. Launch a harness
# inside it (`cd` there, then `claude`) and its AGENTS.md takes over. It
# needs gh authenticated at runtime, which auth_github handles.
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

# ~/.claude/settings.json is deliberately a real file, not a repo symlink:
# Claude Code writes runtime config into it, and a live symlink would land
# those writes in this public repo's working tree (that nearly leaked
# fr8factory internals once). Seed it from the committed template; after
# that, the machine owns it.
setup_claude_settings() {
  if [ -f "$HOME/.claude/settings.json" ]; then
    return 0
  fi
  mkdir -p "$HOME/.claude"
  if [ -f "$DOTFILES_DIR/home/.claude/settings.json" ]; then
    # One-time migration from the old symlinked layout: adopt the previous
    # live content instead of resetting to the template. The file is
    # untracked (gitignored) by the time this branch exists, so the move
    # cannot lose anything git holds.
    info "Migrating ~/.claude/settings.json out of the repo..."
    mv "$DOTFILES_DIR/home/.claude/settings.json" "$HOME/.claude/settings.json"
  else
    info "Seeding ~/.claude/settings.json from the template..."
    cp "$DOTFILES_DIR/home/.claude/settings.template.json" "$HOME/.claude/settings.json"
  fi
}

run_agent_installs() {
  install_claude
  install_gnhf
  install_no_mistakes
  clone_firstmate
  setup_claude_settings
}
