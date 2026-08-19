#!/usr/bin/env bash

# Takes a fresh Mac from nothing to the full setup: Determinate Nix, the
# declarative nix-darwin system, then the imperative layer Nix can't own
# (auth, node toolchain, firstmate). Run once. After it finishes, use
# ./rebuild.sh for every later change.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$DIR"
export DOTFILES_DIR="$DIR"

. sh/utils.sh
. sh/installs.sh

if [ "${1:-}" = "--help" ]; then
  echo ""
  echo "bootstrap.sh - take a fresh Mac to the full setup. Run once."
  echo ""
  echo "You're at the keyboard for: your password (sudo), the flake username"
  echo "rewrite, the Homebrew cleanup choice, the AI/agent tooling choice,"
  echo "and gh auth. Everything else is unattended."
  echo ""
  echo "After it finishes, use ./rebuild.sh for every later change."
  echo ""
  exit 0
fi

# The banner is cosmetic; only colorize on a real terminal so piped or
# logged output never carries raw escape bytes.
[ -t 1 ] && printf "%s" "$(tput setaf 13 2>/dev/null || true)"
cat <<'BANNER'
██╗  ██╗███████╗███╗   ██╗██████╗ ██████╗ ██╗██╗  ██╗      ██╗ ██████╗
██║  ██║██╔════╝████╗  ██║██╔══██╗██╔══██╗██║╚██╗██╔╝      ██║██╔═══██╗
███████║█████╗  ██╔██╗ ██║██║  ██║██████╔╝██║ ╚███╔╝ █████╗██║██║   ██║
██╔══██║██╔══╝  ██║╚██╗██║██║  ██║██╔══██╗██║ ██╔██╗ ╚════╝██║██║   ██║
██║  ██║███████╗██║ ╚████║██████╔╝██║  ██║██║██╔╝ ██╗      ██║╚██████╔╝
╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝      ╚═╝ ╚═════╝
BANNER
[ -t 1 ] && printf "%s" "$(tput sgr0 2>/dev/null || true)"
echo ""

info "Step 1: Determinate Nix"
if in_cmd nix; then
  info "nix is already installed. Skipping."
else
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

info "Step 2: symlink this repo to ~/.dotfiles"
# home.nix resolves its mkOutOfStoreSymlink paths through ~/.dotfiles, so
# this has to exist before the first switch or the build can't find them.
ln -sfn "$DIR" ~/.dotfiles

info "Step 3: check the configured username"
# Before any sudo call: sudo resets $USER to root, so whoami has to run as
# the real interactive user first.
REAL_USER="$(whoami)"
FLAKE_USER="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' flake.nix | head -n1)"
if [ -z "$FLAKE_USER" ]; then
  err "Could not find the single \"user = \" line in flake.nix."
  err "Edit flake.nix yourself, then re-run."
  exit 1
elif [ "$FLAKE_USER" != "$REAL_USER" ]; then
  warn "flake.nix is configured for \"$FLAKE_USER\", but you are \"$REAL_USER\"."
  if [ "$(ask_yn "Rewrite flake.nix's \"user = \" line to \"$REAL_USER\"? [y/N] " n)" = "y" ]; then
    sed -i '' -E "s/^([[:space:]]*user = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" flake.nix
    info "Updated. Review the change with: git diff flake.nix"
  else
    err "Skipped. Edit the \"user = \" line in flake.nix yourself, then re-run."
    exit 1
  fi
else
  info "flake.nix already matches \"$REAL_USER\". Nothing to do."
fi

info "Step 4: check the configured CPU platform"
# Unlike the username, there is nothing to ask: uname is the ground truth.
case "$(uname -m)" in
  arm64)  PLATFORM="aarch64-darwin" ;;
  x86_64) PLATFORM="x86_64-darwin" ;;
  *) err "Unsupported CPU: $(uname -m)"; exit 1 ;;
esac
FLAKE_PLATFORM="$(sed -nE 's/^[[:space:]]*nixpkgs\.hostPlatform = "([^"]+)";.*/\1/p' configuration.nix | head -n1)"
if [ -z "$FLAKE_PLATFORM" ]; then
  err "Could not find the nixpkgs.hostPlatform line in configuration.nix."
  exit 1
elif [ "$FLAKE_PLATFORM" != "$PLATFORM" ]; then
  info "This is a $PLATFORM machine; rewriting configuration.nix (was $FLAKE_PLATFORM)."
  sed -i '' -E "s/^([[:space:]]*nixpkgs\.hostPlatform = \")[^\"]+(\";.*)/\1${PLATFORM}\2/" configuration.nix
  info "Updated. Review the change with: git diff configuration.nix"
else
  info "configuration.nix already matches $PLATFORM. Nothing to do."
fi

info "Step 5: choose Homebrew cleanup behavior"
# The one genuinely destructive setting, so it is an explicit choice, not a
# default. It has to be settled before the first switch runs brew.
CLEANUP="$(sed -nE 's/^[[:space:]]*onActivation\.cleanup = "([^"]+)";.*/\1/p' configuration.nix | head -n1)"
if [ -z "$CLEANUP" ]; then
  err "Could not find the onActivation.cleanup line in configuration.nix."
  exit 1
fi
warn "Homebrew cleanup is currently \"$CLEANUP\"."
warn "\"uninstall\": every time this config is applied (at the end of this"
warn "script, and on each later ./rebuild.sh), any brew package or app NOT"
warn "listed in configuration.nix is uninstalled. \"none\": install what is"
warn "listed, keep everything else. On a machine that already has Homebrew"
warn "packages, choose n until the lists include everything you want to keep."
# On a machine that has bootstrapped before (darwin-rebuild exists), default
# to the committed value so pressing Enter on a re-run changes nothing. A
# first run always defaults to the safe "none", whatever the fork committed.
if [ "$CLEANUP" = "uninstall" ] && in_cmd darwin-rebuild; then
  CLEANUP_DEFAULT="y"; CLEANUP_HINT="[Y/n]"
else
  CLEANUP_DEFAULT="n"; CLEANUP_HINT="[y/N]"
fi
if [ "$(ask_yn "Uninstall unlisted brew packages every time the config is applied? $CLEANUP_HINT " "$CLEANUP_DEFAULT")" = "y" ]; then
  TARGET="uninstall"
else
  TARGET="none"
fi
if [ "$TARGET" != "$CLEANUP" ]; then
  sed -i '' -E "s/^([[:space:]]*onActivation\.cleanup = \")[^\"]+(\";.*)/\1${TARGET}\2/" configuration.nix
  info "Updated to \"$TARGET\". Review the change with: git diff configuration.nix"
else
  info "Already \"$TARGET\". Nothing to do."
fi

info "Step 6: choose whether to install the AI/agent tooling"
# Settled before the first switch because the flag also gates nix-side
# pieces (the herdr brew, the AGENTS.md links).
AGENTS="$(sed -nE 's/^[[:space:]]*agents[[:space:]]*=[[:space:]]*(true|false)[[:space:]]*;.*/\1/p' flake.nix | head -n1)"
if [ -z "$AGENTS" ]; then
  err "Could not find the agents line in flake.nix."
  exit 1
fi
warn "The agent fleet is Claude Code, Codex, firstmate, gnhf, no-mistakes,"
warn "herdr, the third-party skills, and the AGENTS.md links for every AI harness."
warn "Answer n for a plain development machine with none of it."
# Default to the committed value - the fork owner's standing choice - so
# Enter on a re-run changes nothing.
if [ "$AGENTS" = "true" ]; then
  AGENTS_DEFAULT="y"; AGENTS_HINT="[Y/n]"
else
  AGENTS_DEFAULT="n"; AGENTS_HINT="[y/N]"
fi
if [ "$(ask_yn "Install the AI/agent tooling? $AGENTS_HINT " "$AGENTS_DEFAULT")" = "n" ]; then
  TARGET="false"
else
  TARGET="true"
fi
if [ "$TARGET" != "$AGENTS" ]; then
  sed -i '' -E "s/^([[:space:]]*agents[[:space:]]*=[[:space:]]*)(true|false)([[:space:]]*;.*)/\1${TARGET}\3/" flake.nix
  info "Updated to ${TARGET}. Review the change with: git diff flake.nix"
else
  info "Already ${TARGET}. Nothing to do."
fi

info "Step 7: first darwin-rebuild switch"
# Migration aid for machines coming from the old layout, where the live
# Claude settings were a symlink into this repo: the switch is about to
# remove that link, so save the content first. sh/machine.sh adopts the
# snapshot afterwards.
if [ -L "$HOME/.claude/settings.json" ] && [ -e "$HOME/.claude/settings.json" ]; then
  cp -L "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.pre-migration"
fi
# darwin-rebuild doesn't exist yet on a fresh machine, so run it straight
# from the nix-darwin flake this once. The system config it applies is still
# pinned by this repo's flake.lock.
#
# sudo resets PATH to a secure default that excludes /nix/.../bin, so resolve
# nix's absolute path first and invoke that.
NIX_BIN="$(command -v nix)"
# "mac" is the flake host label - if you rename it, change it here, in
# flake.nix, and in rebuild.sh.
sudo "$NIX_BIN" run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
  switch --flake ~/.dotfiles#mac
# If this fails with "nix: command not found", open a new terminal
# (Determinate adds nix to new shells' PATH) and re-run ./bootstrap.sh.

info "Step 8: imperative layer (auth, node toolchain, agent fleet)"
INTERACTIVE=1 run_imperative

success "Done. Use ./rebuild.sh for future changes."
info "Restart your terminal so the new PATH and prompt load."
