#!/usr/bin/env bash

reset_color=$(tput sgr 0)

info() {
  printf "%s[*] %s%s\n" "$(tput setaf 4)" "$1" "$reset_color"
}

success() {
  printf "%s[*] %s%s\n" "$(tput setaf 2)" "$1" "$reset_color"
}

err() {
  printf "%s[*] %s%s\n" "$(tput setaf 1)" "$1" "$reset_color"
}

warn() {
  printf "%s[*] %s%s\n" "$(tput setaf 3)" "$1" "$reset_color"
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
