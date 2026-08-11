#!/usr/bin/env bash

. sh/utils.sh

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

files=(
  ~/.zshrc
)

# One AGENTS.md, read by every agent. Each entry is a destination that gets a
# symlink back to the repo's AGENTS.md.
#
# Deliberately absent: ~/.claude/settings.json. On a work machine that file
# holds employer-provided config (API proxy base URL, model overrides, auth
# helper) mixed in with personal preferences. Symlinking it from here replaces
# the work half and breaks Claude Code. Leave it machine-local.
agent_links=(
  ~/.claude/CLAUDE.md
  ~/.codex/AGENTS.md
  ~/.config/opencode/AGENTS.md
)

# Rename the old config files before we symlink the new ones
rename_files() {
  for f in "${files[@]}"; do
    if file_exists "$f"; then
      info "$f exists. Renaming to $f.pre-setup"
      mv "$f" "$f.pre-setup"
    else
      info "$f doesn't exist. Skipping."
    fi
  done
}

# Run stow command
#
# No pre-emptive move of ~/.config here. stow refuses to overwrite a real file
# and reports the conflict, which is the behavior we want - moving the whole
# directory aside defeats that safety net and strands every unrelated config
# (nvim, gh, git, openspec, ...) at a path its tool no longer looks in.
sym_stow() {
  info "Symlinking dot files..."
  if ! stow -d "$DOTFILES_DIR/stow" -t ~ .; then
    err "stow reported a conflict."
    err "Move or delete the file it named, then re-run. Nothing was changed."
    return 1
  fi
}

# Point every agent's instruction file at the single AGENTS.md in this repo
link_agents() {
  local src="$DOTFILES_DIR/AGENTS.md"

  if ! file_exists "$src"; then
    warn "$src not found. Skipping agent links."
    return 0
  fi

  for dest in "${agent_links[@]}"; do
    mkdir -p "$(dirname "$dest")"

    # Only back up a real file. Re-running over our own symlink is a no-op.
    if file_exists "$dest" && [ ! -L "$dest" ]; then
      info "$dest exists. Renaming to $dest.pre-setup"
      mv "$dest" "$dest.pre-setup"
    fi

    ln -sfn "$src" "$dest"
    info "Linked $dest"
  done
}

# Create .zshrc.local if it doesn't exist
setup_zshrc_local() {
  if [ ! -f "$HOME/.zshrc.local" ]; then
    info "Creating .zshrc.local..."
    cp "$DOTFILES_DIR/stow/.zshrc.local.example" "$HOME/.zshrc.local"
    success "Created .zshrc.local (customize this for your machine)"
  else
    info ".zshrc.local already exists. Skipping."
  fi
}
