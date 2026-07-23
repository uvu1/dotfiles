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
- `mise/`: 共通(unix) と OS 固有の toolset・mise dotfiles
- `mise/dotfiles/`: 通常配置へ移植した設定ファイル
- `mise/dotfiles/ai/`: Codex/Claude Codeの個人設定、共通skills、検証script
- `AGENTS.md` / `CLAUDE.md`: このrepository固有のagent向け指示
- `bootstrap/wsl/`: WSL の systemd、interop、既定ユーザー設定
- `scripts/`: chezmoi 適用済みファイルを削除して切り替えるスクリプト
- `docs/`: 設計と移行計画

macOS と WSL は共通の unix toolset（mise 環境 `unix`）を利用します。macOS は
加えて `darwin` 環境で wezterm 設定を配置します。Windows は Neovim とその周辺
CLI の subset を mise で使います（Git と WezTerm は winget で導入）。PowerShell
profile を含める場合は bat、eza、gh、ghq、kubectl、starship も追加します。

`bun` と `uv` はグローバルtoolsetに含めません。必要なプロジェクトのルートで
それぞれ次を実行し、プロジェクトの `mise.toml` に追加します。

```sh
mise use bun@latest
mise use uv@latest
```

これにより、各toolはそのプロジェクト以下でだけ有効になります。チームで共有しない
個人用設定にする場合は、`mise use --env local bun@latest` または
`mise use --env local uv@latest` を使い、生成される `.mise.local.toml` をGitの
管理対象外にします。グローバル設定から削除しても、miseが既にダウンロードした
インストール実体は自動では削除されませんが、プロジェクト外では有効になりません。

## Codex / Claude Code

macOSとWSLでは、mise dotfilesがCodexとClaude Codeの個人設定を個別file単位で
symlinkします。`~/.codex`や`~/.claude`全体は管理対象にせず、認証、履歴、session、
cache、生成memory、端末固有のtrust状態をローカルに残します。

- Codex: `~/.codex/AGENTS.md`、`~/.codex/config.toml`内の管理block、
  `~/.codex/rules/`
- Claude Code: `~/.claude/CLAUDE.md`、`~/.claude/settings.json`
- 共通skills: `mise/dotfiles/ai/skills/common/`を正本とし、Codex用とClaude用の
  viewから参照

CodexのMCP tokenはconfigへ直接書かず環境変数から渡します。Claude Codeのuser scope
MCPは認証状態を含む`~/.claude.json`へ保存されるため、このfile自体は管理しません。
project共有MCPは各projectの`.mcp.json`で管理します。

Codexの`config.toml`はproject trustなどの端末固有状態も保持するため、file全体を
symlinkしません。`scripts/sync-ai-config.sh`が`mise/dotfiles/ai/codex/config.toml`の
既定値だけをmarker付きblockとして同期し、その他の設定は保持します。この同期は
`dotflow update`のmacOS/WSL hookでも実行されます。

Codex rulesは`dotfiles.rules`だけを共通baselineとして個別symlinkします。Codexが
approval時に更新する`default.rules`は端末固有fileとして残るため、追加のapprovalを
行ってもrepositoryはdirtyになりません。

AI設定を変更した後は次を実行します。

```sh
mise/dotfiles/ai/scripts/check-ai-config.sh
mise -C mise -E unix dotfiles status
```

## dotflow

[dotflow](https://github.com/uvu1/dotflow) は WSL、macOS、Windows 共通の更新・編集
インターフェースです。このリポジトリでは GitHub release の `0.1.0` に固定しており、
`latest` へ自動追従しません。crates.io への公開は release asset の利用とは別の手動作業で、
このリポジトリの導入・更新手順には含みません。

日常の更新は任意のディレクトリから次を実行します。

```sh
dotflow update
```

`dotflow update` はリポジトリ、branch、origin、tracked/untracked を含む clean な
worktree を検証してから `origin/master` へ fast-forwardし、選択したOS profileの
Nix hook、mise tool install、mise dotfiles apply、status確認を順に実行します。
commit、push、stash、reset、rebase、ファイル削除は行わず、dirty treeではpull前に
停止します。実行予定を変更やnetwork accessなしで確認するには
`dotflow update --dry-run` を使います。

主なコマンドは次のとおりです。

- `dotflow add TARGET...`: base mise環境へ対象を追加する。`--profile` を明示した場合は、
  WSL=`linux`、macOS=`darwin`、Windows=`windows` のprofile固有環境へ追加する
- `dotflow edit TARGET`: 選択profileの追加先環境で対象を編集する
- `dotflow root`: 登録済みリポジトリの絶対pathを表示する
- `dotflow cd`: shell integration経由でリポジトリへ移動する
- `dotflow status` / `dotflow status --check`: Gitとmiseの状態を表示・検査する
- `dotflow apply`: pullやtool installをせず、選択profileのdotfilesを適用する
- `dotflow doctor`: config、repository、依存command、選択環境を診断する
- `dotflow completion SHELL`: 静的completionを生成する
- `dotflow shell-init SHELL`: `dotflow cd` 対応wrapperを生成する

zshと管理対象のPowerShell profileは、mise activation直後に `shell-init` を読み込みます。
互換command `dotfiles-update` も残してあり、引数なしで `dotflow update` を呼びます。

初回導入または旧更新scriptからの切り替えでは、cloneしたリポジトリでbase configを
trustし、固定版をinstallしてからOS別cutoverを行います。

```sh
export MISE_EXPERIMENTAL=1
mise -C mise trust mise.toml
mise -C mise install github:uvu1/dotflow
mise -C mise x github:uvu1/dotflow@0.1.0 -- dotflow init "$PWD"
dotflow doctor
dotflow update --dry-run
```

既に `~/dotfiles` が既定pathならlocator登録は必須ではありません。`init` は既存cloneを
登録するだけで、cloneやGit初期化は行いません。過去のchezmoi移行経緯と対象の詳細は
下記の各OS手順および `docs/dotfiles-migration-plan.md` に残しています。

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
mise -C mise -E unix install
mise -C mise -E unix ls --current
bash scripts/cutover-unix.sh darwin
```

二回目以降の Nix 適用は次のとおりです。

```sh
sudo darwin-rebuild switch --flake .#uvu1-mac
```

この適用では `nix-homebrew` が Apple Silicon 用 Homebrew を `/opt/homebrew` に導入し、
1Password、Adobe Creative Cloud、ATOK、Cloudflare One Client、Discord Canary、
Microsoft Office、Obsidian、Scroll Reverser、Slack、Spark、Spotify、WezTerm Nightly、
Zen Twilight、Zoom を
Homebrew Cask で導入・更新します。Nix の宣言にない Homebrew package は削除しません。

Adobe 製品本体は Creative Cloud から選択して導入します。1Password、Adobe、ATOK、
Cloudflare、Office などのアカウント・ライセンス認証、macOS の権限許可、Cloudflare
Zero Trust への端末登録、ATOK の入力ソース選択は各アプリの初回起動後に行います。

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
sudo install -Dm 0644 bootstrap/wsl/WSLInterop.conf /etc/binfmt.d/WSLInterop.conf
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
test -e /proc/sys/fs/binfmt_misc/WSLInterop
(cd /mnt/c && /mnt/c/Windows/System32/cmd.exe /d /c echo WSL-interop-ok)
curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install |
  sh -s -- --daemon
```

`cmd.exe` が `Exec format error` になり、`WSLInterop` が存在しない既存環境では、
bootstrap設定を配置して `systemd-binfmt` を再起動します。WSL全体のshutdownは
不要です。

```sh
cd ~/dotfiles
sudo install -m 0644 bootstrap/wsl/wsl.conf /etc/wsl.conf
sudo install -Dm 0644 bootstrap/wsl/WSLInterop.conf /etc/binfmt.d/WSLInterop.conf
sudo systemctl restart systemd-binfmt.service
(cd /mnt/c && /mnt/c/Windows/System32/cmd.exe /d /c echo WSL-interop-ok)
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
mise -C mise -E unix install
mise -C mise -E unix ls --current
bash scripts/cutover-unix.sh unix
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

`dotfiles-update` は互換aliasとして `dotflow update` を実行します。WSL profileは
pull後に `home-manager switch --flake ~/dotfiles#uvu1@arch-wsl` を実行してから、
`unix` mise環境をinstall・applyします。

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

`dotfiles-update` は互換aliasとして `dotflow update` を実行します。Windows profileは
`windows`、`windows-powershell` の順に処理します。前者だけがNeovim、gitconfig、
WezTerm 設定を、後者だけが重複し得るcombined mise config、starship、PowerShell
profileをapplyします。

Windows の Git と WezTerm は winget で導入し、mise では管理しません。Nvim と
WezTerm の設定は、Windows の symlink 権限に依存しない copy 配置です。

## 検証

```sh
nix --extra-experimental-features 'nix-command flakes' build .#darwinConfigurations.uvu1-mac.system
nix --extra-experimental-features 'nix-command flakes' build '.#homeConfigurations."uvu1@arch-wsl".activationPackage'
export MISE_EXPERIMENTAL=1
mise -C mise -E unix dotfiles status --missing
mise -C mise -E darwin dotfiles status --missing   # macOS のみ (wezterm)
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
