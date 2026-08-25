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
      # Which login each Mac uses - the one value that must be committed
      # per machine, because flakes evaluate purely from the repo: there is
      # no "ask who is logged in" at eval time, and a locally-rewritten
      # username is either committed (breaking the other machine on pull)
      # or a permanently dirty tree. Each Mac picks its entry via the
      # one-line label in ~/.dotfiles-machine; when that file is missing,
      # the sh/ layer derives it by matching the login against these
      # entries. bootstrap.sh and sh/utils.sh parse this file with awk/sed
      # - keep the one-line `label = "login";` formatting when editing.
      machines = {
        work = "andrew";
        personal = "aessex";
      };

      # Shared by every machine - the point of the dotfiles. Promote one of
      # these into per-machine data only when two Macs genuinely differ.
      platform = "aarch64-darwin";
      # Install the AI/agent tooling? false skips the agent fleet and
      # skills (sh/ layer), drops herdr from the brew list
      # (configuration.nix), and gates the AGENTS.md links (home.nix) - a
      # plain development machine, nothing dangling.
      agents = true;
      # "uninstall" converges: every switch removes brew packages and casks
      # not declared in configuration.nix. "none" adopts: install what is
      # listed, keep everything else. Never "zap": that would also purge
      # removed casks' app data.
      cleanup = "uninstall";

      mkMachine = name: user:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit user agents platform cleanup; };
          modules = [
            ./configuration.nix
            nix-homebrew.darwinModules.nix-homebrew
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit user agents inputs; };
              home-manager.users.${user} = import ./home.nix;
              # On first switch, files home-manager wants to own (the old
              # stow symlinks, ~/.claude/settings.json) already exist. Move
              # them aside instead of failing the activation.
              home-manager.backupFileExtension = "hm-backup";
            }
          ];
        };
    in
    {
      darwinConfigurations = builtins.mapAttrs mkMachine machines;
    };
}
