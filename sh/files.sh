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

# What rename_files moved, so restore_files can put it back exactly.
renamed_from=()
renamed_to=()

# Rename the old config files before we symlink the new ones.
#
# Two things this must never do, both learned the hard way:
#   - Back up a symlink. `test -f` follows symlinks, so on a second run it
#     would move our own stow link on top of the real backup and destroy it.
#     A symlink means the file is already stowed; there is nothing to save.
#   - Overwrite an existing .pre-setup. If one is already there, timestamp the
#     new one instead of silently replacing a backup you may still need.
rename_files() {
  renamed_from=()
  renamed_to=()

  for f in "${files[@]}"; do
    if [ -L "$f" ]; then
      info "$f is already a symlink. Nothing to back up."
      continue
    fi

    if ! file_exists "$f"; then
      info "$f doesn't exist. Skipping."
      continue
    fi

    local backup="$f.pre-setup"
    if [ -e "$backup" ]; then
      backup="$f.pre-setup.$(date +%Y%m%d%H%M%S)"
      warn "$f.pre-setup already exists, so backing up to $backup instead."
    fi

    info "$f exists. Renaming to $backup"
    mv "$f" "$backup"
    renamed_from+=("$f")
    renamed_to+=("$backup")
  done
}

# Put back what rename_files moved aside.
#
# rename_files has to run before stow (stow refuses to link over a real file),
# which means a stow failure would otherwise leave you with no ~/.zshrc at all -
# no nvm, no prompt, no PATH, in every new terminal.
restore_files() {
  local i=0
  while [ "$i" -lt "${#renamed_from[@]}" ]; do
    local orig="${renamed_from[$i]}"
    local backup="${renamed_to[$i]}"

    if [ -e "$backup" ] && [ ! -e "$orig" ]; then
      info "Restoring $orig from $backup"
      mv "$backup" "$orig"
    fi

    i=$((i + 1))
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

# Lines in a backed-up .zshrc that look machine-specific: credentials and PATH
# entries. Deliberately NOT migrated automatically - the malformed and duplicate
# entries that accumulate in a hand-edited .zshrc should not be carried forward
# blindly, and a credential should move by your hand, not a script's.
MIGRATE_PATTERN='TOKEN|SECRET|API_KEY|PASSWORD|_KEY=|export PATH='

# Tell the user what was left behind, with commands they can paste.
# Prints the matching line COUNT, never the matching lines - the whole point is
# to avoid dumping a token into terminal scrollback.
report_migration() {
  local backup="$HOME/.zshrc.pre-setup"
  file_exists "$backup" || return 0

  local n
  n=$(grep -cE "$MIGRATE_PATTERN" "$backup" 2>/dev/null || true)
  [ "${n:-0}" -gt 0 ] || return 0

  echo ""
  warn "$n line(s) in ~/.zshrc.pre-setup look machine-specific and were not carried over."
  echo ""
  echo "  1. See what they are:"
  echo ""
  echo "       grep -nE '$MIGRATE_PATTERN' ~/.zshrc.pre-setup"
  echo ""
  echo "  2. Append them to your gitignored local config:"
  echo ""
  echo "       grep -E '$MIGRATE_PATTERN' ~/.zshrc.pre-setup >> ~/.zshrc.local"
  echo ""
  echo "  3. Open it and drop anything stale - duplicated PATH entries, paths"
  echo "     for tools you no longer have:"
  echo ""
  echo "       \${EDITOR:-vi} ~/.zshrc.local && source ~/.zshrc"
  echo ""
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
