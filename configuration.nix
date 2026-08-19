{ user, ... }:

{
  # Determinate manages the Nix daemon itself, so nix-darwin must not.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # bootstrap.sh rewrites this to match uname -m

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
    # "uninstall" removes brew packages that drop out of these lists - the
    # right convergence for the machine this repo is the source of truth for.
    # For anyone else adopting the repo on a Mac with an existing Homebrew,
    # it would uninstall every formula and cask not listed here, apps
    # included, so they get "none" and keep what they have.
    # Not "zap" even here: that would additionally purge removed casks' app
    # data.
    onActivation.cleanup = if user == "aessex" then "uninstall" else "none";
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];
    brews = [
      "herdr"
      # .zshrc sources both plugins from $HOMEBREW_PREFIX/share, so they have
      # to come from brew, not nix.
      "zsh-autosuggestions"
      "zsh-syntax-highlighting"
    ];
    casks = [
      "ghostty"
      "font-hack-nerd-font"
      # Local dictation. arm64 + macOS >= 14 only; brew declines it on Intel.
      "opensuperwhisper"
      # Deliberately absent: claude-code. Claude Code is installed via its
      # native installer (~/.local/bin/claude) and updates itself; the cask
      # would be a second, competing install.
    ];
  };
}
