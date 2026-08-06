# wezterm の mux 接続(unix domain)では ClientPane が foreground process を報告せず、
# mux の codec も working_dir しか運ばない。そのため tabbar.lua はタブ名を組み立てられない。
# mux を越えて伝搬する user_vars に、実行中のコマンドラインとシェル種別を流す。
# 変数名とエスケープシーケンスは wezterm 公式の shell integration に合わせてあるので、
# 将来 wezterm.sh を導入しても衝突しない。

# wezterm 以外の端末でも動くが、未知の OSC は無視されるだけで害はない。WEZTERM_PANE は
# wsl.exe 越しに伝搬しないため、ここで端末を判定してゲートすると WSL のタブだけ
# タイトルが死ぬ。判定せずに常に出す。
__wezterm_set_user_var() {
  (( $+commands[base64] )) || return 0

  # GNU coreutils の base64 は 76 桁で折り返す。改行が混ざると OSC が壊れるので潰す。
  local encoded
  encoded=$(print -rn -- "$2" | base64)
  encoded=${encoded//[[:space:]]/}

  printf '\033]1337;SetUserVar=%s=%s\007' "$1" "$encoded"
}

# シェル自身の名前。コマンドを実行していないタブはこれで表示される。
# Windows の既定ペインは WSL だが、macOS の zsh と区別したいので wsl と名乗らせる。
if [[ -n ${WSL_DISTRO_NAME:-} ]]; then
  __wezterm_set_user_var WEZTERM_SHELL wsl
else
  __wezterm_set_user_var WEZTERM_SHELL zsh
fi

# pane を分割したときに cwd を引き継ぐには wezterm 側が cwd を知っている必要がある。
# WSL ペインの実体は mux server (Windows プロセス) が spawn した wsl.exe なので、
# wezterm のプロセス走査では Windows 側の cwd しか取れない。OSC 7 で Linux のパスを
# 直接教える。ただし Windows の wezterm はそのパスへ chdir できないため、実際の
# 引き継ぎは keybinds.lua の spawn_in_current_cwd が wsl.exe --cd で行う。対で扱うこと。
# UNC パス (wslpath -m) を載せる案は wezterm が URL の host を捨てるため使えない。
__wezterm_osc7() {
  # zsh の path は PATH に tie された特殊パラメータなので local 名に使わない。
  # LC_ALL=C でバイト単位に落とし、マルチバイトも UTF-8 のまま percent-encode する。
  local LC_ALL=C
  local dir=$PWD encoded= i c

  for (( i = 1; i <= $#dir; i++ )); do
    c=$dir[i]

    if [[ $c == [A-Za-z0-9/._~-] ]]; then
      encoded+=$c
    else
      printf -v c '%%%02X' "'$c"
      encoded+=$c
    fi
  done

  printf '\033]7;file://%s%s\033\\' "$HOST" "$encoded"
}

# precmd はプロンプトのたびに走る。既に空を送っていれば base64 を fork しない。
typeset -g __wezterm_prog_cleared=1

__wezterm_preexec() {
  __wezterm_set_user_var WEZTERM_PROG "$1"
  __wezterm_prog_cleared=0
}

__wezterm_precmd() {
  __wezterm_osc7

  (( __wezterm_prog_cleared )) && return 0

  __wezterm_set_user_var WEZTERM_PROG ""
  __wezterm_prog_cleared=1
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec __wezterm_preexec
add-zsh-hook precmd __wezterm_precmd
