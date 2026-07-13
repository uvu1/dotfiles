{ inputs, pkgs, ... }:
{
  nixpkgs.hostPlatform = "aarch64-darwin";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system = {
    primaryUser = "uvu1";
    stateVersion = 6;

    defaults.finder.AppleShowAllFiles = true;
  };

  users.users.uvu1.home = "/Users/uvu1";

  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
  ];

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;
    users.uvu1 = {
      imports = [ ./home.nix ];
      home.username = "uvu1";
      home.homeDirectory = "/Users/uvu1";
    };
  };
}
