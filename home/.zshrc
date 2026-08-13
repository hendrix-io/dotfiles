# Machine-agnostic shell config. Anything specific to one machine - secrets,
# per-host PATH entries, work tooling - belongs in ~/.zshrc.local, which is
# gitignored and sourced at the very bottom of this file.

# Dedupe PATH automatically. `path` and `PATH` stay tied together, so appending
# the same entry twice is a no-op instead of growing the variable forever.
typeset -U path PATH

# Homebrew prefix, without paying for `brew --prefix` on every shell start.
if [ -x /opt/homebrew/bin/brew ]; then
  HOMEBREW_PREFIX=/opt/homebrew          # Apple Silicon
elif [ -x /usr/local/bin/brew ]; then
  HOMEBREW_PREFIX=/usr/local             # Intel
fi

# Put Homebrew on PATH. This is NOT optional and NOT redundant with the system
# default: macOS `path_helper` only reads /etc/paths and /etc/paths.d, neither of
# which Homebrew writes to. Without this (or a .zprofile running `brew
# shellenv`) a fresh login shell has no brew, no starship, no stow, no ripgrep -
# and because the blocks below are all guarded on the binary existing, they fail
# silently and you just get the stock `%n@%m %1~ %#` prompt with no error.
#
# Doing it here rather than in .zprofile also covers non-login interactive
# shells, which read only this file.
if [ -n "$HOMEBREW_PREFIX" ]; then
  export HOMEBREW_PREFIX
  path=("$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin" $path)
fi

# ---------------------------------------------------------------------------
# completions
# ---------------------------------------------------------------------------

# OPENSPEC:START
# OpenSpec shell completions configuration (only if directory exists)
[ -d "$HOME/.zsh/completions" ] && fpath=("$HOME/.zsh/completions" $fpath)
# OPENSPEC:END

[ -n "$HOMEBREW_PREFIX" ] && [ -d "$HOMEBREW_PREFIX/share/zsh/site-functions" ] &&
  fpath=("$HOMEBREW_PREFIX/share/zsh/site-functions" $fpath)

# Once, after every fpath entry is registered.
autoload -Uz compinit && compinit

# ---------------------------------------------------------------------------
# node: nvm, with auto-switch on .nvmrc
# ---------------------------------------------------------------------------

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

  # Must come after nvm is loaded - load-nvmrc calls nvm_find_nvmrc.
  autoload -U add-zsh-hook

  load-nvmrc() {
    local nvmrc_path
    nvmrc_path="$(nvm_find_nvmrc)"

    if [ -n "$nvmrc_path" ]; then
      local nvmrc_node_version
      nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

      if [ "$nvmrc_node_version" = "N/A" ]; then
        nvm install
      elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then
        nvm use
      fi
    elif [ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" ] && [ "$(nvm version)" != "$(nvm version default)" ]; then
      echo "Reverting to nvm default version"
      nvm use default
    fi
  }

  add-zsh-hook chpwd load-nvmrc
  load-nvmrc
fi

# ---------------------------------------------------------------------------
# node: pnpm
# ---------------------------------------------------------------------------

# pnpm's own default install location, per OS - never a hardcoded user path.
if [ -z "${PNPM_HOME:-}" ]; then
  case "$OSTYPE" in
    darwin*) export PNPM_HOME="$HOME/Library/pnpm" ;;
    *)       export PNPM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm" ;;
  esac
fi
[ -d "$PNPM_HOME" ] && path=("$PNPM_HOME" $path)

# ---------------------------------------------------------------------------
# node: bun
# ---------------------------------------------------------------------------

export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
if [ -d "$BUN_INSTALL" ]; then
  path=("$BUN_INSTALL/bin" $path)
  [ -s "$BUN_INSTALL/_bun" ] && . "$BUN_INSTALL/_bun"
fi

# ---------------------------------------------------------------------------
# user-local binaries
# ---------------------------------------------------------------------------

# no-mistakes symlinks itself here, but only when this is already on PATH -
# otherwise its installer sudo-links into /usr/local/bin instead.
[ -d "$HOME/.local/bin" ] && path=("$HOME/.local/bin" $path)

# ---------------------------------------------------------------------------
# zsh plugins
# ---------------------------------------------------------------------------

if [ -n "$HOMEBREW_PREFIX" ]; then
  _zsh_autosuggest="$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  if [ -s "$_zsh_autosuggest" ]; then
    . "$_zsh_autosuggest"
    bindkey '^f' autosuggest-accept   # ctrl-F takes the ghost text
  fi
  unset _zsh_autosuggest

  # Syntax highlighting wraps the line editor, so it has to be sourced after
  # anything else that binds keys or defines widgets.
  _zsh_highlight="$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  [ -s "$_zsh_highlight" ] && . "$_zsh_highlight"
  unset _zsh_highlight
fi

# ---------------------------------------------------------------------------
# prompt
# ---------------------------------------------------------------------------

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship/starship.toml"
command -v starship >/dev/null && eval "$(starship init zsh)"

# ---------------------------------------------------------------------------
# machine-specific config - keep this last so it can override anything above
# ---------------------------------------------------------------------------

# An `if` block rather than `[ -f ... ] &&` on purpose: the latter returns 1
# when the file is absent, and that becomes $? at the first prompt, so starship
# opens every new terminal showing its red error symbol.
if [ -f "$HOME/.zshrc.local" ]; then
  . "$HOME/.zshrc.local"
fi

# pnpm
export PNPM_HOME="/Users/aessex/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

# bun completions
[ -s "/Users/aessex/.bun/_bun" ] && source "/Users/aessex/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
