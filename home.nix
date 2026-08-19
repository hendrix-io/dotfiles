{ config, pkgs, lib, user, agents, inputs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    git   # macOS ships an older git via Xcode CLT; this one wins on PATH
    gh
    glab
    ripgrep
    fd
    fzf
    jq
    lazygit
    neovim
    tmux
    # .zshrc runs `starship init zsh` itself, so the binary is all we need.
    # programs.starship would generate its own starship.toml over ours.
    starship
  ] ++ [
    inputs.treehouse.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # Deliberately no programs.zsh: it generates a .zshrc, and ours is a real
  # file linked below. Same reasoning as starship above.

  # Edit-in-place: the real files stay in this repo, $HOME just points at
  # them, so editing home/.zshrc IS editing ~/.zshrc - no rebuild needed.
  home.file.".zshrc".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.zshrc";
  home.file.".gitconfig".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.gitconfig";
  home.file.".config/starship".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/starship";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";
  home.file.".config/ghostty".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/ghostty";
  # Gated with the fleet: herdr itself is only brewed when agents = true,
  # and an unmanaged herdr writing session state through this link would
  # land it inside the public repo.
  home.file.".config/herdr" = lib.mkIf agents {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";
  };
  # ~/.claude/settings.json is deliberately NOT linked: Claude Code writes
  # runtime config into it, and a live symlink would land those writes in
  # this public repo. sh/agent-installs.sh seeds it once from the committed
  # settings.template.json instead; after that, the machine owns it.

  # One AGENTS.md, read by every agent. Gated with the fleet: a no-agents
  # machine gets no instruction links to nowhere.
  home.file.".claude/CLAUDE.md" = lib.mkIf agents {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/AGENTS.md";
  };
  home.file.".codex/AGENTS.md" = lib.mkIf agents {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/AGENTS.md";
  };
  home.file.".config/opencode/AGENTS.md" = lib.mkIf agents {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/AGENTS.md";
  };
  home.file.".cursor/AGENTS.md" = lib.mkIf agents {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/AGENTS.md";
  };
}
