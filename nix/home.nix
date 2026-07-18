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
    pkgs.podman
    pkgs.passt
  ];

  home.file = pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
    # 非NixOSではNixのglibcがロケールデータをLOCALE_ARCHIVEから探す。
    # programs.zsh 未使用のため hm-session-vars.sh は読まれないので、
    # zshが必ず最初に読む .zshenv でロケールを明示する（WSL日本語入力の文字化け対策）。
    # zshはLANG代入時にsetlocaleを呼ぶため、LOCALE_ARCHIVEを必ず先に設定する
    # （逆順だとarchive未設定のままsetlocaleが失敗しCフォールバック→日本語が化ける）。
    ".zshenv".text = ''
      export LOCALE_ARCHIVE="${pkgs.glibcLocales}/lib/locale/locale-archive"
      export LANG=en_US.UTF-8
    '';

    # 非NixOSのArchではNixのpodmanが/etc/containers/policy.jsonを持たず
    # `podman pull`が失敗するため、ユーザー設定として宣言する。
    ".config/containers/policy.json".text = ''
      { "default": [ { "type": "insecureAcceptAnything" } ] }
    '';
    ".config/containers/registries.conf".text = ''
      unqualified-search-registries = ["docker.io"]
    '';

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
