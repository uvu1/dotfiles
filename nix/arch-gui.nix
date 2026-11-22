{ lib, pkgs, unstable, ... }:
let
  vicinaeExe = lib.getExe unstable.vicinae;
  shortcut = pkgs.writeShellApplication {
    name = "vicinae-kde-shortcut";
    runtimeInputs = [ pkgs.systemd ];
    text = builtins.readFile ../scripts/configure-vicinae-shortcut.sh;
  };
in
{
  home.packages = with unstable; [
    discord-canary
    (callPackage ./packages/chrome-canary.nix { })
    (callPackage ./packages/zen-twilight.nix { })
    obsidian
    rio
    slack
    spotify
    zoom-us
    vicinae
    moralerspace
  ];

  fonts.fontconfig.enable = true;

  xdg.dataFile."kglobalaccel/org.uvu1.Vicinae.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Vicinae
    Exec=${vicinaeExe} toggle
    Icon=vicinae
  '';

  systemd.user.services.vicinae = {
    Unit = {
      Description = "Vicinae launcher";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "exec";
      ExecStart = "${vicinaeExe} server";
      ExecStartPost = "-${lib.getExe shortcut}";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
