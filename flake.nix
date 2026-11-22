{
  description = "uvu1 development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

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
      mkLinuxHome = wsl: home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { system = linuxSystem; };
        extraSpecialArgs = { inherit inputs wsl; };
        modules = [
          ./nix/home.nix
          {
            home.username = "uvu1";
            home.homeDirectory = "/home/uvu1";
          }
        ] ++ nixpkgs.lib.optional (!wsl) ./nix/arch-gui.nix;
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

      homeConfigurations."uvu1@arch-wsl" = mkLinuxHome true;
      homeConfigurations."uvu1@fy-desktop" = mkLinuxHome false;

      checks.${darwinSystem}.darwin-system = self.darwinConfigurations."uvu1-mac".system;
      checks.${linuxSystem} = {
        home-activation = self.homeConfigurations."uvu1@arch-wsl".activationPackage;
        fy-desktop-activation = self.homeConfigurations."uvu1@fy-desktop".activationPackage;
      };
    };
}
