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
# so the nix layer and this one gate on the same committed value. Missing
# line means enabled, which matches checkouts that predate the flag.
agents_enabled() {
  [ "$(sed -nE 's/^[[:space:]]*agents = (true|false);.*/\1/p' "${DOTFILES_DIR:-.}/flake.nix" | head -n1)" != "false" ]
}

run_imperative() {
  info "⒈ Machine setup..."
  run_machine_setup
  success "Machine setup complete"
  echo ""

  info "⒉ Global tools..."
  run_tool_installs
  success "Global tools installed"
  echo ""

  if agents_enabled; then
    export AGENTS_ENABLED=1
    info "⒊ Agent fleet..."
    run_agent_installs
    success "Agent fleet installed"
    echo ""

    info "⒋ Agent skills..."
    install_skills
    echo ""
  else
    export AGENTS_ENABLED=0
    info "⒊ Agent fleet and skills skipped (agents = false in flake.nix)"
    echo ""
  fi

  info "⒌ Verifying installations..."
  verify_installations
}
