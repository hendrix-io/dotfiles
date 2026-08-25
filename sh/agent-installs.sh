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

# Cursor's terminal agent, via its official installer. It never edits rc
# files - it only prints PATH advice when ~/.local/bin isn't on PATH, and
# the pre-seeded PATH avoids even that. Versions live under
# ~/.local/share/cursor-agent with a symlink in ~/.local/bin; inert until
# you sign in with a Cursor account.
install_cursor_cli() {
  if in_cmd "cursor-agent" || [ -x "$HOME/.local/bin/cursor-agent" ]; then
    info "cursor-agent is already installed. Skipping."
    return 0
  fi
  info "Installing Cursor CLI..."
  mkdir -p "$HOME/.local/bin"
  curl -fsS https://cursor.com/install | PATH="$HOME/.local/bin:$PATH" bash ||
    warn "Cursor CLI failed to install"
}

# Pi, via its official installer in managed mode (PI_EXPERIMENTAL=1):
# releases live under ~/.pi/agent/install with a launcher symlinked into
# ~/.local/bin, so pi still resolves when nvm switches node versions.
# (The installer's default mode is `npm install -g` into the active node
# version's bin, which does not.) Update with `pi update`.
#
# The installer's confirm menu reads /dev/tty and would block a rebuild,
# so it runs detached from the terminal (fork + setsid via python3); the
# no-tty path installs without asking and never edits rc files. Needs
# node >=22.19 and npm at install and run time, hence the nvm subshell.
install_pi() {
  if in_cmd "pi" || [ -x "$HOME/.local/bin/pi" ]; then
    info "pi is already installed. Skipping."
    return 0
  fi
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    warn "nvm is not installed. Skipping pi."
    return 0
  fi
  info "Installing Pi..."
  mkdir -p "$HOME/.local/bin"
  (
    set +eu
    . "$NVM_DIR/nvm.sh"
    installer="$(mktemp)" || exit 1
    trap 'rm -f "$installer"' EXIT
    curl -fsSL https://pi.dev/install.sh -o "$installer" || exit 1
    PI_EXPERIMENTAL=1 PATH="$HOME/.local/bin:$PATH" python3 - "$installer" <<'PY'
import os, sys

pid = os.fork()
if pid:
    _, status = os.waitpid(pid, 0)
    sys.exit(os.waitstatus_to_exitcode(status))
os.setsid()
os.execv("/bin/sh", ["sh", sys.argv[1]])
PY
  ) || warn "Pi failed to install"
}

# Seed ~/.pi/agent/settings.json from the template once; after that the
# machine owns it. Not a symlink: pi rewrites the file at runtime, and a
# symlink would land those writes in this public repo (same reasoning as
# Claude's settings, see home.nix). defaultProvider, defaultModel, and
# auth.json are never seeded - they hold work-specific LiteLLM values.
seed_pi_settings() {
  local live="$HOME/.pi/agent/settings.json"
  if [ -f "$live" ]; then
    return 0
  fi
  info "Seeding ~/.pi/agent/settings.json from the template..."
  mkdir -p "$HOME/.pi/agent"
  cp "$DOTFILES_DIR/home/.pi/agent/settings.template.json" "$live"
}

# Codex, OpenAI's terminal agent, via its official installer - it adds a
# PATH block to the shell rc only when ~/.local/bin isn't already on PATH,
# so the pre-seeded PATH prevents the rc edit (same trick as claude and
# cursor-agent). Inert until `codex` logs in; an existing ChatGPT account
# works, no separate billing.
install_codex() {
  if in_cmd "codex" || [ -x "$HOME/.local/bin/codex" ]; then
    info "codex is already installed. Skipping."
    return 0
  fi
  info "Installing Codex..."
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://chatgpt.com/codex/install.sh | PATH="$HOME/.local/bin:$PATH" sh ||
    warn "Codex failed to install"
}

# The flip-off counterpart to the installers above: without this, stale
# entries in default-packages reinstall agent CLIs on every node upgrade
# of a machine that turned the fleet off. @openai/codex is legacy cleanup
# from when codex was npm-installed; it is never added anymore.
remove_agent_default_packages() {
  local f="${NVM_DIR:-$HOME/.nvm}/default-packages"
  [ -f "$f" ] || return 0
  local pkg
  for pkg in gnhf @openai/codex; do
    if grep -qx "$pkg" "$f"; then
      info "Removing $pkg from nvm default-packages (agents = false)..."
      grep -vx "$pkg" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    fi
  done
}

run_agent_installs() {
  install_claude
  install_codex
  install_cursor_cli
  install_pi
  seed_pi_settings
  install_gnhf
  install_no_mistakes
  clone_firstmate
}
