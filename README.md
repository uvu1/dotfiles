# dotfiles

macOS、Arch WSL、Ubuntu ホスト `pve-dev` の開発環境を Nix、Home Manager、nix-darwin、mise dotfiles で管理します。
設定の正本はこのリポジトリの `master` です。ネイティブ Arch は管理しません。
Windows には WezTerm の設定と背景画像だけを WSL から配布します。

## 構成

- `flake.nix`: macOS の nix-darwin、Arch WSL と `pve-dev` の Home Manager standalone、mise 用 nixpkgs-unstable の固定
- `nix/`: Nix が管理する基盤と、グローバルに使う全ツール（LSP・リンタ・フォーマッタ・日常CLI・フォールバックランタイム）
- `mise/`: プロジェクト単位のバージョン切り替え、vendor CLI、OS 固有の toolset・mise dotfiles
- `mise/dotfiles/`: 通常配置へ移植した設定ファイル
- `mise/dotfiles/ai/`: Codex/Claude Codeの個人設定、共通skills、検証script
- `AGENTS.md` / `CLAUDE.md`: このrepository固有のagent向け指示
- `bootstrap/wsl/`: WSL の systemd、interop、既定ユーザー設定
- `scripts/`: AI 設定と Takumi Guard の同期・検証
- `docs/`: 運用手順とコンポーネントの注意点

macOS と WSL は共通の `unix` mise 環境を利用します。macOS は `darwin` 環境で
Karabiner と WezTerm を配置し、WSL は `wsl` 環境で Windows の WezTerm 設定を配置します。
Windows 側のアプリ導入、PowerShell、開発ツールは管理しません。

### nix と mise の責務

グローバルに使うツールは `nix/home.nix` が唯一の供給元です。言語サーバ、リンタ、
フォーマッタ、日常CLI、そしてプロジェクト外のファイル向けフォールバックランタイム
（node / python / go / ruby / rust）がここに入り、`flake.lock` で固定されます。

miseが担うのは次の2つだけです。

1. **プロジェクト単位のバージョン切り替え。** 各プロジェクトの `mise.toml` や
   `.node-version` / `.ruby-version` / `Gemfile` が唯一の宣言元で、そのディレクトリ
   以下でだけ nix のフォールバックより前に出ます。
   gem製のLSPはインタプリタがビルド時のrubyに固定されるため、Gemfileが別のrubyを
   pinしているプロジェクトでは `mise.local.toml` に `gem:ruby-lsp` を宣言します
   （詳細と症状は [Neovim 運用ノート](docs/agents/nvim.md)）。
2. **vendor CLI。** Claude、Codex、herdr、agent-browser、OpenCode は mise で管理します。
   提供元の出荷に追従するため基本は `latest`、OpenCode はメジャー版 `2` を指定しています。

sheldonはmiseを `mise activate zsh`（PATH activation）で有効化します。`--shims` は
版が未解決のときPATHの後方へフォールスルーせず `No version is set for shim: <tool>`
で停止するため、フォールバックをnixに置く構成と両立しません。

同じツールを `nix/home.nix` とグローバルのmise toolsetの両方に宣言してはいけません。
miseはinstallディレクトリをNix profileより前に置くので、mise側が黙って勝ちます。

Neovim のツール解決・Ruby の注意点・検証手順は
[運用ノート](docs/agents/nvim.md) にまとめています。

PostgreSQL 本体と libpq（開発ヘッダー・`pg_config` を含む）はグローバル供給しません。
必要なプロジェクトの Nix devShell 等で宣言します。既存 DB や導入済みパッケージの削除は行いません。

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

- Codex: `~/.codex/AGENTS.md`、`~/.codex/config.toml`内の管理block
- Claude Code: `~/.claude/CLAUDE.md`、`~/.claude/settings.json`
- 共通skills: `mise/dotfiles/ai/skills/common/`を正本とし、Codex用とClaude用の
  viewから参照
- このrepository向けの指示: `AGENTS.md`には全体の方針と索引だけを置き、
  component固有の注意点は`docs/agents/`に分けて編集時だけ読ませる

CodexのMCP tokenはconfigへ直接書かず環境変数から渡します。Claude Codeのuser scope
MCPは認証状態を含む`~/.claude.json`へ保存されるため、このfile自体は管理しません。
project共有MCPは各projectの`.mcp.json`で管理します。

Codexの`config.toml`はproject trustなどの端末固有状態も保持するため、file全体を
symlinkしません。`scripts/sync-ai-config.sh`が`mise/dotfiles/ai/codex/config.toml`の
既定値だけをmarker付きblockとして同期し、その他の設定は保持します。この同期は
`dotflow update`のmacOS/WSL hookでも実行されます。
同期はNixで供給するPythonの標準TOML parserで検証し、marker内に混在した端末固有設定も
保持します。管理対象外の値が変わる場合は書き込みを中止します。
`bash scripts/sync-ai-config.sh --dry-run`で、変更せずに同期可否を確認できます。

Codex の個別操作許可（`~/.codex/rules/`）は端末ローカルで管理し、共通配布しません。

AI設定を変更した後は次を実行します。

```sh
mise/dotfiles/ai/scripts/check-ai-config.sh
mise -C mise -E unix dotfiles status
```

## Takumi Guard

[Takumi Guard](https://shisho.dev/docs/ja/t/guard/)はnpm、PyPI、RubyGems、Goの
registryを仲介して悪性packageのinstallをblockするsecurity proxyです。macOSとWSLでは
`scripts/sync-takumi-guard.sh`が唯一の供給元で、`dotflow update`のafter_sync hookから
毎回再適用されます。

適用先は次のとおりです。いずれも各tool公式の方法で書き込み、他の設定keyは壊しません。

- npm / pnpm / yarn v1: `~/.npmrc`の`registry`と`//npm.flatt.tech/:_authToken`
- RubyGems: `~/.bundle/config`の`mirror.https://rubygems.org`（`Gemfile`の変更は不要）
- Go: `go env -w`による`GOPROXY`と、`~/.netrc`の`machine golang.flatt.tech`
- PyPI: pipの`index-url`と、uvの`[[index]]`（どちらも先頭のmarker行で所有を示し、
  markerの無い既存fileは上書きせず中止する）

これらのfileはすべてtokenを含むため、端末ローカルに留めrepositoryでは追跡しません。
mise dotfilesにも載せません。

tokenは`TAKUMI_GUARD_TOKEN`、無ければ1Password CLIの`op read`で
`op://Private/Takumi Guard/credential`から取得します。WSLでは`op` aliasと同じく
Windows側のCLIを使います。どちらからも取得できない場合は、未設定の対象だけ匿名
（token無し）で有効化して終了します。1Password未sign inの端末で`dotflow update`を
止めず、blockだけは必ず効く状態にするためです。既にtoken付きで設定済みの対象は、
その回では変更しません。

tokenの取得は一度だけ手で行います。利用規約とprivacy policyに同意のうえ、

```sh
curl -X POST https://npm.flatt.tech/api/v1/tokens \
  -H 'Content-Type: application/json' \
  -d '{"email": "<アドレス>", "language": "ja"}'
```

を実行し、welcome mailに届く`tg_anon_...`を1Passwordの`Private`金庫にitem名
`Takumi Guard`で保存します。1つのtokenでnpm / PyPI / RubyGems / Go共通に使えます。

手で確認・適用する場合は次を実行します。

```sh
bash scripts/sync-takumi-guard.sh --dry-run
bash scripts/sync-takumi-guard.sh
```

注意点があります。

- npm 11.15.0以降は、設定中に追加・更新された`package-lock.json`のentryに
  `npm.flatt.tech`が記録されます。team共有のrepositoryでは、project側の`.npmrc`に
  `registry=https://registry.npmjs.org/`を置いて打ち消すか、その差分をcommitしない
  運用が必要です。pnpmはlock fileにregistry URLを記録しません。
- `GOPROXY`に`,direct`のfallbackは付けません（block対象がVCS経由で迂回されうるため
  公式が禁じています）。社内のprivate moduleがある場合は`go env -w GOPRIVATE=...`を
  別途設定します。
- 取得先に到達できないとinstallは完了しません。公式registryへの自動fallbackはありません。
- macOSのpipは`~/Library/Application Support/pip`が存在するとそちらを優先するため、
  scriptはdirectoryの有無を見て書き込み先を選びます。
- yarn berryの`.yarnrc.yml`はproject単位のため、global適用の対象外です。

動作確認は公式のtest packageで行います。いずれも403で失敗すれば有効です。

```sh
cd $(mktemp -d) && npm install @panda-guard/test-malicious
cd $(mktemp -d) && go mod init verify-takumi-guard && go get github.com/flatt-security/hola-takumi-go@v0.1.0
cd $(mktemp -d) && printf 'source "https://rubygems.org"\ngem "hola-takumi", "0.1.0"\n' > Gemfile && bundle install
```

## dotflow

[dotflow](https://github.com/uvu1/dotflow) は WSL と macOS の更新・編集
インターフェースです。このリポジトリでは GitHub release の `0.2.0` に固定しており、
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
  WSL=`unix`、macOS=`unix` の共有環境へ追加する。OS固有の配置は
  `mise.wsl.toml` / `mise.darwin.toml` に明示する
- `dotflow edit TARGET`: 選択profileの追加先環境で対象を編集する
- `dotflow root`: 登録済みリポジトリの絶対pathを表示する
- `dotflow cd`: shell integration経由でリポジトリへ移動する
- `dotflow status` / `dotflow status --check`: Gitとmiseの状態を表示・検査する
- `dotflow apply`: pullやtool installをせず、選択profileのdotfilesを適用する
- `dotflow doctor`: config、repository、依存command、選択環境を診断する
- `dotflow check`: 手元の `origin/master` が `HEAD` より進んでいれば `dotflow update` を促す。
  networkには触れず、前回のfetchから6時間以上経っていれば裏でfetchする
- `dotflow completion SHELL`: 静的completionを生成する
- `dotflow shell-init SHELL`: `dotflow cd` 対応wrapperと、起動時の `dotflow check` を生成する
  （`--no-check` で起動時の更新通知を無効化）

zsh は mise activation 直後に `shell-init` を読み込みます。更新コマンドは
`dotflow update` に統一しています。

初回導入では、下記の OS 別手順で Nix と dotfiles を配置した後、clone した
リポジトリで base config を trust し、固定版の dotflow を登録します。

```sh
export MISE_EXPERIMENTAL=1
mise -C mise trust mise.toml
mise -C mise install github:uvu1/dotflow
mise -C mise x github:uvu1/dotflow@0.2.0 -- dotflow init "$PWD"
dotflow doctor
dotflow update --dry-run
```

既に `~/dotfiles` が既定pathならlocator登録は必須ではありません。`init` は既存cloneを
登録するだけで、cloneやGit初期化は行いません。既存の設定と競合した場合は強制上書きせず、
内容を確認してから適用します。

## 前提

- macOS と Windows に 1Password があり、SSH signing が有効であること
- WSL から
  `/mnt/c/Users/uvu1/AppData/Local/Microsoft/WindowsApps/op-ssh-sign-wsl.exe`
  を実行できること
- Windows では OpenSSH Client と WezTerm Nightly を別途導入すること

## macOS

Nix を導入し、Command Line Tools の Git、または Nix の Git でこの
リポジトリを clone します。リポジトリルートで次を実行します。

```sh
sudo nix --extra-experimental-features 'nix-command flakes' run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake .#uvu1-mac
export MISE_EXPERIMENTAL=1
mise -C mise trust -a
# 共有設定を配置してから、そのグローバル toolset を install する。
mise -C mise -E unix dotfiles apply --dry-run
mise -C mise -E unix dotfiles apply
mise -C mise -E darwin dotfiles apply --dry-run ~/.config/karabiner ~/.config/wezterm
mise -C mise -E darwin dotfiles apply ~/.config/karabiner ~/.config/wezterm
mise -C mise -E unix install
mise -C mise -E unix ls --current
```

二回目以降の Nix 適用は次のとおりです。

```sh
sudo darwin-rebuild switch --flake .#uvu1-mac
```

この適用では `nix-homebrew` が Apple Silicon 用 Homebrew を `/opt/homebrew` に導入し、
1Password、Adobe Creative Cloud、Discord Canary、Hidden Bar、Karabiner、Office、Obsidian、
Raycast、Scroll Reverser、Slack、Spark、Spotify、WezTerm Nightly、Zen Twilight、Zoom を
Homebrew Cask で導入・更新します。宣言から外したアプリや宣言にない package は削除しません。
アプリの認証・ライセンス登録と macOS の権限許可は、初回起動後に行います。

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
wsl-ykman-setup --dry-run
wsl-ykman-setup
mise --version
grep -qxF /home/uvu1/.nix-profile/bin/zsh /etc/shells || \
  echo /home/uvu1/.nix-profile/bin/zsh | sudo tee -a /etc/shells
chsh -s /home/uvu1/.nix-profile/bin/zsh uvu1
getent passwd uvu1
export MISE_EXPERIMENTAL=1
mise -C mise trust -a
# 共有設定を配置してから、そのグローバル toolset を install する。
mise -C mise -E unix dotfiles apply --dry-run
mise -C mise -E unix dotfiles apply
mise -C mise -E unix install
mise -C mise -E unix ls --current
```

`mise --version` は `2026.6.14` 以上を返す必要があります。通常の nixpkgs 26.05 に
含まれる古い mise ではなく、`flake.lock` で固定した nixpkgs-unstable 版を
macOS/WSL 共通で利用します。

WSL では blink.cmp の Rust fuzzy matcher をビルドするため、Home Manager が
GCC と linker も導入します。また、Neovim のクリップボード連携に必要な
`wl-copy` と `wl-paste` も導入します。`linker cc not found` が出た場合は
Nix 構成を再適用した後、Neovim で blink.cmp を再ビルドします。

### WSL で YubiKey を使う

`ykman` は Nix の `yubikey-manager` が供給します。WSL 2 では Windows からの
USB 転送が別途必要です。Windows 側に [usbipd-win](https://github.com/dorssel/usbipd-win)
の公式インストーラーでドライバーとサービスを導入してください。これは Nix/mise で
供給するユーザー用 CLI とは別の、Windows 側の USB 転送基盤です。
転送手順は [Microsoft の公式ドキュメント](https://learn.microsoft.com/windows/wsl/connect-usb)
を参照します。以下は usbipd-win 4 以降のコマンドです。

YubiKey を挿し、管理者 PowerShell で一覧の BUSID を確認して共有します。
`<BUSID>` は YubiKey の値に置き換えます。

```powershell
usbipd list
usbipd bind --busid <BUSID>
```

WSL を起動したまま、通常の PowerShell で転送します。

```powershell
usbipd attach --wsl --busid <BUSID>
```

WSL 側で構成を適用し、PC/SC サービスと USB/HID の権限を設定します。
`wsl-ykman-setup` は Nix で固定した `pcsclite` と `ccid` を使い、初回と設定・版の
変更時に sudo で systemd unit と udev rule を配置します。既存の `pcscd.service` /
`pcscd.socket` が稼働中なら競合を避けるため処理を中断します。以後の `dotflow update` でも
Home Manager の適用後に設定を更新します。

```sh
cd ~/dotfiles
home-manager switch --flake .#uvu1@arch-wsl
wsl-ykman-setup --dry-run
wsl-ykman-setup
ykman list
ykman info
```

USB 転送中は Windows 側のアプリからその YubiKey を使えません。Windows に戻す場合は
PowerShell で `usbipd detach --busid <BUSID>` を実行します。抜き差しや WSL 再起動後は
再度 attach が必要です。`ykman list` が空なら `usbipd list` の Attached 状態を確認し、
PC/SC のエラーなら `systemctl status wsl-ykman-pcscd.service` を確認してください。

### WSL の更新

初回切り替え後は、どのディレクトリからでも次の一コマンドで更新できます。

```sh
dotflow update
```

WSL profile は共有の `unix` 設定と Windows 向けの `wsl` 設定を配置し、
Home Manager、YubiKey 設定、AI 設定、Takumi Guard も更新します。

## Ubuntu (`pve-dev`)

`dev@pve-dev` は x86_64 Linux の `dev` ユーザー (`/home/dev`) 向けの Home Manager プロファイルです。
Nix と Home Manager が導入済みの状態で、リポジトリルートから適用します。

```sh
NIX_CONFIG='extra-experimental-features = nix-command flakes' \
  home-manager switch --flake '.#dev@pve-dev'
```

dotfiles の配置状況は `mise -C mise -E unix dotfiles status` で確認できます。

## infra 専用のシェル設定

Kubernetes の Ctrl-K、`k` alias、補完・プロンプト表示と Vault 補完は、通常のシェルでは
有効化しません。infra リポジトリの `mise.toml` の zsh `enter` / `leave` hook から
`~/.config/zsh/optional/infra.zsh` を読み込みます。プロジェクト配下と各 worktree で有効になり、
退出すると以前の alias・キーバインド・補完・`STARSHIP_CONFIG` に戻ります。
kubectl と Vault 本体は infra の mise toolset が供給します。
詳細は [プロジェクト限定シェル設定](docs/agents/project-shell.md) を参照してください。

## Neovim から SSH 先を編集

現行の接続方法と SSH 先の準備は [標準 SSH 開発手順](docs/nvim-remote-dev.md) を参照してください。
通常の操作・設計と検証は [Neovim 運用ノート](docs/agents/nvim.md)、
herdr の Claude との接続は [AI 連携手順](docs/nvim-ai-integration.md) を参照してください。

## Windows の WezTerm

Windows 側に [WezTerm Nightly](https://wezterm.org/install/windows.html) を導入します。
macOS と共通の Lua 設定と背景画像を WSL から `%USERPROFILE%/.config/wezterm/` にコピーします。

初回は WSL で配置予定を確認してから適用します。以後は WSL の `dotflow update` に含まれます。

```sh
wezterm_dir=/mnt/c/Users/uvu1/.config/wezterm
mise -C mise -E wsl dotfiles apply --dry-run "$wezterm_dir"/{appearance.lua,keybinds.lua,resources/background.jpg,wezterm.lua}
mise -C mise -E wsl dotfiles apply "$wezterm_dir"/{appearance.lua,keybinds.lua,resources/background.jpg,wezterm.lua}
```

WezTerm は macOS ではローカルの zsh、Windows では `wsl.exe` 経由で WSL 内の zsh を起動します。
WezTerm のタブは Ctrl+B を押してから、t で開き、w で閉じ、1〜9 で切り替えます。
`herdr --remote <接続先>` でリモートの Herdr に接続し、Ctrl+1〜9 で Herdr のタブを切り替えます。
Windows 側に以前の `%USERPROFILE%/.wezterm.lua` がある場合は、移行前にどの設定を読み込むか確認してください。
配布を終了した既存設定やインストール済みアプリは自動削除しません。

## 検証

```sh
nix flake check --no-build --all-systems
nix build --no-link --dry-run '.#darwinConfigurations."uvu1-mac".config.home-manager.users.uvu1.home.path'
export MISE_EXPERIMENTAL=1
mise -C mise -E unix dotfiles status
mise -C mise -E darwin dotfiles status   # macOS のみ
mise -C mise -E wsl dotfiles status      # WSL のみ
dotflow doctor
mise/dotfiles/ai/scripts/check-ai-config.sh
python3 scripts/test_project_shell.py
```

`--dry-run` はビルド予定だけを確認します。対応する macOS 環境では `--dry-run` を外して
profile をビルドし、実際のファイル名衝突も検証してください。実機への適用は行いません。
