#!/usr/bin/env bash
#
# Agent skill installation
#
# Third-party skills, installed imperatively so their upstream repos stay
# the source of truth - never vendored into this repo. SKILL.md instructions
# run with full agent permissions, so review a skill (and its non-markdown
# files) before adding it to a list here.
#
# The skills CLI lands everything in ~/.agents/skills and creates
# per-harness symlinks (~/.claude/skills for Claude Code, plus Codex).

. sh/utils.sh

# Skill repository definitions
belsrc_skills=(
  "engineering-council"
  "socratic-tutor"
  "ticket-creator"
)

hypergiant_skills=(
  "accelint-qrspi-propose"
  "accelint-qrspi-apply"
  "accelint-qrspi-archive"
  "accelint-archive-synthesis"
  "accelint-architecture-doc"
  # Upstream's directory is "accelint-onboard-agent", but the CLI selects
  # by the SKILL.md name field, which is plural.
  "accelint-onboard-agents"
  "accelint-onboard-openspec"
  "accelint-readme-writer"
  "accelint-prompt-manager"
  "accelint-english-manager"
)

# Install a single skill via the skills CLI.
# The CLI is idempotent on its own, but the directory guard keeps routine
# rebuilds from paying an npx startup per skill.
# -a installs for both harnesses (Claude Code and Codex).
install_skill() {
  local repo_url=$1
  local skill_name=$2

  if [ -d "$HOME/.claude/skills/$skill_name" ] || [ -d "$HOME/.agents/skills/$skill_name" ]; then
    return 0
  fi

  info "Installing skill: $skill_name..."
  if npx -y skills add -g -y "$repo_url" --skill "$skill_name" -a claude-code -a codex > /dev/null; then
    success "$skill_name installed"
  else
    warn "$skill_name installation may have failed"
  fi
}

# lavish: review agent-generated HTML in a browser. The CLI itself is
# install-free (`npx -y lavish-axi`); only the skill gets installed.
install_lavish_skill() {
  install_skill "kunchenguid/lavish-axi" "lavish"
}

install_belsrc_skills() {
  local repo_url="https://github.com/belsrc/skills"

  for skill in "${belsrc_skills[@]}"; do
    install_skill "$repo_url" "$skill"
  done
}

install_hypergiant_skills() {
  local repo_url="https://github.com/gohypergiant/agent-skills"

  for skill in "${hypergiant_skills[@]}"; do
    install_skill "$repo_url" "$skill"
  done
}

# Main skill installation orchestrator.
# npx comes from nvm, which isn't on PATH during a fresh bootstrap, so the
# whole run happens in a subshell with nvm sourced (nvm.sh is not clean
# under `set -u`, hence set +eu - same pattern as install_node_layer).
install_skills() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if ! command -v npx > /dev/null 2>&1 && [ ! -s "$NVM_DIR/nvm.sh" ]; then
    warn "npx is unavailable. Skipping skill installation - re-run ./rebuild.sh."
    return 0
  fi
  (
    set +eu
    command -v npx > /dev/null 2>&1 || . "$NVM_DIR/nvm.sh"

    install_lavish_skill
    install_belsrc_skills
    install_hypergiant_skills
  ) || warn "skill installation had errors - re-run ./rebuild.sh"
}
