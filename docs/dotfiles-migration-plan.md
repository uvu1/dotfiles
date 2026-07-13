# macOS / WSL Arch 開発環境維持の Dotfiles 移行計画

## Summary

- `github.com/uvu1/dotfiles` の `chezmoi-master`（移行前の `master`）の開発体験を維持しつつ、chezmoi から `Nix + Home Manager + nix-darwin + mise dotfiles` へ移行する。
- 主環境は `macOS` と `WSL ArchLinux`。macOS は nix-darwin + Home Manager、WSL Arch は Home Manager standalone で管理する。
- 所有範囲を明確に分ける。Nix は OS/system と最小基盤、mise は開発 CLI、mise dotfiles は設定ファイルを管理する。
- Windows は補助環境として `wezterm / git / nvim` を mise dotfiles で適用し、将来的に PowerShell profile も同じ仕組みで共有できる構造にする。

## Key Changes

### Nix flake

- repo に `flake.nix` と `flake.lock` を追加し、`nixpkgs`, `home-manager`, `nix-darwin` を固定してコミット対象にする。
- outputs は `darwinConfigurations."uvu1-mac"` と `homeConfigurations."uvu1@arch-wsl"` を定義する。
- `hostPlatform` は macOS を `aarch64-darwin`、WSL Arch を `x86_64-linux` として固定する。Intel Mac を使う場合のみ macOS hostPlatform を `x86_64-darwin` に差し替える。
- `home.username = "uvu1"`、`home.homeDirectory = "/home/uvu1"` または `/Users/uvu1`、`home.stateVersion`、`system.stateVersion`、`system.primaryUser = "uvu1"` を明示する。
- 検証用に `checks.<system>` で Home Manager activationPackage と nix-darwin system を公開するか、各環境で明示的に `nix build` する。

### Ownership

- Nix が管理するもの: `mise`, `git`, `zsh`, `sheldon`、Nix/darwin/WSL のネイティブ依存、macOS defaults、WSL bootstrap 用ファイル。
- mise が管理するもの: 現行 `[tools]` の開発 CLI と言語ランタイム。`starship`, `delta`, `fzf`, `ghq` など現行 mise tools にあるものは mise 側に残し、Nix では重複導入しない。
- mise dotfiles が管理するもの: `.gitconfig`, `.zshrc`, `.config/nvim`, `.config/mise/config.toml`, `.config/sheldon`, `.config/zsh`, `.config/starship.toml`, `.config/wezterm`, Windows PowerShell profile 候補。
- Windows では `.config/mise/config.toml` を初期適用対象に含める。既存 global mise 設定を削除した後、Windows subset の global config を先に配置してから `mise install` を実行する。
- Home Manager では `programs.git`, `programs.zsh`, `programs.starship` などの設定ファイル生成を使わない。必要な場合も package 導入に限定し、dotfiles の出力先と競合させない。

### macOS / nix-darwin

- macOS は nix-darwin を導入し、Home Manager を nix-darwin module として統合する。
- 初回は Nix と repo clone 後、`sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#uvu1-mac` 形式で導入する。flake input を release branch に固定する場合は、実行側の nix-darwin ref も同じ系列に合わせる。
- 二回目以降は `sudo darwin-rebuild switch --flake .#uvu1-mac` を使う。
- `system.defaults.finder.AppleShowAllFiles = true` を設定し、Finder の隠しファイル表示を有効化する。
- macOS defaults は nix-darwin に限定し、mise dotfiles では触らない。
- Git signing は `/Applications/1Password.app/Contents/MacOS/op-ssh-sign` を使う。
- WezTerm は macOS に適用し、default shell は `/bin/zsh -l` を維持する。

### WSL Arch

- `wsl --list --online` に `ArchLinux` がある場合のみ公式 WSL distro として構築する。公式一覧に無い場合は中断し、ArchWSL/rootfs import には進まない。
- `/etc/wsl.conf` は Home Manager/mise dotfiles では管理できないため、repo 内テンプレートを `sudo install -m 0644` する専用 bootstrap 手順で適用する。
- `wsl.conf` 適用後は Windows 側で `wsl.exe --shutdown` を実行し、再起動後に `systemctl is-system-running` または `systemctl status` で systemd を確認する。
- 初回は Nix と repo clone 後、`nix run home-manager -- switch --flake .#uvu1@arch-wsl` 形式で導入する。二回目以降は `home-manager switch --flake .#uvu1@arch-wsl` を使う。
- Git signing は `/mnt/c/Users/uvu1/AppData/Local/Microsoft/WindowsApps/op-ssh-sign-wsl.exe` を使う。
- WezTerm config は WSL 内には適用しない。現行 chezmoi の WSL ignore 方針を維持する。

### mise dotfiles

- chezmoi の `dot_*`, `readonly_*`, `.tmpl`, `.chezmoiignore.tmpl` を廃止し、通常の repo 配置へ整理する。
- mise 設定は `mise/mise.toml` をベースにし、環境差分は `mise/mise.darwin.toml`, `mise/mise.linux.toml`, `mise/mise.windows.toml`, `mise/mise.windows-powershell.toml` に分ける。
- `mise/mise.toml` には全 OS 共通の最小 tools だけを置く。macOS/WSL は環境差分で現行 `[tools]` 全キーを有効化し、Windows は `wezterm / git / nvim` 補助に必要な subset だけを有効化する。
- OS 選択は `--config` ではなく mise の global flags を使う。例: `mise -C mise -E darwin dotfiles apply --dry-run`、`mise -C mise -E linux dotfiles status --missing`。
- `dotfiles.default_mode = "symlink"` を基本にし、Windows の `.gitconfig` や template 生成が必要なファイルは対象ごとに `copy` または `template` を指定する。
- `nvim`, `zsh`, `sheldon`, `starship`, `mise`, `git` は macOS/WSL 共通体験として管理する。`wezterm` は macOS/Windows に適用し、WSL には適用しない。

### Migration / cutover

- chezmoi へ戻す工程は設けない。切替時は既存の chezmoi 適用済み設定を削除してから mise dotfiles を force なしで適用する。
- macOS の削除対象は `~/.config/nvim`, `~/.config/mise`, `~/.config/sheldon`, `~/.config/zsh`, `~/.config/starship.toml`, `~/.config/wezterm`, `~/.zshrc`, `~/.gitconfig`。
- WSL Arch の削除対象は `~/.config/nvim`, `~/.config/mise`, `~/.config/sheldon`, `~/.config/zsh`, `~/.config/starship.toml`, `~/.zshrc`, `~/.gitconfig`。WSL では WezTerm を適用しないため `~/.config/wezterm` は対象外。
- Windows の削除対象は `%USERPROFILE%\.config\nvim`, `%USERPROFILE%\.config\wezterm`, `%USERPROFILE%\.config\mise`, `%USERPROFILE%\.config\starship.toml`, `%USERPROFILE%\.gitconfig`, `%USERPROFILE%\Documents\PowerShell`。PowerShell profile を初期適用しない場合でも、古い chezmoi 由来 profile は削除する。
- 削除前に `mise -C mise -E <env> dotfiles apply --dry-run --force --verbose` で、既存ファイルを上書きせずに mise が作成する対象を確認し、対象外のファイルを削除しない。
- 既存設定を削除後、`mise -C mise -E <env> dotfiles apply --dry-run --verbose` が衝突なしになることを確認してから、`mise -C mise -E <env> dotfiles apply --yes` を実行する。
- 二回目 apply 後に `mise -C mise -E <env> dotfiles status --missing` と通常 status を確認し、追加差分が出ないことを受入条件にする。
- mise は状態 DB を持たず、設定から削除したファイルも自動削除しない前提で、削除対象は移行メモに明示して手動削除する。

### Git / Editor / Terminal

- Git 共通値は user name/email/signing key、SSH signing、`commit.gpgsign = true`、`init.defaultBranch = main`、`ghq.root = ~/repo` を維持する。
- `.gitconfig` は mise template で OS 別 signer/sshCommand を生成する。
- Nvim は macOS/WSL/Windows で同一設定を共有し、OS 固有 CLI 依存だけ executable check で保護する。
- WezTerm の hardcoded path は `os.getenv("HOME")` / `os.getenv("USERPROFILE")` から解決する形へ変える。

## Bootstrap Plan

### macOS 初回

- Nix をインストールし、repo を clone する。
- 新規 macOS では repo clone の前提として Command Line Tools の `git` を使う。未導入なら `xcode-select --install` を実行するか、Nix 導入後に `nix shell nixpkgs#git -c git clone <repo-url>` で clone する。
- コミット済みの `flake.lock` をそのまま使い、bootstrap 先では lock を再生成しない。
- `sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#uvu1-mac` で nix-darwin + Home Manager を初回適用する。
- repo の mise 設定内容を確認してから `mise -C mise trust -a` を実行する。
- `mise -C mise -E darwin install` で `[tools]` をインストールし、`mise -C mise -E darwin ls --current` で有効バージョンを確認する。
- `mise -C mise -E darwin dotfiles apply --dry-run --force --verbose` で対象確認後、既存 chezmoi 設定を削除して force なしで apply する。

### WSL Arch 初回

- `wsl --install -d ArchLinux` 後、root 初期セッションで `useradd -m -G wheel -s /bin/bash uvu1` を実行し、`passwd uvu1` で sudo 用パスワードを設定する。
- root 初期セッションで `pacman -Syu --needed sudo git curl ca-certificates` を実行し、clone と Nix インストールに必要な最小依存を導入する。
- `sudo` の `%wheel ALL=(ALL:ALL) ALL` を有効化する。
- repo は `uvu1` 所有の作業ディレクトリへ clone し、root 所有で残さない。
- repo 内の `wsl.conf` を `sudo install -m 0644 <repo>/bootstrap/wsl/wsl.conf /etc/wsl.conf` で適用する。`wsl.conf` には `systemd=true` と `[user] default=uvu1` を含める。
- Windows 側で `wsl -l -v` の distro 名を確認し、`wsl --manage <distro-name> --set-default-user uvu1` が利用できる環境では `wsl.conf` に加えて既定ユーザーも明示設定する。
- Windows 側で `wsl.exe --shutdown` し、WSL 再起動後に systemd を確認する。
- Nix をインストールし、`nix run home-manager -- switch --flake .#uvu1@arch-wsl` で初回適用する。
- Home Manager による zsh 導入後、安定した zsh パスを `/etc/shells` に追加して `chsh -s <zsh-path> uvu1` を実行し、`getent passwd uvu1` で login shell を確認する。
- repo の mise 設定内容を確認してから `mise -C mise trust -a` を実行する。
- `mise -C mise -E linux install` で `[tools]` をインストールし、`mise -C mise -E linux ls --current` で有効バージョンを確認する。
- `mise -C mise -E linux dotfiles apply --dry-run --force --verbose` で対象確認後、既存 chezmoi 設定を削除して force なしで apply する。

### Windows 補助

- Windows 側に mise を導入し、repo を参照できる状態にする。
- repo の mise 設定内容を確認してから `mise -C mise trust -a` を実行する。
- 旧 global mise 設定とのマージを避けるため、`$HOME/.config/mise` を削除した後、`mise -C mise -E windows dotfiles apply --dry-run --verbose $HOME/.config/mise/config.toml` で対象を確認し、`mise -C mise -E windows dotfiles apply --yes $HOME/.config/mise/config.toml` で Windows subset の global config を先に配置する。
- `mise -C mise -E windows install` で Windows subset の `[tools]` をインストールし、`mise -C mise -E windows ls --current` で有効バージョンを確認する。
- `mise -C mise -E windows dotfiles apply --dry-run --verbose` で `mise global config / wezterm / nvim / .gitconfig` のみが対象になることを確認して apply する。
- PowerShell profile を有効化する場合のみ `mise -C mise -E windows-powershell dotfiles apply --dry-run --verbose` で確認し、`mise -C mise -E windows-powershell dotfiles apply --yes` で適用し、`mise -C mise -E windows-powershell dotfiles status --missing` を確認する。

## Test Plan

### Nix / Home Manager

- `nix build .#darwinConfigurations.uvu1-mac.system` を macOS で実行する。
- `nix build .#homeConfigurations."uvu1@arch-wsl".activationPackage` を WSL Arch で実行する。
- `checks.<system>` を定義した場合は `nix flake check` でも上記が検証されることを確認する。

### mise / dotfiles

- 各環境で repo の mise 設定内容を確認後、`mise -C mise trust -a` が完了していることを確認する。
- `mise -C mise -E darwin install` と `mise -C mise -E linux install` を実行し、`mise -C mise -E <env> ls --current` に現行 `[tools]` 全キーの有効バージョンが表示されることを確認する。
- `mise -C mise -E windows install` を実行し、`mise -C mise -E windows ls --current` が Windows subset の tools だけを表示することを確認する。
- Windows では `$HOME/.config/mise/config.toml` が新しい Windows subset 用 global config に置き換わってから `mise install` されることを確認する。
- `mise -C mise -E darwin dotfiles status --missing`、`mise -C mise -E linux dotfiles status --missing`、`mise -C mise -E windows dotfiles status --missing` を各環境で確認する。
- 現行 `dot_config/mise/config.toml` の `[tools]` 全キーが darwin/linux の mise config 合成結果に残り、windows の mise config 合成結果には補助対象 subset だけが残ることを確認する。
- 各環境で二回目の `mise -C mise -E <env> dotfiles apply --dry-run --verbose` が差分ゼロになることを確認する。

### Runtime

- macOS で `defaults read com.apple.finder AppleShowAllFiles` が `1` または `true` を返すこと。
- macOS/WSL で `zsh -lic 'mise --version; starship --version; nvim --version; git config user.name'` が成功すること。
- macOS/WSL で Git SSH signing が OS 別 1Password signer 経由で動くこと。
- Windows 補助で WezTerm/Nvim/Git signing が動くこと。

## Assumptions

- macOS は Apple Silicon の `aarch64-darwin` を既定にする。Intel Mac の場合は実装時に `x86_64-darwin` へ差し替える。
- ユーザー名は macOS/WSL/Windows すべて `uvu1` を既定にする。
- Home Manager は mise dotfiles 対象のユーザー設定ファイルを生成せず、dotfiles の出力先と競合させない。macOS defaults や system 設定は nix-darwin が管理する。
- macOS defaults は nix-darwin に集約し、mise dotfiles では触らない。
- Windows は主環境ではなく補助対象。PowerShell profile は将来共有可能な構造だけ用意し、初期適用とは分ける。
