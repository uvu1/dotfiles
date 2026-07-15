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

mkdir -p "$codex_home"
tmp=$(mktemp "${TMPDIR:-/tmp}/codex-config.XXXXXX")
trap 'rm -f "$tmp" "$tmp.body"' EXIT

if [[ -f "$target_config" ]]; then
  awk -v begin="$begin_marker" -v end="$end_marker" '
    BEGIN { in_managed = 0; in_top = 1; emitted = 0 }
    $0 == begin { in_managed = 1; next }
    $0 == end { in_managed = 0; next }
    in_managed { next }
    /^\[/ { in_top = 0 }
    in_top && /^(model|model_reasoning_effort)[[:space:]]*=/ { next }
    !emitted && /^[[:space:]]*$/ { next }
    { emitted = 1; print }
  ' "$target_config" >"$tmp.body"
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

if [[ -f "$target_config" ]] && cmp -s "$tmp" "$target_config"; then
  echo "Codex defaults already synchronized"
  exit 0
fi

mv "$tmp" "$target_config"
trap 'rm -f "$tmp.body"' EXIT
echo "Synchronized managed Codex defaults into $target_config"
