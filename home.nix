{ config, pkgs, user, inputs, ... }:

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
  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";
  # Fine to manage on a personal machine: nothing employer-provided in it.
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";

  # One AGENTS.md, read by every agent.
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/AGENTS.md";
}
