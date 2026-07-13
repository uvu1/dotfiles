{ inputs, pkgs, ... }:
let
  misePackage = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mise;
  dotfilesUpdate = pkgs.writeShellApplication {
    name = "dotfiles-update";
    runtimeInputs = [
      pkgs.git
      misePackage
    ];
    text = builtins.readFile ../scripts/update-wsl.sh;
  };
in
{
  home.stateVersion = "26.05";

  home.packages = [
    pkgs.curl
    pkgs.git
    misePackage
    pkgs.sheldon
    pkgs.zsh
  ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
    dotfilesUpdate
    pkgs.gcc
    pkgs.wl-clipboard
  ];

  programs.home-manager.enable = true;
}
