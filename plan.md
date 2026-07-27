# dotflow: apply 後の検証で environment targets を無視するバグの修正計画

## 目的

`dotflow apply` が、設定された dotfile の適用には成功しているにもかかわらず、適用後の検証で対象外の dotfile を drift と判定して終了コード 1 になる問題を修正する。

修正後は、各 environment に設定された `targets`、または CLI で明示された targets と同じ範囲だけを適用後に検証する。選択対象内の実際の drift は引き続きエラーにする。

## 再現条件

1つの profile が複数の mise environment を持ち、それぞれが異なる targets を担当している構成で再現する。

```toml
[profiles.windows]
platform = "windows"

[[profiles.windows.environments]]
mise_environment = "windows"
targets = ["~/.config/nvim", "~/.gitconfig", "~/.config/wezterm"]

[[profiles.windows.environments]]
mise_environment = "windows-powershell"
targets = ["~/.config/mise/config.toml", "~/.config/starship.toml", "~/Documents/PowerShell"]
```

mise の環境設定は base config と environment config をマージする。そのため、ある environment が継承しているものの担当 targets には含まれない dotfile が、別 environment によって異なる mode または source で管理されている場合がある。

確認例:

```text
mise -C mise -E windows dotfiles status --missing
  ~/.config/mise/config.toml  differs (content differs)

mise -C mise -E windows-powershell dotfiles status --missing
  ~/.config/nvim  differs (exists but is not a symlink)
```

一方、environment の targets を明示した `mise dotfiles apply --dry-run` は成功する。

## 原因

`src/main.rs` の `apply()` は、適用時には次のルールで `selected` を決めている。

- CLI targets が空なら `Environment.targets`
- CLI targets が指定されていれば CLI targets

その `selected` は `mise dotfiles apply --yes ...` には渡されている。

しかし適用後の2回目のループでは、次のコマンドを targets なしで実行している。

```rust
mise_inherit(r, repo, cfg, e, &["dotfiles", "status", "--missing"])?;
mise_inherit(r, repo, cfg, e, &["dotfiles", "status"])?;
```

これにより、適用対象外の継承 dotfile まで検証される。`mise dotfiles status --missing` がその drift を検出して終了コード 1 を返すため、`dotflow apply` 全体が失敗する。

## 実装方針

### 1. 適用と検証で同じ target 選択ロジックを使う

`apply()` 内で environment ごとの `selected` を決め、次のすべての mise 呼び出しに同じ targets を渡す。

```text
mise dotfiles apply --yes <selected...>
mise dotfiles status --missing <selected...>
mise dotfiles status <selected...>
```

実装の重複を避けるため、CLI targets と `Environment.targets` から有効な targets を返す小さな helper を導入するか、適用と検証を同じ environment loop 内で行う。

### 2. targets が空の場合の既存動作を維持する

CLI targets と `Environment.targets` の両方が空の場合は、引数を追加せず environment の全 dotfile を適用・検証する。これは `[common]` や targets を限定していない既存 profile の動作を変えないために必要。

### 3. status 出力の重複を確認する

現在は `status --missing` の後に通常の `status` も実行している。両方が同じ一覧を出力するなら通常の `status` は冗長なので、以下のどちらかを明示的に選ぶ。

- 最小変更: 両コマンドを維持し、両方に同じ targets を渡す。
- 整理する場合: `status --missing` だけで必要な出力と終了判定を満たすことをテストで確認してから、通常の `status` を削除する。

このバグ修正では、挙動変更を抑えるため最小変更を優先する。

## テスト計画

### 回帰テスト

複数 environment と異なる targets を持つ profile を用意し、dry-run の `Runner.intended` に記録される mise 呼び出しを検証する。

期待する呼び出し:

```text
-E windows dotfiles apply --yes ~/.config/nvim
-E windows dotfiles status --missing ~/.config/nvim
-E windows dotfiles status ~/.config/nvim

-E windows-powershell dotfiles apply --yes ~/.config/mise/config.toml
-E windows-powershell dotfiles status --missing ~/.config/mise/config.toml
-E windows-powershell dotfiles status ~/.config/mise/config.toml
```

特に、`status` または `status --missing` が targets なしで記録されていないことを確認する。

### CLI targets のテスト

`dotflow apply <target>` の明示 target が `Environment.targets` を上書きし、適用と検証の両方に同じ CLI target が渡されることを確認する。

### 空 targets のテスト

CLI targets と `Environment.targets` が両方空の場合は、従来どおり targets なしで全体の apply/status が呼ばれることを確認する。

### drift 判定のテスト

可能なら fake mise または一時ディレクトリを使った CLI テストを追加し、次を確認する。

- 選択対象外に drift があっても `dotflow apply` は成功する。
- 選択対象内に drift が残れば `dotflow apply` は失敗する。

## 検証コマンド

```sh
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-features
```

CI の Linux、macOS、Windows の全 matrix で成功することを確認する。

## 完了条件

- environment targets を持つ複数 environment profile で `dotflow apply` が誤って失敗しない。
- apply と post-apply status が同じ targets を使用する。
- CLI targets の既存の上書き動作を維持する。
- targets が空の profile では従来どおり全 dotfile を対象にする。
- 選択対象内の未適用・差分は引き続き非ゼロ終了になる。
- 回帰テストと既存テストが全対応OSで成功する。

## 対象外

- mise の environment merge semantics の変更
- dotfiles repository 側の environment 分割や dotfile 定義の再配置
- `dotflow status` 全体の表示仕様の再設計
