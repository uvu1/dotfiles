{ inputs, pkgs, ... }:
{
  home.stateVersion = "26.05";

  home.packages = [
    pkgs.curl
    pkgs.git
    inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mise
    pkgs.sheldon
    pkgs.zsh
  ];

  programs.home-manager.enable = true;
}
