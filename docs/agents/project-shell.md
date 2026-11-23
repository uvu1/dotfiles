# プロジェクト限定のシェル設定

- Kubernetes / Vault の UI は `mise/dotfiles/.config/zsh/optional/infra.zsh` を正本とし、Sheldon から常時読み込まない。
- infra の `mise.toml` にある zsh `enter` / `leave` hook が `source ~/.config/zsh/optional/infra.zsh enter|leave` を実行する。単なる子プロセスの hook では alias・補完・キーバインドを変更できないため、`shell = "zsh"` と `script` を使う。
- 入場時に `k` alias、emacs / viins の Ctrl-K、kubectl / k / Vault の補完、`STARSHIP_CONFIG` を保存し、退出時に復元する。入場・退出の重複呼び出しでも元の状態を失わないこと。
- プロンプトは共通 `starship.toml` からキャッシュへ派生させ、Kubernetes 表示だけを追加する。共通設定をコピーして別管理しない。元の `STARSHIP_CONFIG` は退出時に戻す。
- kubectl と Vault は infra のプロジェクト toolset が供給する。ここではインストール、認証、通信、context の変更を自動実行しない。Ctrl-K で context を選択した場合のみ `kubectl config use-context` を実行する。
- `python3 scripts/test_project_shell.py` を実行する。実際の認証・kubeconfig・キャッシュに触れず、隔離した HOME と偽の CLI で入退場を検証する。
