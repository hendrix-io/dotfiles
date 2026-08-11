# dotfiles

My personal configuration files, managed with GNU Stow.

## What's included

- **Zsh config** - nvm with `.nvmrc` auto-switching, pnpm, bun, autosuggestions, syntax highlighting
- **Starship prompt** - minimal, fast, with git status
- **Ghostty** - ayu theme, Hack Nerd Font
- **Shared agent instructions** - one `AGENTS.md` read by Claude Code, Codex, and opencode
- **CLI tools** - ripgrep, fd, fzf, lazygit, neovim

## Installation

```bash
git clone https://github.com/hendrix-io/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh
```

`setup.sh` installs Homebrew and the tools above, backs up any `~/.zshrc` it is
about to replace to `~/.zshrc.pre-setup`, symlinks everything under `stow/` into
your home directory, and links `AGENTS.md` to each agent's config location.

Run it once. After that, use `./rebuild.sh`.

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

`setup.sh` creates it from `stow/.zshrc.local.example` on first run.

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
`model`. Symlinking it from a dotfiles repo replaces the work half and breaks
Claude Code. It stays machine-local.

## Structure

```
dotfiles/
├── AGENTS.md        # shared agent instructions, symlinked to 3 locations
├── setup.sh         # first-run setup
├── rebuild.sh       # re-apply after changes
├── sh/
│   ├── utils.sh     # helper functions
│   ├── installs.sh  # package installation
│   └── files.sh     # symlinking and backups
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

stow -d stow -t ~ .       # link
stow -d stow -t ~ -D .    # unlink
stow -d stow -t ~ -R .    # relink, picking up deletions
```

Stow refuses to overwrite a real file and tells you which one conflicts. That
is the intended safety net - move the file aside yourself rather than scripting
around it.
