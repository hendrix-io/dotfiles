#!/usr/bin/env bash

# The imperative layer's orchestrator: everything the declarative build
# can't own lives in the sh/ modules, and this file only sequences the
# phases. INTERACTIVE=1 (bootstrap) may stop and prompt; INTERACTIVE=0
# (rebuild) warns instead, so a routine rebuild never blocks on input.

. sh/utils.sh
. sh/machine.sh
. sh/tool-installs.sh
. sh/agent-installs.sh
. sh/skill-installs.sh

# The agents flag lives in flake.nix (bootstrap asks once and rewrites it),
# so the nix layer and this one gate on the same committed value. An
# unparseable or missing line warns and defaults to enabled, which matches
# checkouts that predate the flag - and mirrors nix, which would fail eval
# outright if the binding disappeared.
agents_enabled() {
  local v
  v="$(sed -nE 's/^[[:space:]]*agents[[:space:]]*=[[:space:]]*(true|false)[[:space:]]*;.*/\1/p' "${DOTFILES_DIR:-.}/flake.nix" | head -n1)"
  if [ -z "$v" ]; then
    warn "Could not read the agents flag from flake.nix; assuming enabled."
    v="true"
  fi
  [ "$v" != "false" ]
}

run_imperative() {
  if agents_enabled; then
    AGENTS_ENABLED=1
  else
    AGENTS_ENABLED=0
  fi
  export AGENTS_ENABLED

  info "[1/5] Machine setup..."
  run_machine_setup
  success "Machine setup complete"
  echo ""

  info "[2/5] Global tools..."
  run_tool_installs
  success "Global tools installed"
  echo ""

  if [ "$AGENTS_ENABLED" = "1" ]; then
    info "[3/5] Agent fleet..."
    run_agent_installs
    success "Agent fleet installed"
    echo ""

    info "[4/5] Agent skills..."
    install_skills
    echo ""
  else
    info "[3/5] Agent fleet skipped (agents = false in flake.nix)"
    info "[4/5] Agent skills skipped"
    remove_gnhf_default_package
    echo ""
  fi

  info "[5/5] Verifying installations..."
  verify_installations
}
