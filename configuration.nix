{ user, agents, platform, cleanup, lib, ... }:

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
