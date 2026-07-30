# nvim ツール供給元の移行メモ（2026-07-31）

別環境で nvim のプラグイン構成を改修している人向けの引き継ぎ。**この日、LSP / リンタ /
フォーマッタの供給元が mise から nix に変わった。** nvim 設定が依存している契約のうち何が
変わり何が変わっていないかをここにまとめる。詳しい症状と切り分け手順は
`docs/nvim-lsp-audit.md` の「LSP が起動しないときの調査手順」と「既知の罠」にある。

## なぜ変えたか

1. **mise の npm backend がインタプリタを固定できなかった。** `#!/usr/bin/env node` のままなので、
   グローバルに入れた LSP が「たまたまその時 PATH にいた node」で動く。
   `typescript-language-server 5.3.0` は `engines.node >= 20` を宣言するが、
   プロジェクトが node 18 を pin していると違反した状態で起動し、node 20+ 固有の API を
   踏んだ時だけ落ちる。「特定プロジェクトでだけ TS 補完がときどき効かない」という形で出る。
2. **`latest` 指定 26 件が再現性の穴だった。** macOS と WSL で版が揃わない。

nixpkgs は npm 製パッケージの shebang を絶対 node パスに書き換える。これが nix を使う理由。

## 供給元の対応表

| 層 | 何を持つか | 版の固定 |
|---|---|---|
| **nix profile**<br>`/etc/profiles/per-user/uvu1/bin` | LSP 15 本、リンタ、フォーマッタ、日常 CLI、フォールバックの言語ランタイム | `flake.lock` |
| **mise（グローバル）**<br>`~/.config/mise/config.toml` | `dotflow` と vendor CLI 3 件（`claude` / `cloudflared` / `aqua:openai/codex`）だけ | `latest`（意図的） |
| **mise（プロジェクト）**<br>各プロジェクトの設定 | そのプロジェクトの言語ランタイムと、gem 製ツール | プロジェクトが宣言 |

mise の役目は **プロジェクト単位のバージョン切り替えだけ**になった。`mise activate` は
shims ではなく **hook-env モード**（`mise activate zsh`）。

## nvim 設定に効く変更 3 つ

### 1. `lib/mise.lua` の `base_path()` が必須になった

hook-env モードでは、nvim が継承する PATH に「nvim を起動したディレクトリ」の installs が
既に前置されている。その PATH のまま `mise x -C <root>` を呼ぶと mise は前置済みの分を
解決対象から外し、対象 root のツールを再付与しない。結果、**プロジェクトの処理系が
LSP に渡らない**。

```
継承した PATH のまま   → /etc/profiles/per-user/uvu1/bin/python3   （nix のフォールバック）
PATH=__MISE_ORIG_PATH  → installs/python/3.13/bin/python3          （プロジェクト版）
```

`base_path()` が `__MISE_ORIG_PATH`（mise が activate 前の PATH を保存している変数）を
子プロセスの PATH の土台にして、mise に一から解決させる。`lsp_cmd` と `M.linter` の両方に効く。

**この関数を消すと basedpyright が `Import "x" could not be resolved` を出して補完候補 0 件になる。**
サーバ自体は正常に起動するので `:LspLog` に起動エラーが残らず、原因が見えにくい。
`mise x -- basedpyright file.py`（CLI）だと解決できるのに LSP だと解決できない、
という食い違いが出たらこれ。

### 2. `mise x -C` でラップするのは 4 本だけ

`rust_analyzer` / `gopls` / `ruby_lsp` / `basedpyright`。基準は「サーバがプロジェクトの
処理系を実行・内省しないと正しい答えを出せないか」。

残り 11 本はラップ**しない**。バージョン依存の実体がリポジトリ内のファイル
（`node_modules/typescript`、`compile_commands.json`、JSON schema、`.eslintrc`）なので
サーバ自身が workspace から解決する。ラップは無益なうえ、プロジェクトが古い node を
pin していると逆に壊れる。

### 3. npm の穴が塞がったのでワークアラウンドは不要

`lua/plugins/lsp.lua` の basedpyright に「npm 製で shebang が node なので
`MISE_DISABLE_TOOLS` で node を外すと落ちる」というコメントがあったが、**もう成り立たない**。
nix 版は shebang が絶対 node パスなので、PATH 上の node に一切依存しない。

確認方法（環境変数ゼロで起動する = 固定されている証拠）:

```sh
env -i "$(command -v typescript-language-server)" --version   # 5.3.0
env -i "$(command -v basedpyright-langserver)" --version
env -i "$(command -v copilot-language-server)" --version      # 1.517.0
```

basedpyright のラップが残っているのは **プロジェクトの python を解析対象として渡すため**だけ。

## 版の差分

プラグイン改修中に「挙動が変わった」と感じたらここを見る。左が移行前（mise）、右が現在（nix）。

### 上がった / 揃った

| ツール | 変化 |
|---|---|
| `clangd` | 22.1.6 → **22.1.8**。`clang-format` と同じ `llvmPackages_22.clang-tools` 由来になり **両者の版が揃った**（以前は 22.1.6 / 22.1.8 でズレていた） |

### 同じ

`typescript-language-server` 5.3.0 / `yaml-language-server` 1.24.0 /
`lua-language-server` 3.18.2 / `gopls` v0.23.0 / `golangci-lint` 2.12.2 /
`stylua` 2.5.2 / `clang-format` 22.1.8 / `nvim` 0.12.4

### 下がった

| ツール | 変化 | 備考 |
|---|---|---|
| `tailwindcss-language-server` | 0.16.0 → **0.14.29** | 差が大きい。nixpkgs が追いついていない |
| `ruby-lsp` | 0.26.10 → **0.26.3** | |
| `rust-analyzer` | 2026-07-27 → **2026-06-15** | |
| `prettier` | 3.9.6 → **3.8.3** | |
| `biome` | 2.5.6 → **2.5.0** | |
| `ruff` | 0.16.0 → **0.15.20** | |
| `yamllint` | 1.38.0 → **1.37.1** | |
| `gofumpt` | 0.11.0 → **0.10.0** | |
| `goimports` | 0.48.0 → **gotools 0.44.0 同梱** | |
| `copilot-language-server` | 1.526.0 → **1.517.0** | |
| `basedpyright` | 1.39.9 → **1.39.8** | |
| `tree-sitter` | 0.26.11 → **0.26.9** | パーサのビルドに使う CLI |
| `rg` | 15.2.0 → **15.1.0** | |
| `fzf` / `lazygit` | 0.74.1 → 0.74.0 / 0.63.1 → 0.63.0 | |

### 供給の形が変わったもの

| ツール | 変化 |
|---|---|
| `vscode-langservers-extracted` | npm 4.10.0 → **VSCodium 1.121.03429**。版の体系が別なのでダウングレードではない。`vscode-{json,css,html,eslint}-language-server` の 4 本が揃い、全て絶対 node パスで wrap され、4 本すべてに LSP initialize を通す `passthru.tests.initialization` が付く |
| `goimports` | `gotools` は `bundle` / `stringer` / `play` / `stress` など汎用名のバイナリを 45 個撒き、`bundle` が ruby のものと衝突して profile が作れない。`nix/home.nix` で `goimports` だけを取り出す派生を作っている |
| `rustfmt` | プロジェクト外では nix の rustfmt 1.9.0（rust 1.96.1）。プロジェクトが mise で rust を宣言していれば rustup の toolchain 版に切り替わる |
| `pipx` | **削除**。`yamllint` を mise で入れるための土台だっただけ |

## 運用の変化

| したいこと | 移行前 | 現在 |
|---|---|---|
| LSP の版を上げる | `config.unix.toml` を編集 → `mise install` | `nix flake update` → `darwin-rebuild switch` / `home-manager switch` |
| LSP を追加する | `config.unix.toml` の `[tools]` | `nix/home.nix` の `devTools` |
| 実体がどこから来ているか | `mise which <tool>` | `command -v <tool>`（`/etc/profiles/...` なら正常） |
| プロジェクトの版を固定する | 変わらず（`mise.toml` / `.node-version` / `Gemfile` / `rust-toolchain.toml`） | 同じ |

`nix flake check --no-build` は評価しかしないので、`buildEnv` のファイル名衝突は検出できない。
パッケージを増やしたら profile をドライビルドして確認する:

```sh
nix build --no-link '.#darwinConfigurations."uvu1-mac".config.home-manager.users.uvu1.home.path'
```

**mise から宣言を消したら必ず shims を再生成する。** 残った shim は PATH 前方で
`No version is set for shim: <tool>` になり nix profile に到達しない（fall-through しない）。

```sh
rm -rf ~/.local/share/mise/shims && mise reshim
```

## 変わっていないもの

- `lua/plugins/conform.lua` は無変更。裸の PATH 解決が nix profile に落ちるだけ
- `lib/mise.lua` の `bundled` 機構（`Gemfile.lock` にあれば `bundle exec` 経由）は健在
- `lib/mise.lua` の FAIL_FAST（`MISE_EXEC_AUTO_INSTALL=0`）と起動 5 秒以内の非 0 終了通知も健在
- `vim.lsp.enable` のリストが有効サーバ集合の唯一の正本、という構造も同じ
- `config/options.lua` の shims append は残してある。ただし hook-env では
  グローバル宣言の 4 件しか解決しないので、実質的な役割はほぼ無い

## nvim 以外で効くこと

- **`blink.cmp` の `implementation = "rust"` の順序依存が消えた。** `cargo build --release` が
  必要だが、`cargo` が nix profile にあるので home-manager の activation が済んでいれば常に使える。
  以前は mise の `rust` 宣言に依存していて、新規マシンでプラグイン同期が `mise install` より
  先に走ると `InsertEnter` ごとに例外が出た（`docs/nvim-completion-audit.md` Finding 4）
- **`haml_lint` は nixpkgs に無い。** グローバルには置かず、プロジェクトの Gemfile が唯一の
  供給元。`nvim-lint.lua` の `gates` が `project.bundles(dir, "haml_lint")` で判定し、
  載っていなければ「そのプロジェクトは haml を lint しない方針」と見なして静かにスキップする
  （`rubocop` と同じ扱い）
- **`copilot-language-server` は unfree。** `nix/home.nix` の `allowUnfreePredicate` が
  このパッケージだけを許可している。`legacyPackages` 経由では評価に失敗するので、
  nix 側を触るときは `import ... { config.allowUnfreePredicate = ...; }` の形を崩さない
