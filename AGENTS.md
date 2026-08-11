# Global agent instructions

Read by Claude Code, Codex, and opencode. `sh/files.sh` symlinks this one file
to `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, and
`~/.config/opencode/AGENTS.md`, so there is a single copy to edit.

Project-level `AGENTS.md` files override anything here.

## Version control

- Never commit unless explicitly asked. Finish the work, stage it if that
  helps, and report what changed - the decision to commit is mine.
- Never add yourself as a commit co-author.
- Never use `--no-verify`. If a hook fails, fix the cause.
- Never force-push to a shared branch.

## Working style

- Start with the simplest version that could work. Add structure only when a
  concrete requirement forces it, not in anticipation of one.
- Prefer `const` and early returns over reassigning a `let`.
- Comments earn their place. Delete anything that restates the code; keep the
  ones that explain a non-obvious *why*, and keep them short.
- Fix root causes, not symptoms. If the real fix is out of scope, say so
  explicitly rather than papering over it.

## Communication

- Lead with the answer, then the evidence. No preamble.
- Plain English over jargon. If a term is unavoidable, define it once on first
  use.
- When comparing options, describe what actually happens in each rather than
  labeling them "Option A / Option B".
- Report outcomes honestly. If tests fail, show the output. If a step was
  skipped, say which and why.

## Secrets

- Never write a credential into a tracked file. Machine-specific secrets go in
  `~/.zshrc.local`, which is gitignored.
- Never echo the value of a secret into terminal output when a check on its
  presence would do.
