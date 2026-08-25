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
  echo "You're at the keyboard for: your password (sudo), one go-ahead on"
  echo "this machine's committed choices, and gh auth. Everything else is"
  echo "unattended."
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

info "Step 3: machine identity"
# Resolve which machines-map entry this Mac uses: reads
# ~/.dotfiles-machine, or matches the login and writes it.
if ! MACHINE="$(machine_label)"; then
  err "Login \"$(whoami)\" matches no machine in flake.nix's machines block."
  err "Add an entry for this Mac to the machines map (label = \"login\";),"
  err "or pick a label by hand: echo <label> > ~/.dotfiles-machine - then re-run."
  exit 1
fi
info "This is machine \"$MACHINE\"."

info "Step 4: check the machine's configured platform"
# Nothing to ask: uname is the ground truth.
case "$(uname -m)" in
  arm64)  PLATFORM="aarch64-darwin" ;;
  x86_64) PLATFORM="x86_64-darwin" ;;
  *) err "Unsupported CPU: $(uname -m)"; exit 1 ;;
esac
FLAKE_PLATFORM="$(flake_value platform)"
if [ "$FLAKE_PLATFORM" != "$PLATFORM" ]; then
  err "flake.nix declares platform \"$FLAKE_PLATFORM\", but this is a $PLATFORM Mac."
  err "Fix the platform line in flake.nix, then re-run."
  exit 1
fi
info "Platform matches $PLATFORM."

info "Step 5: review the committed choices"
CLEANUP="$(flake_value cleanup)"
AGENTS="$(flake_value agents)"
if [ -z "$CLEANUP" ] || [ -z "$AGENTS" ]; then
  err "Could not read the cleanup/agents lines from flake.nix."
  exit 1
fi
info "agents = $AGENTS (the fleet: Claude Code, Codex, Cursor, Pi, firstmate,"
info "gnhf, no-mistakes, herdr, the skills, and the AGENTS.md links)"
warn "brew cleanup = $CLEANUP"
if [ "$CLEANUP" = "uninstall" ]; then
  warn "Every switch - including the one about to run - UNINSTALLS any brew"
  warn "package or cask not listed in configuration.nix."
else
  warn "Switches install what is listed and keep everything else."
fi
# Default the go-ahead to No on a first bootstrap when cleanup is
# "uninstall": pressing Enter must not delete existing brew packages.
# Machines that have switched before default to Yes.
if [ "$CLEANUP" = "uninstall" ] && ! in_cmd darwin-rebuild; then
  GO_DEFAULT="n"; GO_HINT="[y/N]"
else
  GO_DEFAULT="y"; GO_HINT="[Y/n]"
fi
if [ "$(ask_yn "Proceed with this configuration? $GO_HINT " "$GO_DEFAULT")" = "n" ]; then
  err "Edit flake.nix, then re-run."
  exit 1
fi

info "Step 6: first darwin-rebuild switch"
# On a Mac that had Homebrew before, brew's Ruby startup cache (bootsnap)
# was built by the old brew version; the nix-pinned brew reads it and dies
# with "rb_file_s_lstat - .../bootsnap/...". It is only a cache - clear it
# so the migrated brew starts clean.
rm -rf "$HOME/Library/Caches/Homebrew/bootsnap"
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
sudo "$NIX_BIN" run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
  switch --flake ~/.dotfiles#"$MACHINE"
# If this fails with "nix: command not found", open a new terminal
# (Determinate adds nix to new shells' PATH) and re-run ./bootstrap.sh.

info "Step 7: imperative layer (auth, node toolchain, agent fleet)"
INTERACTIVE=1 run_imperative

success "Done. Use ./rebuild.sh for future changes."
info "Restart your terminal so the new PATH and prompt load."
