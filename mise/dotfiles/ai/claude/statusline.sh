#!/bin/sh
# Claude Code の statusLine。starship プロンプト (dotfiles/.config/starship.toml) の
# 見た目をそのまま踏襲し、シェルには出せない情報 (モデル / コンテキスト残量 /
# 5h 上限) を区切りの右側に並べる。
#
# stdin の JSON は Claude Code 2.1.316 の statusLine ペイロード。
#   https://code.claude.com/docs/en/statusline
# rate_limits は claude.ai の Pro / Max / Ultra でのみ、かつセッション最初の API
# 応答以降にしか現れない。context_window の割合もセッション開始直後は null に
# なりうる。どちらも欠けたらその区画ごと省く。
set -u

esc=$(printf '\033')
reset="${esc}[0m"
dim="${esc}[2m"

# starship [os.symbols] と同じグリフ (Macos = U+F179 / Arch = U+F08C7)。
case "$(uname -s)" in
  Darwin) os=$(printf '\357\205\271') ;;
  *) os=$(printf '\363\260\243\207') ;;
esac

# 使用率が高いほど悪い指標の色。$1=値 $2=警告 $3=危険。
severity() {
  if [ "$1" -ge "$3" ]; then
    printf '31'
  elif [ "$1" -ge "$2" ]; then
    printf '33'
  else
    printf '32'
  fi
}

# $HOME 配下を starship [directory] と同じく ~ に畳む。
tilde() {
  case "$1" in
    "$HOME") printf '~' ;;
    "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;;
    *) printf '%s' "$1" ;;
  esac
}

# 欠損値は空文字で返すため、行数は常に一定で位置がずれない。
fields=$(jq -r '
  def pct: if . == null then "" else (. | round) end;
  [ .model.display_name // ""
  , .workspace.current_dir // .cwd // ""
  , (.context_window.remaining_percentage | pct)
  , (.rate_limits.five_hour.used_percentage | pct)
  , (if .rate_limits.five_hour.resets_at == null then ""
     else (.rate_limits.five_hour.resets_at | localtime | strftime("%H:%M")) end)
  ] | .[]')

{
  read -r model
  read -r dir
  read -r ctx_left
  read -r five_used
  read -r five_at
} <<EOF
$fields
EOF

# --- starship 由来の左側 ---------------------------------------------------
printf '%s[1;32m%s%s in %s[34m%s%s as %s[1;37m%s%s' \
  "$esc" "$os" "$reset" \
  "$esc" "$(tilde "$dir")" "$reset" \
  "$esc" "${USER:-$(whoami)}" "$reset"

git_c() { git -C "$dir" --no-optional-locks "$@" 2>/dev/null; }
branch=$(git_c symbolic-ref --short -q HEAD || git_c rev-parse --short HEAD)
if [ -n "$branch" ]; then
  state=''
  [ -n "$(git_c status --porcelain | head -1)" ] && state='!'
  counts=$(git_c rev-list --left-right --count '@{u}...HEAD')
  if [ -n "$counts" ]; then
    # 左が @{u} 側 = behind、右が HEAD 側 = ahead。
    set -- $counts
    [ "$2" != 0 ] && state="${state}⇡$2"
    [ "$1" != 0 ] && state="${state}⇣$1"
  fi
  printf ' on %s[35m%s%s' "$esc" "$branch" "$reset"
  [ -n "$state" ] && printf ' %s[36m%s%s' "$esc" "$state" "$reset"
fi
printf ' at %s' "$(date +%H:%M)"

# --- Claude 固有の右側 -----------------------------------------------------
printf ' %s|%s %s[2;33m%s%s' "$dim" "$reset" "$esc" "$model" "$reset"

if [ -n "$ctx_left" ]; then
  printf ' %s·%s ctx %s[%sm%s%%%s' \
    "$dim" "$reset" "$esc" "$(severity "$((100 - ctx_left))" 70 85)" "$ctx_left" "$reset"
fi

if [ -n "$five_used" ]; then
  printf ' %s·%s 5h %s[%sm%s%%%s' \
    "$dim" "$reset" "$esc" "$(severity "$five_used" 50 80)" "$five_used" "$reset"
  [ -n "$five_at" ] && printf '%s↻%s%s' "$dim" "$five_at" "$reset"
fi
