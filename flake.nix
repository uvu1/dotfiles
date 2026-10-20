{
  description = "uvu1 development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      ...
    }:
    let
      linuxSystem = "x86_64-linux";
      darwinSystem = "aarch64-darwin";

      # Standalone Home Manager for a work Mac. Unlike nix-darwin, this does not
      # configure Homebrew GUI apps, system defaults, services, or macOS users.
      # --impure is required to read the current account's USER/HOME.
      mkWorkHome = system: home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { inherit system; };
        extraSpecialArgs = {
          inherit inputs;
          workProfile = true;
        };
        modules = [
          ./nix/home.nix
          {
            home.username = builtins.getEnv "USER";
            home.homeDirectory = builtins.getEnv "HOME";
          }
        ];
      };
    in
    {
      darwinConfigurations."uvu1-mac" = nix-darwin.lib.darwinSystem {
        system = darwinSystem;
        specialArgs = { inherit inputs; };
        modules = [
          ./nix/darwin.nix
          inputs.nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
        ];
      };

      homeConfigurations."work-aarch64-darwin" = mkWorkHome "aarch64-darwin";
      homeConfigurations."work-x86_64-darwin" = mkWorkHome "x86_64-darwin";

      homeConfigurations."uvu1@arch-wsl" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = linuxSystem;
        };
        extraSpecialArgs = { inherit inputs; };
        modules = [
          ./nix/home.nix
          {
            home.username = "uvu1";
            home.homeDirectory = "/home/uvu1";
          }
        ];
      };

      checks.${darwinSystem}.darwin-system = self.darwinConfigurations."uvu1-mac".system;
      checks.${linuxSystem}.home-activation =
        self.homeConfigurations."uvu1@arch-wsl".activationPackage;
    };
}
