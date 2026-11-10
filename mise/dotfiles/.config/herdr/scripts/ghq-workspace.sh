#!/usr/bin/env bash
# ghq のリポジトリを選び、そのリポジトリを cwd とする herdr の workspace へ切り替える
# （herdr の [[keys.command]] prefix+g、type = "popup"）。
#
# 選択 UI は zsh/ghq.zsh の ghq-fzf と同じ（ghq list | fzf + README プレビュー）。
# workspace 名は wezterm/workspaces.lua の workspace_name と同じく owner/repo にし、
# 同名の workspace が既にあれば新しく作らずそこへ移る。
set -euo pipefail

herdr=${HERDR_BIN_PATH:-herdr}
root=$(ghq root)

repo=$(
  ghq list |
    fzf --prompt "ghq> " \
      --preview "bat --color=always --style=header,grid --line-range :80 '$root'/{}/README.*"
) || exit 0 # Esc / Ctrl-C で抜けたときは何もしない

# <host>/<owner>/<repo> の末尾 2 段を workspace 名にする。
label=$(printf '%s\n' "$repo" | awk -F/ '{ print (NF >= 2 ? $(NF - 1) "/" $NF : $NF) }')

workspace_id=$(
  "$herdr" workspace list |
    jq -r --arg label "$label" \
      'first(.result.workspaces[] | select(.label == $label) | .workspace_id) // empty'
)

if [[ -n $workspace_id ]]; then
  "$herdr" workspace focus "$workspace_id" >/dev/null
else
  "$herdr" workspace create --cwd "$root/$repo" --label "$label" --focus >/dev/null
fi
