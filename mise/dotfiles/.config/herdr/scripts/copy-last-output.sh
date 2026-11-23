#!/usr/bin/env bash
# 直前のコマンドの出力をクリップボードへコピーする（herdr の [[keys.command]] prefix+c）。
#
# starship のプロンプトが「空行 / 情報行 / ❯ 行」で固定なことを利用して範囲を割り出す。
# 記号と行の形の出所は starship.toml の format / add_newline / [character] なので、
# そちらを変えるときはこのスクリプトも揃えること。
#
#   copy-last-output.sh          herdr から現在のペインを読んでコピーする
#   copy-last-output.sh --stdin  標準入力の画面テキストから出力部分だけを標準出力へ出す（検証用）
set -euo pipefail

readonly PROMPT_SYMBOL="❯"
# プロンプトを探して遡る上限。scrollback 全体を毎回読むと重いので頭打ちにする。
readonly MAX_LOOKBACK_ROWS=2000

# 画面テキスト（折り返しを論理行に戻したもの）を受け取り、直前の出力を返す。
# 末尾の現在のプロンプト（❯ 行）から、add_newline の空行まで遡ってプロンプトブロックを
# 飛ばし、その手前から 1 つ前の ❯ 行（= 入力行）の直後までを出力とみなす。
extract_last_output() {
  awk -v prompt="$PROMPT_SYMBOL" '
    { lines[NR] = $0 }
    END {
      n = NR
      # 画面下端の未使用行を落とす。
      while (n > 0 && lines[n] ~ /^[[:space:]]*$/) n--
      if (n == 0 || index(lines[n], prompt) != 1) {
        print "プロンプト行にいないため範囲を判定できません" > "/dev/stderr"; exit 2
      }
      # 情報行は折り返すことがあるので行数を決め打ちせず、空行に当たるまで戻る。
      row = n - 1
      while (row > 0 && lines[row] != "") row--
      if (row <= 0) { print "プロンプトの区切りが見つかりません" > "/dev/stderr"; exit 2 }
      last = row - 1
      row = last
      while (row > 0 && index(lines[row], prompt) != 1) row--
      if (row <= 0) { print "直前のプロンプトが見つかりません" > "/dev/stderr"; exit 2 }
      body = ""
      for (i = row + 1; i <= last; i++) body = body (i > row + 1 ? "\n" : "") lines[i]
      if (body ~ /^[[:space:]]*$/) { print "直前のコマンドに出力がありません" > "/dev/stderr"; exit 2 }
      # 末尾に改行を足さない。シェルへ貼り付けたときに即実行されてしまう。
      printf "%s", body
    }
  '
}

copy_to_clipboard() {
  local cmd
  for cmd in pbcopy clip.exe wl-copy; do
    if command -v "$cmd" >/dev/null 2>&1; then
      "$cmd"
      return
    fi
  done
  echo "クリップボードへ書き込むコマンドが見つかりません" >&2
  return 1
}

if [[ ${1:-} == --stdin ]]; then
  extract_last_output
  exit
fi

herdr=${HERDR_BIN_PATH:-herdr}
pane=${HERDR_ACTIVE_PANE_ID:?herdr の custom command から実行してください}

# 範囲を割り出せたときだけクリップボードへ書く。パイプで直結すると失敗時に空文字で
# クリップボードを潰してしまう。成功時は無言、失敗したときだけ通知する。
notify() {
  "$herdr" notification show "herdr" --body "$1" >/dev/null
}

if ! output=$(
  "$herdr" pane read "$pane" --source recent-unwrapped --lines "$MAX_LOOKBACK_ROWS" |
    extract_last_output 2>&1
); then
  notify "$output"
  exit 1
fi

if ! message=$(printf '%s' "$output" | copy_to_clipboard 2>&1); then
  notify "$message"
  exit 1
fi
