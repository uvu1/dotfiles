{ lib, pkgs, ... }:
let
  vicinae = "/usr/bin/vicinae";
  shortcut = pkgs.writeShellApplication {
    name = "vicinae-kde-shortcut";
    runtimeInputs = [ pkgs.systemd ];
    text = builtins.readFile ../scripts/configure-vicinae-shortcut.sh;
  };
in
{
  home.packages = [ pkgs.moralerspace ];

  fonts.fontconfig.enable = true;

  xdg.dataFile."kglobalaccel/org.uvu1.Vicinae.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Vicinae
    Exec=${vicinae} toggle
    Icon=vicinae
  '';

  systemd.user.services.vicinae = {
    Unit = {
      Description = "Vicinae launcher";
      PartOf = [ "graphical-session.target" ];
      ConditionPathIsExecutable = vicinae;
    };
    Service = {
      Type = "exec";
      ExecStart = "${vicinae} server";
      ExecStartPost = "-${lib.getExe shortcut}";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
