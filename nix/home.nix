{ inputs, pkgs, ... }:
{
  home.stateVersion = "26.05";

  home.packages = [
    pkgs.curl
    pkgs.git
    inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mise
    pkgs.sheldon
    pkgs.zsh
  ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
    pkgs.gcc
    pkgs.wl-clipboard
  ];

  programs.home-manager.enable = true;
}
