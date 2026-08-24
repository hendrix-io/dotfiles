{
  description = "dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    treehouse.url = "github:kunchenguid/treehouse";
    treehouse.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nix-homebrew, home-manager, nixpkgs, treehouse }:
    let
      # The one username line to change on a machine with a different login.
      # bootstrap.sh detects a mismatch and offers to rewrite this for you.
      user = "andrew";
      # Install the AI/agent tooling? bootstrap.sh asks once and rewrites
      # this line. false skips the agent fleet and skills (sh/ layer), drops
      # herdr from the brew list (configuration.nix), and gates the AGENTS.md
      # links (home.nix) - a plain development machine, nothing dangling.
      agents = true;
    in
    {
      darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit user agents; };
        modules = [
          ./configuration.nix
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit user agents inputs; };
            home-manager.users.${user} = import ./home.nix;
            # On first switch, files home-manager wants to own (the old stow
            # symlinks, ~/.claude/settings.json) already exist. Move them
            # aside instead of failing the activation.
            home-manager.backupFileExtension = "hm-backup";
          }
        ];
      };
    };
}
