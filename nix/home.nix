{ inputs, pkgs, ... }:
let
  misePackage = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mise;
  dotfilesUpdate = pkgs.writeShellApplication {
    name = "dotfiles-update";
    runtimeInputs = [
      pkgs.git
      misePackage
    ];
    text = ''
      export PATH="$HOME/.local/share/mise/shims:$PATH"
    '' + builtins.readFile ../scripts/update-wsl.sh;
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

  home.file = pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
    ".local/bin/ssh" = {
      executable = true;
      text = ''
        #!/bin/sh
        exec /mnt/c/Windows/System32/OpenSSH/ssh.exe "$@"
      '';
    };
    ".local/bin/ssh-keygen" = {
      executable = true;
      text = ''
        #!/bin/sh
        exec ${pkgs.openssh}/bin/ssh-keygen "$@"
      '';
    };
  };

  programs.home-manager.enable = true;
}
