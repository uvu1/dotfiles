# migrate-dotfiles

`github.com/uvu1/dotfiles` の `chezmoi-master`（旧 `master`）を移行元正本として、
chezmoi 管理の設定を Nix、Home Manager、nix-darwin、mise dotfiles へ移行した構成です。

移植時に参照した正本コミットは
`44ae8668a39989d0bfba1572ae869da3fb4b22f5` です。設定を更新するときは、
移行元を再確認する場合は `chezmoi-master` を参照します。移行後の正本は
このリポジトリの `master` です。

## 構成

- `flake.nix`: macOS の nix-darwin と WSL Arch の Home Manager standalone
- `nix/`: Nix が管理する最小基盤
- `mise/`: OS 別 toolset と mise dotfiles
- `mise/dotfiles/`: 通常配置へ移植した設定ファイル
- `bootstrap/wsl/wsl.conf`: WSL の systemd と既定ユーザー設定
- `scripts/`: chezmoi 適用済みファイルを削除して切り替えるスクリプト
- `docs/`: 設計と移行計画

macOS と WSL では正本の `[tools]` 全キーを維持します。Windows は
Neovim とその周辺 CLI、MinGit、WezTerm の subset を使います。PowerShell
profile は任意適用です。

## 前提

- macOS と Windows に 1Password があり、SSH signing が有効であること
- WSL から
  `/mnt/c/Users/uvu1/AppData/Local/Microsoft/WindowsApps/op-ssh-sign-wsl.exe`
  を実行できること
- Windows では OpenSSH Client と PowerShell 7 を利用できること

## macOS

Nix を導入し、Command Line Tools の Git、または Nix の Git でこの
リポジトリを clone します。リポジトリルートで次を実行します。

```sh
sudo nix --extra-experimental-features 'nix-command flakes' run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake .#uvu1-mac
export MISE_EXPERIMENTAL=1
mise -C mise trust -a
mise -C mise -E darwin install
mise -C mise -E darwin ls --current
bash scripts/cutover-unix.sh darwin
```

二回目以降の Nix 適用は次のとおりです。

```sh
sudo darwin-rebuild switch --flake .#uvu1-mac
```

## WSL Arch

Windows 側で公式 distro 一覧に `ArchLinux` があることを確認して導入します。

```powershell
wsl --list --online
wsl --install -d ArchLinux
```

root 初期セッションでユーザーと最小依存を作成します。

```sh
useradd -m -G wheel -s /bin/bash uvu1
passwd uvu1
pacman -Syu --needed sudo git curl ca-certificates
```

`/etc/sudoers` の `%wheel ALL=(ALL:ALL) ALL` を有効化し、`uvu1` 所有の
ディレクトリへこのリポジトリを clone します。その後、次を実行します。

```sh
sudo install -m 0644 bootstrap/wsl/wsl.conf /etc/wsl.conf
```

Windows 側で distro 名を確認し、利用可能なら既定ユーザーも明示します。

```powershell
wsl -l -v
wsl --manage ArchLinux --set-default-user uvu1
wsl --shutdown
```

WSL を再起動して systemd と Nix を利用可能にした後、リポジトリルートで
次を実行します。

```sh
systemctl is-system-running
nix --extra-experimental-features 'nix-command flakes' run home-manager/release-26.05 -- switch --flake .#uvu1@arch-wsl
grep -qxF /home/uvu1/.nix-profile/bin/zsh /etc/shells || \
  echo /home/uvu1/.nix-profile/bin/zsh | sudo tee -a /etc/shells
chsh -s /home/uvu1/.nix-profile/bin/zsh uvu1
getent passwd uvu1
export MISE_EXPERIMENTAL=1
mise -C mise trust -a
mise -C mise -E linux install
mise -C mise -E linux ls --current
bash scripts/cutover-unix.sh linux
```

## Windows

PowerShell 7 で mise とこのリポジトリを利用可能にしてから実行します。

```powershell
$env:MISE_EXPERIMENTAL = "1"
mise -C mise trust -a
./scripts/cutover-windows.ps1
```

PowerShell profile も適用する場合は次のとおりです。

```powershell
./scripts/cutover-windows.ps1 -IncludePowerShell
```

どちらの場合も既存の chezmoi 由来 PowerShell profile と starship 設定は
削除します。`-IncludePowerShell` は新しい profile を再配置する場合にだけ指定します。

Windows の Git と WezTerm は mise の GitHub backendから展開されるため、
スタートメニュー登録は行いません。mise の shim またはターミナルから起動します。
Nvim と WezTerm の設定は、Windows の symlink 権限に依存しない copy 配置です。

## 検証

```sh
nix --extra-experimental-features 'nix-command flakes' build .#darwinConfigurations.uvu1-mac.system
nix --extra-experimental-features 'nix-command flakes' build '.#homeConfigurations."uvu1@arch-wsl".activationPackage'
export MISE_EXPERIMENTAL=1
mise -C mise -E darwin dotfiles status --missing
mise -C mise -E linux dotfiles status --missing
```

Windows では次を実行します。

```powershell
$env:MISE_EXPERIMENTAL = "1"
mise -C mise -E windows ls --current
mise -C mise -E windows dotfiles status --missing
```
