#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_config="$repo_root/mise/dotfiles/ai/codex/config.toml"
codex_home=${CODEX_HOME:-"$HOME/.codex"}
target_config="$codex_home/config.toml"
begin_marker='# >>> dotfiles:codex-defaults >>> managed by sync-ai-config.sh'
end_marker='# <<< dotfiles:codex-defaults <<<'

if [[ ! -f "$source_config" ]]; then
  echo "missing managed Codex defaults: $source_config" >&2
  exit 1
fi

# 管理ブロックは target の先頭に置き、その後ろに端末ローカルな設定を残す。テーブル
# ヘッダを書くと後続のトップレベルキーがそのテーブルに取り込まれるため、入れ子の値は
# `tui.notification_method = ...` のような dotted key で書く。
if rg -q '^\[' "$source_config"; then
  echo "managed Codex defaults must use dotted keys, not table headers: $source_config" >&2
  exit 1
fi

mkdir -p "$codex_home"
tmp=$(mktemp "${TMPDIR:-/tmp}/codex-config.XXXXXX")
trap 'rm -f "$tmp" "$tmp.body"' EXIT

if [[ -f "$target_config" ]]; then
  # 取り除くキーは source のトップレベルキーそのものを唯一の情報源にする。
  # source にキーを足せば同期が追従し、ここに一覧を複製しない。
  awk -v source="$source_config" -v begin="$begin_marker" -v end="$end_marker" '
    function key_of(line) {
      sub(/[[:space:]]*=.*/, "", line)
      return line
    }
    BEGIN { in_managed = 0; in_top = 1; emitted = 0 }
    FILENAME == source {
      if ($0 ~ /^[A-Za-z0-9_.-]+[[:space:]]*=/) {
        key = key_of($0)
        managed[key] = 1

        if (key ~ /\./) {
          table = key
          sub(/\..*/, "", table)
          managed_table[table] = 1
        }
      }
      next
    }
    $0 == begin { in_managed = 1; next }
    $0 == end { in_managed = 0; next }
    in_managed { next }
    /^\[/ {
      in_top = 0
      table = $0
      sub(/^\[+[[:space:]]*/, "", table)
      sub(/[[:space:]]*\].*/, "", table)
      sub(/\..*/, "", table)

      # dotted key で定義したテーブルを本文が再定義すると TOML が二重定義で壊れる。
      # 黙って壊れた config を書くより、移動を促して止める。
      if (table in managed_table) {
        printf "move [%s] into %s: it collides with the managed dotted keys\n", table, source > "/dev/stderr"
        exit 1
      }
    }
    in_top && key_of($0) in managed { next }
    !emitted && /^[[:space:]]*$/ { next }
    { emitted = 1; print }
  ' "$source_config" "$target_config" >"$tmp.body"
else
  : >"$tmp.body"
fi

umask 077
{
  printf '%s\n' "$begin_marker"
  awk 'NF { print }' "$source_config"
  printf '%s\n' "$end_marker"
  if [[ -s "$tmp.body" ]]; then
    printf '\n'
    awk '
      NF {
        while (blanks > 0) { print ""; blanks-- }
        print
        next
      }
      { blanks++ }
    ' "$tmp.body"
  fi
} >"$tmp"

# cmp は diffutils で、WSL(Arch) には入っていない。存在しない場合 127 が
# 「差分あり」と区別できず毎回書き換えになるため、bash 内の比較で済ませる。
if [[ -f "$target_config" ]] && [[ "$(<"$tmp")" == "$(<"$target_config")" ]]; then
  echo "Codex defaults already synchronized"
  exit 0
fi

mv "$tmp" "$target_config"
trap 'rm -f "$tmp.body"' EXIT
echo "Synchronized managed Codex defaults into $target_config"
