# Global agent instructions

- Never use the em dash. Use a plain dash `-` instead.
- Lead with the answer, then the evidence. No preamble.
- Plain English over jargon. If a term is unavoidable, define it once on first
  use.
- When comparing options, describe what actually happens in each rather than
  labeling them "Option A / Option B".
- Report outcomes honestly. If tests fail, show the output. If a step was
  skipped, say which and why.
- Never commit unless explicitly asked. Finish the work, stage it if that
  helps, and report what changed - the decision to commit is mine.
- Never use `--no-verify`. If a hook fails, fix the cause.
- Never force-push to a shared branch.
- Never hand-edit `CHANGELOG.md` or any file marked auto-generated. Change the
  thing that generates it.
- Do not give much weight to development cost. Prefer quality, simplicity,
  robustness, scalability, and long term maintainability.
- For one-off or infrequent operational work, start with the simplest direct
  end-to-end path. Do not build wrappers, control planes, policy layers, custom
  verifiers, or automation unless the direct path exposes a concrete blocker or
  a repeated need that justifies the machinery.
- Add structure only when a requirement forces it, not in anticipation of one.
- Start by reproducing the bug end to end, as close to how a user would hit it
  as you can get. This is what finds the real cause instead of a plausible one.
- Fix root causes, not symptoms. If the real fix is out of scope, say so
  explicitly rather than papering over it.
- When testing a product end to end, be picky about the UI. If something looks
  off, even when unrelated to the current task, try to get it fixed along the
  way.
- Apply the same standard to lint errors, failing tests, and flaky tests. If you
  see one, fix it even when you did not cause it.
- Before using dynamic workflows, ultra code, or any harness feature that
  immediately spawns a large swarm of subagents, explain the tradeoffs and ask
  for explicit approval.
- Verify in a shell that does not inherit an already-populated environment when
  debugging shell config. An inherited PATH hides exactly the bug you are
  looking for.
