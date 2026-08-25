#!/usr/bin/env bash

# Resolve colors once. tput fails outright when $TERM is unset - piping the
# script, running it from CI, or sourcing it in a non-tty - so fall back to
# plain output instead of letting a `set -e` caller die on a color lookup.
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && tput sgr 0 >/dev/null 2>&1; then
  reset_color=$(tput sgr 0)
  blue=$(tput setaf 4)
  green=$(tput setaf 2)
  red=$(tput setaf 1)
  yellow=$(tput setaf 3)
else
  reset_color="" blue="" green="" red="" yellow=""
fi

info() {
  printf "%s[*] %s%s\n" "$blue" "$1" "$reset_color"
}

success() {
  printf "%s[*] %s%s\n" "$green" "$1" "$reset_color"
}

err() {
  printf "%s[*] %s%s\n" "$red" "$1" "$reset_color" >&2
}

warn() {
  printf "%s[*] %s%s\n" "$yellow" "$1" "$reset_color" >&2
}

in_cmd() {
  hash "$@" &> /dev/null
}

# Ask a yes/no question; echoes "y" or "n". Accepts y/yes/n/no in any
# casing (tr, not ${var,,}: macOS ships bash 3.2). An empty answer or EOF
# takes the default; anything else re-asks, so a typo can never opt a
# machine into (or out of) an action.
ask_yn() {
  local prompt=$1 default=$2 reply
  while true; do
    read -r -p "$prompt" reply || reply=""
    reply="$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')"
    case "$reply" in
      y|yes) echo "y"; return ;;
      n|no)  echo "n"; return ;;
      "")    echo "$default"; return ;;
      *)     printf 'Please answer y or n.\n' >&2 ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Machine identity
# ---------------------------------------------------------------------------

# Print this Mac's label in flake.nix's `machines` map. Reads
# ~/.dotfiles-machine (untracked); when the file is missing, derives the
# label from the login and writes it.
machine_label() {
  local f="$HOME/.dotfiles-machine" label
  if [ -f "$f" ]; then
    label="$(tr -d '[:space:]' < "$f")"
    if [ -n "$label" ]; then
      printf '%s' "$label"
      return 0
    fi
  fi
  label="$(derive_machine_label "$(whoami)")" || return 1
  printf '%s\n' "$label" > "$f"
  printf '%s' "$label"
}

# Print the machines-map label whose login matches $1. Fails on zero or
# multiple matches.
derive_machine_label() {
  awk -v login="$1" '
    /^[[:space:]]*machines[[:space:]]*=[[:space:]]*\{[[:space:]]*$/ { inm = 1; next }
    inm && /^[[:space:]]*\};/ { inm = 0 }
    inm && $2 == "=" && $3 == "\"" login "\";" { hits[++n] = $1 }
    END { if (n == 1) print hits[1]; else exit 1 }
  ' "${DOTFILES_DIR:-.}/flake.nix"
}

# Read one shared `key = value;` line from flake.nix (agents, cleanup,
# platform). Strings print without their quotes; missing keys print
# nothing.
flake_value() {
  sed -nE 's/^[[:space:]]*'"$1"'[[:space:]]*=[[:space:]]*"?([^";]+)"?;.*/\1/p' \
    "${DOTFILES_DIR:-.}/flake.nix" | head -n1
}

# Verification report, the last phase of run_imperative. Deliberately never
# fails: rebuild.sh must stay safe to run at any time, so a logged-out glab
# or a missing tool is a warn line, not an exit code. Runs in a subshell so
# sourcing nvm (not clean under `set -u`) can't leak or abort the caller.
verify_installations() {
  (
    set +eu
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    command -v node > /dev/null 2>&1 || { [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" > /dev/null 2>&1; }
    export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"

    if command -v node > /dev/null 2>&1; then success "node: $(node --version)"; else warn "node: not found"; fi
    if command -v pnpm > /dev/null 2>&1; then success "pnpm: $(pnpm --version)"; else warn "pnpm: not found"; fi
    if command -v bun > /dev/null 2>&1; then success "bun: $(bun --version)"; else warn "bun: not found"; fi
    if command -v openspec > /dev/null 2>&1; then success "openspec: $(openspec --version 2>/dev/null | head -1)"; else warn "openspec: not found"; fi
    if ! command -v gh > /dev/null 2>&1; then
      warn "gh: not on PATH (fresh bootstrap? restart the terminal, then re-run ./rebuild.sh)"
    elif gh auth status > /dev/null 2>&1; then
      success "gh: authenticated"
    else
      warn "gh: not authenticated (run: gh auth login)"
    fi
    if command -v glab > /dev/null 2>&1; then
      if glab auth status > /dev/null 2>&1; then success "glab: authenticated"; else warn "glab: not authenticated (run: glab auth login)"; fi
    fi

    if [ "${AGENTS_ENABLED:-1}" = "1" ]; then
      if command -v claude > /dev/null 2>&1; then success "claude: installed"; else warn "claude: not found"; fi
      if command -v codex > /dev/null 2>&1; then success "codex: installed"; else warn "codex: not found"; fi
      if command -v cursor-agent > /dev/null 2>&1; then success "cursor-agent: installed"; else warn "cursor-agent: not found"; fi
      if command -v pi > /dev/null 2>&1; then success "pi: installed"; else warn "pi: not found"; fi
      if command -v no-mistakes > /dev/null 2>&1; then success "no-mistakes: installed"; else warn "no-mistakes: not found"; fi
      skill_count=$(find "$HOME/.claude/skills" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
      success "skills: ${skill_count:-0} installed"
    fi
  )
  return 0
}
