{ user, agents, platform, cleanup, lib, pkgs, ... }:

{
  # Determinate manages the Nix daemon itself, so nix-darwin must not.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = platform; # per machine, from flake.nix's machines block

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
  };
  system.stateVersion = 6;

  # Register nix's zsh in /etc/shells so it can be the login shell
  # (`chsh -s /run/current-system/sw/bin/zsh`). Otherwise Ghostty starts
  # Apple's /bin/zsh 5.9 while `zsh` on PATH is nix's 5.9.1, and the two
  # versions keep invalidating each other's ~/.zcompdump.
  environment.shells = [ pkgs.zsh ];

  # The global /etc/zshrc would run its own compinit (plus promptinit and
  # bashcompinit). home/.zshrc runs compinit itself with a different fpath,
  # so the two kept invalidating ~/.zcompdump and rebuilding it every shell.
  # fpath is still set in /etc/zshenv, so nothing is lost.
  programs.zsh = {
    enableCompletion = false;
    enableBashCompletion = false;
    promptInit = "";
  };

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      AppleShowAllExtensions = true;
    };
    dock.autohide = true;
    finder.FXPreferredViewStyle = "Nlsv"; # list view by default
    trackpad.Clicking = true;             # tap to click
  };

  nix-homebrew = {
    enable = true;
    inherit user;
    # This machine had Homebrew before Nix. Migration deletes brew's own git
    # checkout but keeps every installed package (Cellar and Caskroom).
    autoMigrate = true;
  };
  homebrew = {
    enable = true;
    # Per machine, from flake.nix's machines block - see the choice docs
    # there ("uninstall" converges, "none" adopts, never "zap").
    onActivation.cleanup = cleanup;
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];
    brews = [
      # .zshrc sources both plugins from $HOMEBREW_PREFIX/share, so they have
      # to come from brew, not nix.
      "zsh-autosuggestions"
      "zsh-syntax-highlighting"
    ] ++ lib.optionals agents [
      # herdr is agent tooling; the agents flag in flake.nix gates it. With
      # cleanup = "uninstall", flipping the flag off also removes it.
      "herdr"
    ];
    casks = [
      "ghostty"
      "font-hack-nerd-font"
      "opensuperwhisper"
    ];
  };
}
