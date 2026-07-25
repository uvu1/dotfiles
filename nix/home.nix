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
    # WSLの日本語文字化け対策。programs.zsh 未使用で hm-session-vars.sh が
    # 読まれないため、zshが最初に読む .zshenv でロケールを明示する。
    # en_US.UTF-8 は Nix パッチ済み glibc しか LOCALE_ARCHIVE から解決できず、
    # システム(Arch)glibc にリンクされた mise 導入ツールや coreutils は
    # LOCALE_ARCHIVE を無視して C にフォールバックし日本語を化けさせる。
    # C.UTF-8 は Nix/システム両方の glibc に組み込みで存在し archive 不要のため、
    # 全プロセスで一貫して UTF-8 になる。LOCALE_ARCHIVE は名前付きロケールを
    # 要求する Nix ツール向けに残す。
    ".zshenv".text = ''
      export LOCALE_ARCHIVE="${pkgs.glibcLocales}/lib/locale/locale-archive"
      export LANG=C.UTF-8
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
