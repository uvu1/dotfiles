#!/usr/bin/env bash
# Takumi Guard (GMO Flatt Security) のレジストリ設定を端末へ適用する。
# 手順の出典は公式ドキュメント https://shisho.dev/docs/ja/t/guard/quickstart/ 。
#
# 生成物 (~/.npmrc, ~/.bundle/config, ~/.netrc, pip.conf, uv.toml) は tg_anon_
# トークンを含むため、リポジトリでは追跡せず端末ローカルに置く。このスクリプトが
# 唯一の供給元で、dotflow update の after_sync から再適用される。
#
# トークンは TAKUMI_GUARD_TOKEN、無ければ 1Password から取る。どちらも取れない
# ときは「未設定の対象だけ匿名で有効化」して終了する。1Password 未サインインの
# 端末で dotflow update を止めず、かつブロック機能だけは必ず効く状態にするため。
set -euo pipefail

op_item='op://Private/Takumi Guard/credential'
npm_registry='https://npm.flatt.tech/'
npm_auth_key='//npm.flatt.tech/:_authToken'
rubygems_mirror_key='mirror.https://rubygems.org'
rubygems_host='rubygems.flatt.tech'
pypi_host='pypi.flatt.tech'
pypi_path='/simple/'
golang_host='golang.flatt.tech'
golang_proxy="https://${golang_host}"
marker='# managed by scripts/sync-takumi-guard.sh'

dry_run=0
changed=0
failed=0

usage() {
  cat <<'USAGE'
Usage: sync-takumi-guard.sh [--dry-run]

Takumi Guard のレジストリ設定を npm / RubyGems / Go / PyPI へ適用する。
--dry-run を付けると何も書き込まず、適用予定だけを表示する。
USAGE
}

case "${1:-}" in
  --dry-run) dry_run=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  '') ;;
  *)
    usage >&2
    exit 2
    ;;
esac
if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi

warn() { printf '%s\n' "$*" >&2; }

skip() { printf 'Skipped %s (command not found)\n' "$1"; }

# zsh の alias (mise/dotfiles/.config/zsh/aliases.zsh) はスクリプトに効かないので、
# WSL では Windows 側の op.exe を同じ規則で自前に解決する。
resolve_op() {
  if command -v op >/dev/null 2>&1; then
    printf 'op'
    return 0
  fi
  if [ -n "${WSL_DISTRO_NAME:-}" ]; then
    local win_op="/mnt/c/Users/${USER}/AppData/Local/Microsoft/WinGet/Links/op.exe"
    if [ -x "$win_op" ]; then
      printf '%s' "$win_op"
      return 0
    fi
  fi
  return 1
}

# 認証付き URL。トークンが無ければ匿名形式になる。
guard_url() { # $1=host $2=path
  if [ -n "$token" ]; then
    printf 'https://token:%s@%s%s' "$token" "$1" "$2"
  else
    printf 'https://%s%s' "$1" "$2"
  fi
}

# コマンドの出力にはトークンが混ざりうるので捨てる。失敗時は対象名だけ報告する。
act() { # $1=説明 $2...=コマンド
  local description="$1"
  shift
  changed=$((changed + 1))
  if [ "$dry_run" -eq 1 ]; then
    printf 'Would set %s\n' "$description"
    return 0
  fi
  if ! "$@" >/dev/null 2>&1; then
    warn "Failed to set ${description}"
    failed=$((failed + 1))
    return 0
  fi
  printf 'Set %s\n' "$description"
}

# マーカー行を先頭に持つファイルだけを所有する。手で書かれたファイルは上書きしない。
write_managed() { # $1=path $2=説明、内容は stdin
  local path="$1" description="$2" content tmp
  content=$(cat)
  if [ -e "$path" ]; then
    if ! head -n 1 "$path" | grep -Fqx "$marker"; then
      warn "Refusing to overwrite unmanaged ${path}; remove it or add the marker line"
      failed=$((failed + 1))
      return 0
    fi
    if [ "$content" = "$(cat "$path")" ]; then
      return 0
    fi
    # トークンを取れなかった回で、既に有効な設定を匿名へ落とさない。
    if [ -z "$token" ] && grep -Fq '.flatt.tech' "$path"; then
      return 0
    fi
  fi
  changed=$((changed + 1))
  if [ "$dry_run" -eq 1 ]; then
    printf 'Would write %s\n' "$description"
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  tmp=$(mktemp "${path}.XXXXXX")
  chmod 600 "$tmp"
  printf '%s\n' "$content" >"$tmp"
  mv "$tmp" "$path"
  printf 'Wrote %s\n' "$description"
}

apply_npm() {
  if ! command -v npm >/dev/null 2>&1; then
    skip npm
    return 0
  fi
  local current desired_auth npmrc="$HOME/.npmrc"
  current=$(npm config get registry 2>/dev/null || printf '')
  if [ "$current" != "$npm_registry" ]; then
    if [ -n "$token" ] || ! printf '%s' "$current" | grep -Fq 'npm.flatt.tech'; then
      act "npm registry to ${npm_registry}" npm config set registry "$npm_registry"
    fi
  fi
  # _authToken は protected で npm config get から読めないため ~/.npmrc を直接見る。
  if [ -n "$token" ]; then
    desired_auth="${npm_auth_key}=${token}"
    if ! { [ -f "$npmrc" ] && grep -Fqx "$desired_auth" "$npmrc"; }; then
      act 'npm auth token in ~/.npmrc' npm config set "$npm_auth_key" "$token"
    fi
  fi
}

apply_bundler() {
  if ! command -v bundle >/dev/null 2>&1; then
    skip bundler
    return 0
  fi
  local desired config="$HOME/.bundle/config"
  desired=$(guard_url "$rubygems_host" '/')
  # bundler 4 の `bundle config get` は --global を受け付けず、cwd 側の
  # .bundle/config も混ざる。グローバル設定ファイルを直接見る。
  if [ -f "$config" ] && grep -Fq "$desired" "$config"; then
    return 0
  fi
  if [ -z "$token" ] && [ -f "$config" ] && grep -Fq "$rubygems_host" "$config"; then
    return 0
  fi
  act "bundler mirror to https://${rubygems_host}/" \
    bundle config set --global "$rubygems_mirror_key" "$desired"
}

# Go のツールチェーンは .netrc の Basic 認証でトークンを送る。1 行形式だけを所有し、
# 他ホストの行は残す。
upsert_netrc() {
  local netrc="$HOME/.netrc" desired tmp
  desired="machine ${golang_host} login token password ${token}"
  if [ -f "$netrc" ] && grep -Fqx "$desired" "$netrc"; then
    return 0
  fi
  changed=$((changed + 1))
  if [ "$dry_run" -eq 1 ]; then
    printf 'Would set ~/.netrc entry for %s\n' "$golang_host"
    return 0
  fi
  tmp=$(mktemp "${netrc}.XXXXXX")
  chmod 600 "$tmp"
  if [ -f "$netrc" ]; then
    grep -v "^machine ${golang_host} " "$netrc" >"$tmp" || true
  fi
  printf '%s\n' "$desired" >>"$tmp"
  mv "$tmp" "$netrc"
  printf 'Set ~/.netrc entry for %s\n' "$golang_host"
}

apply_go() {
  local current
  if command -v go >/dev/null 2>&1; then
    current=$(go env GOPROXY 2>/dev/null || printf '')
    if [ "$current" != "$golang_proxy" ]; then
      # ,direct のフォールバックは付けない。プロキシがエラーを返したときに VCS から
      # 直接取得され、ブロック対象が Guard を迂回しうるため公式が禁じている。
      if [ -n "$token" ] || ! printf '%s' "$current" | grep -Fq "$golang_host"; then
        act "GOPROXY to ${golang_proxy}" go env -w "GOPROXY=${golang_proxy}"
      fi
    fi
  else
    skip go
  fi
  if [ -n "$token" ]; then
    upsert_netrc
  fi
}

# pip のユーザー設定は macOS だけ XDG_DATA_HOME 基準で探索され、
# ~/Library/Application Support/pip があるとそちらが優先される。
pip_config_path() {
  if [ "$(uname -s)" = Darwin ]; then
    if [ -n "${XDG_DATA_HOME:-}" ] && [ -d "${XDG_DATA_HOME}/pip" ]; then
      printf '%s/pip/pip.conf' "$XDG_DATA_HOME"
      return 0
    fi
    if [ -d "${HOME}/Library/Application Support/pip" ]; then
      printf '%s/Library/Application Support/pip/pip.conf' "$HOME"
      return 0
    fi
  fi
  printf '%s/pip/pip.conf' "${XDG_CONFIG_HOME:-${HOME}/.config}"
}

apply_pypi() {
  local index_url
  index_url=$(guard_url "$pypi_host" "$pypi_path")
  write_managed "$(pip_config_path)" 'pip index-url' <<EOF
${marker}
[global]
index-url = ${index_url}
EOF
  # uv は pip の設定も PIP_INDEX_URL も読まない。
  write_managed "${XDG_CONFIG_HOME:-${HOME}/.config}/uv/uv.toml" 'uv default index' <<EOF
${marker}
[[index]]
url = "${index_url}"
default = true
EOF
}

token="${TAKUMI_GUARD_TOKEN:-}"
if [ -n "$token" ]; then
  printf 'Using token from TAKUMI_GUARD_TOKEN\n'
else
  if op_bin=$(resolve_op); then
    token=$("$op_bin" read --no-newline "$op_item" 2>/dev/null) || token=''
  fi
  if [ -n "$token" ]; then
    printf 'Using token from 1Password (%s)\n' "$op_item"
  else
    warn "トークンを取得できませんでした。未設定の対象だけ匿名で有効にします。"
    warn "通知とレート上限の緩和が必要なら ${op_item} にトークンを保存してください。"
  fi
fi

apply_npm
apply_bundler
apply_go
apply_pypi

if [ "$failed" -gt 0 ]; then
  warn "Takumi Guard: ${failed} target(s) failed"
  exit 1
fi
if [ "$changed" -eq 0 ]; then
  printf 'Takumi Guard already configured\n'
elif [ "$dry_run" -eq 1 ]; then
  printf 'Would apply %d change(s)\n' "$changed"
fi
