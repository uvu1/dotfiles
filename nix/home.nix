{ pkgs, ... }:
{
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    curl
    git
    mise
    sheldon
    zsh
  ];

  programs.home-manager.enable = true;
}
