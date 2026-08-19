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

`bootstrap.sh` does five things, in order:

1. Installs Determinate Nix, if it isn't already installed.
2. Symlinks this repo to `~/.dotfiles` (home.nix resolves its file links through that path).
3. Checks the `user` in `flake.nix` against your macOS username and offers to fix a mismatch.
4. Runs the first `darwin-rebuild switch`, which builds the whole declarative layer.
5. Runs the imperative layer: prompts `gh auth login` (and optionally `glab`), installs the node toolchain, Claude Code, and the agent tools, clones firstmate.

Auth is the only part that needs you at the keyboard. Everything else is unattended.

## Not your machine? Not a fresh Mac? Still fine

This repo is written so someone who isn't me can clone it and run
`./bootstrap.sh` on a Mac that already has stuff on it. What to expect:

- **Your username**: step 3 of bootstrap notices `flake.nix` says `aessex`
  and offers to rewrite it to your login. Say yes. That leaves a one-line
  local edit in your clone - fork the repo first if you ever want to push
  your own changes.
- **Your existing apps and brew packages survive.** The aggressive
  `cleanup = "uninstall"` convergence only applies to my username; for
  everyone else Homebrew installs what's listed here and touches nothing
  else. One caveat: casks install with `--force`, so if you already have
  Ghostty installed manually, brew adopts (replaces) that copy.
- **Your existing dotfiles are backed up, not deleted.** Files this repo
  manages (`~/.zshrc`, `~/.gitconfig`, `~/.config/nvim`, ...) are moved
  aside as `*.hm-backup` on the first switch. Anything you want to keep -
  PATH entries, aliases, secrets - goes into `~/.zshrc.local`, which is
  sourced last and overrides everything.
- **Tools you already have are left alone.** Every imperative installer is
  guarded: existing nvm, node, pnpm, bun, or Claude Code installs are
  detected and skipped.
- **macOS defaults ARE applied** - dark mode, dock autohide, fast key
  repeat, tap to click. Edit `system.defaults` in `configuration.nix`
  before bootstrapping if you feel strongly.
- **Your git identity is yours.** Bootstrap creates `~/.gitconfig.local`
  from the example; put your name and email there. It is never committed.
- **Intel Macs**: change `nixpkgs.hostPlatform` in `configuration.nix` to
  `x86_64-darwin` first (OpenSuperWhisper won't install there; brew
  declines it on Intel).

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

`~/.claude/settings.json` IS managed here. This is a personal machine, so the
file holds nothing but personal preferences; on a work machine that mixes in
employer-provided config (API proxy, auth helper), leave it machine-local
instead - Claude Code reads a single user-level settings file, and replacing
the work half breaks it.

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

For user `aessex` only, `configuration.nix` sets
`homebrew.onActivation.cleanup = "uninstall"`: any brew package not in its
`brews`/`casks` lists is uninstalled on switch. The first switch removed
brew's git, gh, starship, and stow - Nix provides git, gh, and starship from
then on, and stow isn't needed anymore. It is deliberately not `"zap"`,
which would also purge removed casks' app data. Every other user gets
`"none"`, so an existing Homebrew keeps its packages (see the section
above).

## Structure

```
dotfiles/
├── flake.nix          # entry point: nixpkgs, nix-darwin, home-manager, treehouse
├── configuration.nix  # system layer: macOS defaults, Homebrew lists
├── home.nix           # user layer: packages, symlinks into home/
├── AGENTS.md          # shared agent instructions, linked to 3 locations
├── bootstrap.sh       # first run: nix install, first switch, auth, clones
├── rebuild.sh         # every later change; never prompts
├── sh/
│   ├── utils.sh       # helpers and colored output
│   └── installs.sh    # the imperative layer: guarded installers, auth, firstmate
└── home/              # the real config files, symlinked into ~
    ├── .zshrc
    ├── .zshrc.local.example
    ├── .claude/settings.json
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
