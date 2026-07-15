# dotfiles

My personal configuration files, managed with GNU Stow.

## What's included

- **Starship prompt** - Minimal, fast shell prompt with git status
- **Zsh config** - nvm with auto-switching, pnpm, bun, and more

## Installation

```bash
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh
```

The setup script will:
- Install Homebrew (if not already installed)
- Install stow, starship, nvm, pnpm, and bun
- Backup any existing config files (.pre-setup)
- Symlink dotfiles to your home directory
- Create a `.zshrc.local.example` file

## After installation

1. Copy `~/.zshrc.local.example` to `~/.zshrc.local`
2. Edit `~/.zshrc.local` with machine-specific config (PATH, secrets, etc.)
3. Restart your terminal or run `source ~/.zshrc`

## Structure

```
dotfiles/
├── sh/              # Installation and utility scripts
│   ├── utils.sh     # Helper functions
│   ├── installs.sh  # Package installation
│   └── files.sh     # File management and stow
├── stow/            # Dotfiles to be stowed
│   ├── .zshrc
│   ├── .zshrc.local.example
│   └── .config/
│       └── starship/
│           └── starship.toml
├── setup.sh         # Main setup script
└── README.md
```

## Manual management

If you prefer to manage dotfiles manually:

```bash
# Stow all dotfiles
cd ~/dotfiles
stow -d stow -t ~ .

# Unstow (remove symlinks)
stow -d stow -t ~ -D .

# Restow (useful after updates)
stow -d stow -t ~ -R .
```
