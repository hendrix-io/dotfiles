# dotfiles

My personal configuration files, managed with GNU Stow.

## What's included

**Shell and terminal**

- **Zsh** - nvm with `.nvmrc` auto-switching, pnpm, bun, autosuggestions, syntax highlighting, self-deduplicating PATH
- **Starship prompt** - minimal, fast, with git status
- **Ghostty** - ayu theme, Hack Nerd Font
- **CLI tools** - ripgrep, fd, fzf, lazygit, neovim, tmux, gh, glab

**Agent tooling**

- **Shared `AGENTS.md`** - one file read by Claude Code, Codex, and opencode
- **[no-mistakes](https://github.com/kunchenguid/no-mistakes)** - local validation gate, aliased to `gate`
- **[treehouse](https://github.com/kunchenguid/treehouse)** - pool of reusable git worktrees with warm dependencies
- **[lavish](https://github.com/kunchenguid/lavish-axi)** - review agent-generated HTML in a browser; skill installed at user level

**Apps**

- **[OpenSuperWhisper](https://github.com/Starmel/OpenSuperWhisper)** - local dictation (arm64, macOS 14+)

## Installation

```bash
git clone https://github.com/hendrix-io/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh
```

`setup.sh` installs Homebrew and everything above, backs up any `~/.zshrc` it is
about to replace to `~/.zshrc.pre-setup`, symlinks everything under `stow/` into
your home directory, and links `AGENTS.md` to each agent's config location.

Run it once. After that, use `./rebuild.sh`.

### If it reports a stow conflict

Stow refuses to overwrite a real file, names the one that conflicts, and changes
nothing. `setup.sh` then restores any `.zshrc` it had already moved aside and
exits, so you are never left without a shell config.

Two ways forward. Discard the existing file, keeping this repo's version:

```bash
mv ~/.config/some/file{,.pre-setup} && ./setup.sh
```

Or keep the existing file and pull it *into* the repo, replacing this repo's
copy with yours:

```bash
stow -d stow -t ~ --adopt .
git diff          # see exactly what got adopted
```

`--adopt` is the right choice when the live file is newer than the committed
one. Always `git diff` afterwards - it overwrites the repo copy silently.

## Daily use

Edit files under `stow/` directly. They are symlinked, not copied, so a change
to `stow/.zshrc` *is* a change to `~/.zshrc` - no rebuild needed.

Run `./rebuild.sh` only when you:

- add or remove a file under `stow/` (restow relays the links)
- add a package to `sh/installs.sh`

```bash
./rebuild.sh
```

## Machine-specific config

`~/.zshrc.local` is gitignored and sourced last by `.zshrc`, so it overrides
anything in the shared config. Everything specific to one machine goes there:

- secrets and tokens
- PATH entries for tools installed on only that machine
- employer-provided environment config

`setup.sh` creates it from `stow/.zshrc.local.example` on first run, then prints
the exact commands to migrate anything machine-specific out of the backed-up
`~/.zshrc.pre-setup`. It reports how many such lines it found but never prints
them, so a credential does not end up in terminal scrollback.

**Never put a credential in `stow/.zshrc`** - that file is committed.

## Agent instructions

`AGENTS.md` at the repo root is symlinked to all three of:

- `~/.claude/CLAUDE.md`
- `~/.codex/AGENTS.md`
- `~/.config/opencode/AGENTS.md`

Edit the one file, every agent picks it up. Project-level `AGENTS.md` files
still override it.

**`~/.claude/settings.json` is deliberately not managed here.** On a work
machine that file mixes employer-provided config (API proxy base URL, model
overrides, auth helper) with personal preferences like `statusLine` and
`model`. Claude Code reads a single user-level settings file with no second file
merged into it, so symlinking it from a dotfiles repo replaces the work half and
breaks Claude Code. It stays machine-local.

Skills split the same way. Skills that follow *you* across projects belong in
`~/.claude/skills/` - that is where `setup.sh` installs the lavish skill, with
`npx skills add ... -g`. Skills that encode one project's conventions belong in
that project's `.claude/skills/`.

## The gate

`no-mistakes` puts a validation pipeline in front of your remote. The `gate`
alias runs it in local-only mode:

```bash
gate     # no-mistakes --skip push,pr,ci
```

That runs `intent → rebase → review → test → document → lint` and stops there.
Nothing is pushed, no PR or MR is opened. Drop the `--skip` when you want it to
own the branch end to end.

Per-repo configuration lives in that repo's `.no-mistakes.yaml`, not here:

```yaml
commands:
  test: npm run test -w some-package
  lint: npm run lint
  format: npm run format
```

`commands.*` are read from the repo's **default branch**, never the pushed
commit - a supply-chain guard. The config has to land on `main`/`development`
before it affects a feature branch.

GitLab is supported via `glab` instead of `gh`, including self-hosted
instances. Install it with `brew install glab` if you enable the MR and CI
steps.

## Structure

```
dotfiles/
├── AGENTS.md        # shared agent instructions, symlinked to 3 locations
├── setup.sh         # first-run setup
├── rebuild.sh       # re-apply after changes
├── sh/
│   ├── utils.sh     # helper functions and colored output
│   ├── installs.sh  # package, cask, and tool installation
│   └── files.sh     # symlinking, backups, and rollback
└── stow/            # everything here is symlinked into ~
    ├── .zshrc
    ├── .zshrc.local.example
    └── .config/
        ├── ghostty/config
        └── starship/starship.toml
```

## Manual management

```bash
cd ~/dotfiles

stow -d stow -t ~ .          # link
stow -d stow -t ~ -D .       # unlink
stow -d stow -t ~ -R .       # relink, picking up deletions
stow -d stow -t ~ --adopt .  # pull existing files INTO the repo, then link
```
