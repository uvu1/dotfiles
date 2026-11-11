# dotfiles

`github.com/uvu1/dotfiles` の `chezmoi-master`（旧 `master`）を移行元正本として、
chezmoi 管理の設定を Nix、Home Manager、nix-darwin、mise dotfiles へ移行した構成です。

移植時に参照した正本コミットは
`44ae8668a39989d0bfba1572ae869da3fb4b22f5` です。設定を更新するときは、
移行元を再確認する場合は `chezmoi-master` を参照します。移行後の正本は
このリポジトリの `master` です。

## 構成

- `flake.nix`: macOS の nix-darwin、WSL Arch の Home Manager standalone、mise 用 nixpkgs-unstable の固定
- `nix/`: Nix が管理する基盤と、グローバルに使う全ツール（LSP・リンタ・フォーマッタ・日常CLI・フォールバックランタイム）
- `mise/`: プロジェクト単位のバージョン切り替え、vendor CLI、OS 固有の toolset・mise dotfiles
- `mise/dotfiles/`: 通常配置へ移植した設定ファイル
- `mise/dotfiles/ai/`: Codex/Claude Codeの個人設定、共通skills、検証script
- `AGENTS.md` / `CLAUDE.md`: このrepository固有のagent向け指示
- `bootstrap/wsl/`: WSL の systemd、interop、既定ユーザー設定
- `.config/configuration.winget`: Windows のGUIアプリとbootstrap基盤
- `scripts/`: 初期構築と更新をまとめるスクリプト
- `docs/`: 設計と移行計画

macOS と WSL は共通の unix toolset（mise 環境 `unix`）を利用します。macOS は
加えて `darwin` 環境で Karabiner と Rio の設定を配置します。Windows は単一の `windows`
環境でNeovim、PowerShell profile、Windows用CLI、通常のdotfilesを管理します。
GUIアプリ、Git、mise、PowerShell、Rioの導入はWinGet Configurationが担当します。

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
   （詳細と症状は `docs/nvim-lsp-audit.md` の「既知の罠」）。
2. **vendor CLI。** `claude` / `cloudflared` / `aqua:openai/codex` はサービスに接続する
   クライアントで提供元の出荷に追従したいため、再現性より鮮度を取って `latest` の
   まま mise に残しています。

sheldonはmiseを `mise activate zsh`（PATH activation）で有効化します。`--shims` は
版が未解決のときPATHの後方へフォールスルーせず `No version is set for shim: <tool>`
で停止するため、フォールバックをnixに置く構成と両立しません。

同じツールを `nix/home.nix` とグローバルのmise toolsetの両方に宣言してはいけません。
miseはinstallディレクトリをNix profileより前に置くので、mise側が黙って勝ちます。

この分割は2026-07-31にmiseからnixへ移して成立したものです。nvimの設定を触る場合は
`docs/nvim-tooling-migration.md` に変更点と版の差分、`lib/mise.lua` の `base_path()` が
必須である理由がまとまっています。

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

`nekok`プロファイルは`~/.codex/nekok.config.toml`へsymlinkします。
zshで`codex --profile nekok`（`-p nekok`も可）を実行すると、1Password CLIの
`op read`で`op://Private/Nekok Free-Codex/username`からendpoint、
`op://Private/Nekok Free-Codex/credential`からAPIキーを取得します。
endpointは起動時のconfig override、APIキーは子プロセスの`NEKO_API`環境変数で渡し、
値をdotfilesやローカルconfigへ書き込みません。macOSでは1Password CLI、WSLでは
既存の`op` aliasが参照するWindows側のCLIが利用可能で、認証済みである必要があります。

Codex rulesは`dotfiles.rules`だけを共通baselineとして個別symlinkします。Codexが
approval時に更新する`default.rules`は端末固有fileとして残るため、追加のapprovalを
行ってもrepositoryはdirtyになりません。

AI設定を変更した後は次を実行します。

```sh
mise/dotfiles/ai/scripts/check-ai-config.sh
mise -C mise -E unix dotfiles status
```

## Takumi Guard

[Takumi Guard](https://shisho.dev/docs/ja/t/guard/)はnpm、PyPI、RubyGems、Goの
registryを仲介して悪性packageのinstallをblockするsecurity proxyです。macOSとWSLでは
`scripts/sync-takumi-guard.sh`が唯一の供給元で、`dotflow update`のafter_sync hookから
毎回再適用されます。Windows profileはnode / go / ruby / pythonを持たないため対象外です。

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

[dotflow](https://github.com/uvu1/dotflow) は WSL、macOS、Windows 共通の更新・編集
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
  WSL=`linux`、macOS=`darwin`、Windows=`windows` のprofile固有環境へ追加する
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

zshと管理対象のPowerShell profileは、mise activation直後に `shell-init` を読み込みます。
互換command `dotfiles-update` も残してあり、引数なしで `dotflow update` を呼びます。

初回導入または旧更新scriptからの切り替えでは、cloneしたリポジトリでbase configを
trustし、固定版をinstallしてからOS別cutoverを行います。

```sh
export MISE_EXPERIMENTAL=1
mise -C mise trust mise.toml
mise -C mise install github:uvu1/dotflow
mise -C mise x github:uvu1/dotflow@0.2.0 -- dotflow init "$PWD"
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
- Windows では OpenSSH Clientと、WinGet Configuration対応のwinget
  (`1.6.2631`以上)を利用できること

## macOS

Nix を導入し、Command Line Tools の Git、または Nix の Git でこの
リポジトリを clone します。リポジトリルートで次を実行します。

```sh
sudo nix --extra-experimental-features 'nix-command flakes' run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake .#uvu1-mac
export MISE_EXPERIMENTAL=1
mise -C mise trust -a
# unix の toolset は ~/.config/mise/config.toml が正本で、cutover の apply が
# それを symlink する。install はその後に実行する。
bash scripts/cutover-unix.sh darwin
mise -C mise -E unix install
mise -C mise -E unix ls --current
```

二回目以降の Nix 適用は次のとおりです。

```sh
sudo darwin-rebuild switch --flake .#uvu1-mac
```

この適用では `nix-homebrew` が Apple Silicon 用 Homebrew を `/opt/homebrew` に導入し、
1Password、Adobe Creative Cloud、ATOK、Cloudflare One Client、Discord Canary、
Google Chrome Canary、macFUSE、Microsoft Office、Obsidian、Rio、Scroll Reverser、Slack、Spark、
Spotify、Zen Twilight、Zoom を
Homebrew Cask で導入・更新します。Nix の宣言にない Homebrew package は削除しません。

macFUSE は SSHFS で遠隔ファイルを開くために使います。初回は macOS のシステム設定で
拡張機能を許可し、指示されたら再起動してください。SSHFS の実行ファイルは
Home Manager が Nix から供給します。

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
wsl-fuse-setup
wsl-ykman-setup --dry-run
wsl-ykman-setup
mise --version
grep -qxF /home/uvu1/.nix-profile/bin/zsh /etc/shells || \
  echo /home/uvu1/.nix-profile/bin/zsh | sudo tee -a /etc/shells
chsh -s /home/uvu1/.nix-profile/bin/zsh uvu1
getent passwd uvu1
export MISE_EXPERIMENTAL=1
mise -C mise trust -a
# unix の toolset は ~/.config/mise/config.toml が正本で、cutover の apply が
# それを symlink する。install はその後に実行する。
bash scripts/cutover-unix.sh unix
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

SSHFS を使う前に `test -c /dev/fuse` を確認します。デバイスがない場合は
WSL 側で FUSE を利用可能にしてから接続してください。SSHFS は Nix が供給し、
認証には既存の Windows OpenSSH とその SSH 設定を使います。非特権ユーザーの
マウントに必要な権限付き `fusermount3` は、`wsl-fuse-setup` が Nix で固定した
実体から配置します。初回と版の変更時だけ sudo を使い、`dotflow update` では
Home Manager の適用後に実行します。

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
dotfiles-update
```

`dotfiles-update` は互換aliasとして `dotflow update` を実行します。WSL profileは
pull後に `home-manager switch --flake ~/dotfiles#uvu1@arch-wsl` を実行してから、
`unix` mise環境をinstall・applyします。

## Neovim から SSH 先を編集

macOS または WSL の Neovim で `<leader>mc`（`:RemoteSSHFSConnect`）を実行し、SSH 接続先と
マウントするディレクトリを選びます。WSL では Windows 側の SSH config を読み、
同じ `ssh.exe` で接続します。接続先には SSH/SFTP が必要ですが、Neovim や dotfiles
の導入は不要です。接続後は通常の Explorer、`<leader>mf`（遠隔ファイル検索）、
`<leader>mg`（遠隔 grep）でファイルを操作できます。終了時は
`<leader>md` で切断します。
接続先が一覧に出ない場合は `:RemoteSSHFSConnect user@host:/path` で直接指定します。

`<leader>ff` と `<leader>fg` は、作業ディレクトリが接続中のマウント内なら遠隔検索に
切り替わります。ローカルのディレクトリへ移動すると従来の Snacks 検索に戻ります。
`<leader>mf` と `<leader>mg` は遠隔検索を直接呼びます。

Git 操作は `:terminal ssh 接続先` で開く SSH 先の端末で行ってください。
SSHFS 上で手元の Git や lazygit を実行すると、ファイルの多いリポジトリでは
遅くなります。LSP は手元で動くため、SSH 先にしかない依存関係は参照できません。
検索コマンドは SSH 先に `rg` があれば遠隔で実行でき、ない場合は手元の
Snacks 検索でマウント先を検索します。

## Windows

このリポジトリを `$HOME\dotfiles` へcloneし、Windows PowerShellまたはPowerShell 7で
bootstrapを実行します。Windows、WSLともに `$HOME\dotfiles` / `~/dotfiles` を
適用元の正本とします。

```powershell
./scripts/bootstrap-windows.ps1
```

bootstrapはWinGet Configuration機能を有効化し、`.config/configuration.winget` を
検証・適用してから、単一の `windows` mise環境をinstallします。その後、dotfilesの
dry-run、apply、status、`dotflow doctor`を順に実行します。既存dotfileと競合した場合は
削除や強制上書きをせず停止します。

WinGet Configurationはbootstrap基盤、Windows環境、ブラウザ、日常利用するGUIアプリを
宣言し、bootstrap実行時に最新版へ更新します。YAMLからresourceを削除しても、既に
導入済みのアプリは自動ではアンインストールされません。OS component、runtime、ゲーム、
chezmoi、miseと重複するCLIは宣言対象外です。

- bootstrap基盤: 1Password、7-Zip、Git、mise、PowerShell、Rio
- Windows環境: WSL、Windows Terminal、PowerToys
- ブラウザ: Chrome、Firefox Developer Edition/Nightly、Zen Browser/Twilight
- 日常アプリ: Obsidian、Slack、Zoom、Spark、Spotify、Discord Canary
- その他: Adobe Creative Cloud、Claude、Cloudflare WARP、Gyazo、ExplorerPatcher、
  TranslucentTB

### Windows の更新

PowerShell profile を含めて初回切り替えした後は、新しい PowerShell 7 を開き、
どのディレクトリからでも次の一コマンドで更新できます。

```powershell
dotfiles-update
```

`dotfiles-update` は互換aliasとして `dotflow update` を実行します。Windows profileは
単一の `windows` mise環境をinstallし、Neovim、gitconfig、Rio、combined mise
config、starship、PowerShell profileをまとめてapplyします。通常更新では重い
`winget configure`を再実行しません。

Windows の Git と Rio は winget で導入し、mise では管理しません。Nvim と
Rio の設定は、Windows の symlink 権限に依存しない copy 配置です。Rio は WSL を開き、
WSL 内で herdr を起動します。PowerShell は WSL から `pwsh.exe` として呼び出します。

### Windows のフォント

Rio は macOS と同じ `Moralerspace Neon` を使います。winget では配布されていないため、
初回だけ手動で導入します。

1. [yuru7/moralerspace の Releases](https://github.com/yuru7/moralerspace/releases) から
   `Moralerspace_v2.0.0.zip` を取得して展開する
2. `MoralerspaceNeon-*.ttf`（Regular / Bold / Italic / BoldItalic）を選び、右クリックの
   「インストール」で導入する
3. Rio を開き直す

フォントが無い場合、Rio は既定のフォントで表示します。

## 検証

```sh
nix --extra-experimental-features 'nix-command flakes' build .#darwinConfigurations.uvu1-mac.system
nix --extra-experimental-features 'nix-command flakes' build '.#homeConfigurations."uvu1@arch-wsl".activationPackage'
export MISE_EXPERIMENTAL=1
mise -C mise -E unix dotfiles status --missing
mise -C mise -E darwin dotfiles status --missing   # macOS のみ (karabiner, rio)
```

Windows では次を実行します。

```powershell
$env:MISE_EXPERIMENTAL = "1"
mise -C mise -E windows ls --current
mise -C mise -E windows dotfiles status --missing
winget configure validate -f .config/configuration.winget
winget configure test -f .config/configuration.winget --accept-configuration-agreements
dotflow doctor
Get-Command dotfiles-update
```
