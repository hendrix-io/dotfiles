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

# Does it exist in brew?
in_brew() {
  brew list | grep "$@" &> /dev/null
}

file_exists() {
  test -f "$@"
}

folder_exists() {
  test -d "$@"
}

install_pkg() {
  brew install "$@" || echo "$@ failed to install"
}

# Update current packages
update_pkgs() {
  brew update
  brew upgrade
}

# Cleanup after ourselves
clean_up() {
  info "Cleaning up..."
  brew cleanup
}
