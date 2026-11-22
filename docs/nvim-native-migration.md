# Neovim 0.13 の標準機能への移行

現在の操作・表示を優先し、標準機能で用途を満たせる部分から移行する。
プラグインを減らすために同等機能の独自ローダーやインストーラーは作らない。
Neovimは0.13開発版の検証したソースをflake.lockで固定する。

## 今回移行するもの

| 以前 | 移行先 |
| --- | --- |
| RemoteDev、remote.nvim、remote-sshfs.nvim | 標準 `:connect ssh://…` |
| 独自SSH認証・トンネル・再接続・UI接続 | Neovim標準のSSH・サーバー選択 |
| Python workerと成果物manifestによる配置 | 標準Neovim配置・設定コピー、SSH先のmise |
| SSHFS専用検索分岐 | 接続先で通常のSnacks検索を実行 |

`gcc` / `gc`、LSP起動、snippet展開は以前からそれぞれ標準のコメント操作、
`vim.lsp.config` / `enable`、`vim.snippet`を使っている。

## 現在の体験を維持するため残すもの

| プラグイン | 標準との差 |
| --- | --- |
| Lazy | vim.packには現在のevent/keys/cmd/opts/buildのspec処理がない |
| blink.cmp / friendly-snippets | 補完source統合、typo許容、frecency、括弧補完、snippet集 |
| nvim-ufo / promise-async | 標準foldexprとzR/zMにはzpのfold previewがない |
| tiny-inline-diagnostic | 標準virtual_linesとは装飾・配置が異なる |
| Snacks explorer | 標準dirは読み取り専用の一覧。tree、Git/診断、追従、trashとは非同等 |
| nvim-treesitter | 標準の解析器に加え、追加言語のparserとqueryを供給する |
| treesitter-textobjects | 標準an/inは現在のaf/if/ac/ic/aa/iaとlookaheadとは非同等 |
| ts-comments | 標準gcに対しJSX/TSXのnode別commentstring等を補う |
| nvim-lspconfig | 標準APIが使うサーバーのcmd/filetypes/root定義を供給する |
| conform / nvim-lint | 外部formatter・linterの選択、連続実行、診断解析は標準LSP表示と別の役割 |
| diffview | 標準difftoolはGit履歴・merge UIの直接代替ではない |

補完はRust必須を外し、Luaフォールバックを許可する。blinkをLSP開始前にロードし、
最初の接続にもcapabilitiesが反映されるようにする。

## 一次情報

- [固定した0.13の変更点](https://github.com/neovim/neovim/blob/6184b150f409f317f363e215a90343ecd61585c5/runtime/doc/news.txt)
- [標準プラグイン管理](https://neovim.io/doc/user/pack/)
- [標準補完](https://neovim.io/doc/user/lsp/#lsp-completion)
- [標準parserと追加parserの供給](https://neovim.io/doc/user/treesitter/#treesitter-parsers)
- [標準dir](https://neovim.io/doc/user/plugins/#dir)
- [ts-commentsの追加機能](https://github.com/folke/ts-comments.nvim)
