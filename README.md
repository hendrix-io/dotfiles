# dotfiles

My personal Mac setup, managed with nix-darwin and home-manager.
One repo, one command, and a fresh Mac ends up configured the same way every time.

The declarative skeleton is adapted from
[kunchenguid/dotfiles](https://github.com/kunchenguid/dotfiles) (MIT-0) -
see [Credits](#credits).

## What's included

**Declarative (Nix owns it, `rebuild.sh` re-applies it)**

- **macOS settings** - dark mode, fast key repeat, dock autohide, Finder list view, tap to click
- **CLI tools** - git, gh, glab, ripgrep, fd, fzf, jq, lazygit, neovim, tmux, starship, [treehouse](https://github.com/kunchenguid/treehouse) (via its own flake input)
- **Homebrew** - ghostty, Hack Nerd Font, [OpenSuperWhisper](https://github.com/Starmel/OpenSuperWhisper), [herdr](https://herdr.dev), the zsh plugins `.zshrc` sources from brew's share dir
- **Linked configs** - zsh, starship, ghostty, herdr, `~/.claude/settings.json`, and one `AGENTS.md` for every agent

**Imperative (guarded installers, same scripts re-run safely)**

- **Node toolchain** - nvm with `.nvmrc` auto-switching, node LTS, pnpm, bun
- **Claude Code** - via its native installer into `~/.local/bin` (deliberately
  not the brew cask, which would be a second, competing install)
- **[gnhf](https://github.com/kunchenguid/gnhf)** - overnight agent loop orchestrator, npm global, kept alive across node upgrades via nvm's `default-packages`
- **[no-mistakes](https://github.com/kunchenguid/no-mistakes)** - local validation gate, aliased to `gate`
- **[lavish](https://github.com/kunchenguid/lavish-axi)** - review agent-generated HTML in a browser; skill installed at user level
- **[firstmate](https://github.com/kunchenguid/firstmate)** - agent distro; the clone is the install, at `~/code/firstmate`

## Fresh-machine setup

```sh
git clone https://github.com/hendrix-io/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

`bootstrap.sh` does eight things, in order:

1. Installs Determinate Nix, if it isn't already installed.
2. Symlinks this repo to `~/.dotfiles` (home.nix resolves its file links through that path).
3. Checks the `user` in `flake.nix` against your macOS username and offers to fix a mismatch.
4. Checks `nixpkgs.hostPlatform` against your CPU (`uname -m`) and rewrites it if it's wrong - no question asked, uname knows better.
5. Asks whether brew packages missing from the repo's lists should be uninstalled whenever the config is applied, and writes your answer into `configuration.nix` (see [Homebrew cleanup](#homebrew-cleanup)).
6. Asks whether to install the AI/agent tooling (Claude Code, firstmate, gnhf, no-mistakes, herdr, the skills, the `AGENTS.md` links), and writes your answer into `flake.nix`. Answer **n** for a plain development machine with none of it.
7. Runs the first `darwin-rebuild switch`, which builds the whole declarative layer.
8. Runs the imperative layer in phases: machine setup (auth, local files), global tools (node, pnpm, bun, openspec), the agent fleet and skills (if enabled), and a verification report.

Auth is the only part that needs you at the keyboard. Everything else is unattended.

## Not your machine? Not a fresh Mac? Still fine

This repo is written so someone who isn't me can clone it and run
`./bootstrap.sh` on a Mac that already has stuff on it. What to expect:

- **Your username**: step 3 of bootstrap notices `flake.nix` says `aessex`
  and offers to rewrite it to your login. Say yes. That leaves a one-line
  local edit in your clone - fork the repo first if you ever want to push
  your own changes.
- **Your existing apps and brew packages survive.** Bootstrap asks
  whether brew packages missing from this repo's lists should be
  uninstalled; answer **n** (the default) and Homebrew installs what's
  listed here and touches nothing else. One caveat: casks install with
  `--force`, so if you already have Ghostty installed manually, brew
  replaces that copy with its own.
- **Your existing dotfiles are backed up, not deleted.** Files this repo
  manages (`~/.zshrc`, `~/.gitconfig`, `~/.config/nvim`, ...) are moved
  aside as `*.hm-backup` on the first switch. Anything you want to keep -
  PATH entries, aliases, secrets - goes into `~/.zshrc.local`, which is
  sourced last and overrides everything.
- **Tools you already have are left alone.** Every imperative installer is
  guarded: existing nvm, node, pnpm, bun, or Claude Code installs are
  detected and skipped.
- **The AI tooling is optional.** Bootstrap asks once; answer **n** and no
  agent fleet, skills, herdr, or AGENTS.md links are installed - just a
  normal development machine. The answer is committed to your fork like the
  username.
- **macOS defaults ARE applied** - dark mode, dock autohide, fast key
  repeat, tap to click. Edit `system.defaults` in `configuration.nix`
  before bootstrapping if you feel strongly.
- **Your git identity is yours.** Bootstrap creates `~/.gitconfig.local`
  from the example; put your name and email there. It is never committed.
- **Intel Macs work without edits.** Bootstrap detects the CPU and rewrites
  `nixpkgs.hostPlatform` itself. (OpenSuperWhisper won't install there;
  brew declines it on Intel - everything else is unaffected.)

### Revamping an existing setup

This repo started as a revamp of a machine with years of Homebrew and old
dotfiles on it, not a fresh install. Bootstrap won't delete anything you
have - but it also won't automatically add your existing setup to the
config. That part is manual, in this order:

1. **List what you already have installed.** `brew leaves` shows the
   command-line packages you installed yourself; `brew list --cask` shows
   your apps. Add the ones you want to keep to the `brews` and `casks`
   lists in `configuration.nix`. Skipping this loses nothing - it just
   means a future machine built from your fork wouldn't get those
   packages.
2. **Copy what you need out of your old dotfiles.** The first switch
   renames your old files (`~/.zshrc` becomes `~/.zshrc.hm-backup`, and so
   on). Copy the lines you still want: machine-specific ones into
   `~/.zshrc.local`, ones you'd want on every machine into `home/.zshrc`
   in your fork.
3. **Turn on cleanup once the lists are complete.** When
   `configuration.nix` lists everything you actually want, change
   `onActivation.cleanup` to `"uninstall"`. From then on, anything
   installed with a plain `brew install` is removed again the next time
   you run `./rebuild.sh`, unless you add it to the list - that is what
   keeps the machine matching the repo.

### Fork-and-run, step by step

1. Fork this repo on GitHub, keeping the name `dotfiles`.
2. In Terminal (a Mac that has never had dev tools will pop the Xcode
   Command Line Tools dialog on the first `git` command - accept, wait,
   rerun):

   ```sh
   git clone https://github.com/YOUR-USERNAME/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ./bootstrap.sh
   ```

   The HTTPS URL is the safe default: it works before any keys exist, and
   `gh auth login` during bootstrap sets up push credentials for it (pick
   HTTPS and say yes to "authenticate Git"). If this machine already has
   SSH keys on your GitHub account, clone `git@github.com:YOUR-USERNAME/dotfiles.git`
   instead and pick SSH during `gh auth login`.

   You're at the keyboard six times: your Mac password for sudo, **y** to
   the username rewrite, **n** to the Homebrew cleanup question (unless
   you've already filled the package lists with what you want kept),
   **y/n** to the AI/agent tooling question (n = plain dev machine), the
   browser auth for `gh`, and optionally skipping glab.

3. Restart the terminal, then claim your identity and salvage your old
   shell config:

   ```sh
   nvim ~/.gitconfig.local   # your name + GitHub noreply email
   nvim ~/.zshrc.local       # paste keepers from ~/.zshrc.hm-backup
   ```

4. Commit the machine-specific rewrites to your fork:

   ```sh
   git add flake.nix configuration.nix
   git commit -m "chore: my username and platform"
   git push
   ```

To pull future improvements from upstream later:

```sh
git remote add upstream https://github.com/hendrix-io/dotfiles.git
git pull upstream main
```

That merges cleanly as long as your divergence stays small (the username
line, the platform line, and whatever you prune from `run_imperative` or
`system.defaults` because it isn't for you).

### Validate without applying

Once Nix is installed, check that the config builds without touching the system:

```sh
nix flake check --no-build
nix build .#darwinConfigurations.mac.system --dry-run
```

## Daily use

Edit files under `home/` directly. They are symlinked, not copied, so a change
to `home/.zshrc` *is* a change to `~/.zshrc` - no rebuild needed.

Run `./rebuild.sh` when you:

- add or remove a package in `home.nix` or `configuration.nix`
- change a macOS default
- add or remove a linked file
- want the guarded installers re-checked

```sh
./rebuild.sh
```

`rebuild.sh` never prompts. If auth is missing it warns and tells you the
command to run, so a routine rebuild can't block on input.

## Machine-specific config

`~/.zshrc.local` is gitignored and sourced last by `.zshrc`, so it overrides
anything in the shared config. Everything specific to one machine goes there:

- secrets and tokens
- PATH entries for tools installed on only that machine

`bootstrap.sh` creates it from `home/.zshrc.local.example` on first run.

Git identity works the same way: the committed `home/.gitconfig` holds only
behavior, and `~/.gitconfig.local` (created from its example, never
committed) holds your name and emails - including per-directory `includeIf`
overrides for different jobs, so none of that is visible in this public repo.

**Never put a credential in `home/.zshrc`** - that file is committed.

## Agent instructions

`AGENTS.md` at the repo root is linked by home-manager to all four of:

- `~/.claude/CLAUDE.md` (Claude Code)
- `~/.codex/AGENTS.md` (Codex CLI)
- `~/.config/opencode/AGENTS.md` (OpenCode)
- `~/.cursor/AGENTS.md` (Cursor)

Edit the one file, every agent picks it up. Project-level `AGENTS.md` files
still override it. Codex and Cursor aren't installed by this repo - but if
you use them, their global instructions are already wired the moment they
are (`npm i -g @openai/codex`, `brew install --cask cursor`).

`~/.claude/settings.json` is deliberately NOT symlinked into this repo:
Claude Code writes runtime config into that file, and a live symlink would
put those writes one `git add` away from a public repo. The repo commits
`home/.claude/settings.template.json` instead; bootstrap seeds the live file
from it once, and from then on the machine owns it. Edit preferences you
want on every future machine in the template, machine-local ones live.

Skills are installed by `sh/skill-installs.sh` and pinned by their guards -
a rebuild never changes an installed skill. Update them deliberately with
`npx -y skills update -g`, and skim what changed after: updated skills are
new instruction text running with full agent permissions.

## Agent fleet

The pieces fit together like this:

- **firstmate** is the captain: launch a harness inside `~/code/firstmate`
  (`claude` is a co-primary) and it dispatches crew agents into treehouse
  worktrees, in tmux by default or herdr as an experimental backend.
- **treehouse** keeps a pool of reusable worktrees with dependencies and
  build caches intact.
- **gnhf** is the overnight loop: `gnhf "objective"` commits one small change
  per iteration until a cap, and you wake up to a reviewable branch.
- **no-mistakes** (`gate`) validates locally before anything reaches a remote.
- **herdr** runs as a service: `brew services start herdr` once, then it's the
  agent multiplexer in your terminal. Its config here is seeded for a
  tmux-style prefix; expect to tune keybindings under Ghostty.

## Homebrew cleanup

`onActivation.cleanup` in `configuration.nix` decides what happens to brew
packages that are NOT in the `brews`/`casks` lists. `"uninstall"` removes
them every time the config is applied (bootstrap's first run, and each
later `./rebuild.sh`), which keeps the machine matching the repo exactly -
that's what my machine runs. `"none"` leaves them alone - the right answer
for a machine with an existing Homebrew, until the lists cover everything
you want to keep. Bootstrap asks which you want and writes the answer into
the file; commit it to your fork like the username. It is deliberately
never `"zap"`, which would also delete removed casks' app data.

## Structure

```
dotfiles/
├── flake.nix          # entry point: nixpkgs, nix-darwin, home-manager, treehouse
├── configuration.nix  # system layer: macOS defaults, Homebrew lists
├── home.nix           # user layer: packages, symlinks into home/
├── AGENTS.md          # shared agent instructions, linked to 3 locations
├── bootstrap.sh       # first run: nix install, questions, first switch, auth
├── rebuild.sh         # every later change; never prompts
├── sh/
│   ├── utils.sh          # colors, guards, the verification report
│   ├── installs.sh       # the phased orchestrator; sources the modules below
│   ├── machine.sh        # git ownership, gh recovery, auth, local-file seeding
│   ├── tool-installs.sh  # nvm, node, pnpm, bun, openspec
│   ├── agent-installs.sh # claude, gnhf, no-mistakes, firstmate, settings seed
│   └── skill-installs.sh # third-party agent skills
└── home/              # the real config files, symlinked into ~
    ├── .zshrc
    ├── .zshrc.local.example
    ├── .claude/settings.template.json
    └── .config/
        ├── ghostty/config
        ├── herdr/config.toml
        ├── nvim/              # lazy.nvim, ayu-dark, oil + snacks + neogit
        └── starship/starship.toml
```

## Credits

The nix-darwin + home-manager structure here - `flake.nix` /
`configuration.nix` / `home.nix`, the bootstrap-then-rebuild flow, and the
`mkOutOfStoreSymlink` edit-in-place model - is adapted from
[Kun Chen's dotfiles](https://github.com/kunchenguid/dotfiles) (MIT No
Attribution), and the herdr config started as a copy of his. Most of the
agent tooling this repo installs ([treehouse](https://github.com/kunchenguid/treehouse),
[firstmate](https://github.com/kunchenguid/firstmate),
[gnhf](https://github.com/kunchenguid/gnhf),
[no-mistakes](https://github.com/kunchenguid/no-mistakes),
[lavish](https://github.com/kunchenguid/lavish-axi)) is his work too.
His [walkthrough video](https://youtu.be/5N-okeDdIuI) covers the original
setup this one grew from.

The imperative shell layer predates the Nix port and comes from
[belsrc's dotfiles](https://github.com/belsrc/.dotfiles), this repo's
original skeleton: the `sh/utils.sh` output helpers, the guarded-installer
pattern in `sh/installs.sh` (check for the tool, install only if missing,
safe to re-run), and the bones of `.zshrc` - the Homebrew prefix detection
and plugin sourcing - are his, as is Ghostty as the terminal of choice.
