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
      if command -v no-mistakes > /dev/null 2>&1; then success "no-mistakes: installed"; else warn "no-mistakes: not found"; fi
      skill_count=$(find "$HOME/.claude/skills" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
      success "skills: ${skill_count:-0} installed"
    fi
  )
  return 0
}
