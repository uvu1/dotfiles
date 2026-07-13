# dotfiles

`github.com/uvu1/dotfiles` の `chezmoi-master`（旧 `master`）を移行元正本として、
chezmoi 管理の設定を Nix、Home Manager、nix-darwin、mise dotfiles へ移行した構成です。

移植時に参照した正本コミットは
`44ae8668a39989d0bfba1572ae869da3fb4b22f5` です。設定を更新するときは、
移行元を再確認する場合は `chezmoi-master` を参照します。移行後の正本は
このリポジトリの `master` です。

## 構成

- `flake.nix`: macOS の nix-darwin、WSL Arch の Home Manager standalone、mise 用 nixpkgs-unstable の固定
- `nix/`: Nix が管理する最小基盤
- `mise/`: OS 別 toolset と mise dotfiles
- `mise/dotfiles/`: 通常配置へ移植した設定ファイル
- `bootstrap/wsl/wsl.conf`: WSL の systemd と既定ユーザー設定
- `scripts/`: chezmoi 適用済みファイルを削除して切り替えるスクリプト
- `docs/`: 設計と移行計画

macOS と WSL では現在のdarwin/linux用toolsetを利用します。Windows は
Neovim とその周辺 CLI、MinGit、WezTerm の subset を使います。PowerShell
profile を含める場合は bat、eza、gh、ghq、kubectl、starship も追加します。

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

`/etc/sudoers` の `%wheel ALL=(ALL:ALL) ALL` を有効化し、このリポジトリを
`uvu1` 所有の `~/dotfiles` へ clone します。その後、次を実行します。

```sh
git clone https://github.com/uvu1/dotfiles ~/dotfiles
cd ~/dotfiles
sudo install -m 0644 bootstrap/wsl/wsl.conf /etc/wsl.conf
```

Windows 側で distro 名を確認し、利用可能なら既定ユーザーも明示します。

```powershell
wsl -l -v
wsl --manage ArchLinux --set-default-user uvu1
wsl --shutdown
```

WSL を再起動したら systemd を確認します。Nix が未導入の場合のみ、`uvu1`
ユーザーで multi-user インストールを実行します。

```sh
systemctl is-system-running
curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install |
  sh -s -- --daemon
```

新しいシェルを開くか、次のコマンドで Nix を読み込みます。`nix-command` と
`flakes` は Home Manager が内部で実行する Nix にも適用されるよう、ユーザー設定へ
恒久的に追加します。

```sh
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
mkdir -p ~/.config/nix
grep -qxF 'extra-experimental-features = nix-command flakes' ~/.config/nix/nix.conf 2>/dev/null || \
  echo 'extra-experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
nix --version
systemctl is-active nix-daemon.socket
```

その後、リポジトリルートで次を実行します。

```sh
nix run home-manager/release-26.05 -- switch --flake .#uvu1@arch-wsl
mise --version
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

`mise --version` は `2026.6.14` 以上を返す必要があります。通常の nixpkgs 26.05 に
含まれる古い mise ではなく、`flake.lock` で固定した nixpkgs-unstable 版を
macOS/WSL 共通で利用します。

WSL では blink.cmp の Rust fuzzy matcher をビルドするため、Home Manager が
GCC と linker も導入します。また、Neovim のクリップボード連携に必要な
`wl-copy` と `wl-paste` も導入します。`linker cc not found` が出た場合は
Nix 構成を再適用した後、Neovim で blink.cmp を再ビルドします。

### WSL の更新

初回切り替え後は、どのディレクトリからでも次の一コマンドで更新できます。

```sh
dotfiles-update
```

`dotfiles-update` は `~/dotfiles` の `master` を `origin/master` へ fast-forwardし、
Home Manager、mise tools、mise dotfiles の順に適用して status まで確認します。
commit、push、stash、reset、ファイル削除は行いません。tracked/untracked を問わず
worktree に変更がある場合は、変更一覧を表示して pull 前に終了します。

## Windows

PowerShell 7 で mise を利用可能にし、このリポジトリを
`$HOME\dotfiles` へ clone してから実行します。Windows、WSLともに
`$HOME\dotfiles` / `~/dotfiles` を適用元の正本とします。

```powershell
$env:MISE_EXPERIMENTAL = "1"
mise -C mise trust -a
./scripts/cutover-windows.ps1 -IncludePowerShell
```

既存の chezmoi 由来設定を削除せず、対象だけを確認する場合は、切り替えスクリプトが
表示する dry-run の後の確認入力で中止します。自動実行時は、削除対象を確認済みの場合に
限り `-Yes` を追加できます。

```powershell
./scripts/cutover-windows.ps1 -IncludePowerShell -Yes
```

`-IncludePowerShell` を省略すると、新しい PowerShell profile、starship 設定、
PowerShell 用ツールは配置しません。どちらの場合も既存の chezmoi 由来 PowerShell
profile と starship 設定は削除します。

### Windows の更新

PowerShell profile を含めて初回切り替えした後は、新しい PowerShell 7 を開き、
どのディレクトリからでも次の一コマンドで更新できます。

```powershell
dotfiles-update
```

`dotfiles-update` は `$HOME\dotfiles` が `uvu1/dotfiles` の `master` で
clean なことを検証し、`origin/master` へ fast-forward します。その後、Windows と
PowerShell の mise tools、mise dotfiles を順に適用して status まで確認します。
tracked/untracked を問わず worktree に変更がある場合は、変更一覧を表示して pull 前に
終了します。commit、push、stash、reset、ファイル削除は行いません。

Windows の Git と WezTerm は mise の GitHub backendから展開されるため、
スタートメニュー登録は行いません。mise の shim またはターミナルから起動します。
Nvim と WezTerm の設定は、Windows の symlink 権限に依存しない copy 配置です。
MinGit はGitHub側のTSA証明書とmiseの検証が一致しないリリースがあるため、このtoolの
install中だけGitHub Artifact Attestationsを無効化します。checksumとSLSA provenanceの
検証は維持し、他のGitHub backend toolsではArtifact Attestationsも有効なままです。

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
mise -C mise -E windows-powershell ls --current
mise -C mise -E windows-powershell dotfiles status --missing `
  $HOME/.config/mise/config.toml `
  $HOME/.config/starship.toml `
  $HOME/Documents/PowerShell
Get-Command dotfiles-update
```
