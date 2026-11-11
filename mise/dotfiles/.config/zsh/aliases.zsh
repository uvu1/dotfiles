alias edit="nvim"
alias code="nvim"
alias vim="nvim"

if [[ -n ${WSL_DISTRO_NAME:-} ]]; then
  alias op="op.exe"
fi

alias ga="git add"
alias gaa="git add ."
alias gst="git status"
alias gcm="git commit -m"
alias gpl="git pull"
alias gps="git push"

alias k="kubectl"

alias bat="bat --style=plain --color=always --paging=always"
alias fd="fd --color=always --hidden --exclude .git"
alias rg="rg --color=always"
alias ls="eza --icons --group-directories-first --color=always"

codex() {
  local selected_profile='' arg
  local -i profile_next=0
  for arg in "$@"; do
    if (( profile_next )); then
      selected_profile=$arg
      profile_next=0
      continue
    fi
    case "$arg" in
      --) break ;;
      --profile|-p) profile_next=1 ;;
      --profile=*) selected_profile=${arg#--profile=} ;;
      -p?*) selected_profile=${arg#-p} ;;
    esac
  done
  if [[ "$selected_profile" != nekok ]]; then
    command codex "$@"
    return
  fi

  # op read は macOS の op と WSL の Windows op.exe の両方で使える。
  local neko_endpoint neko_api
  neko_endpoint=$(op read --no-newline 'op://Personal/Nekok Free-Codex/username') || return
  neko_api=$(op read --no-newline 'op://Personal/Nekok Free-Codex/credential') || return
  if [[ -z "$neko_endpoint" || -z "$neko_api" ]]; then
    print -u2 'nekok: 1Password の endpoint または API キーが空です。'
    return 1
  fi
  # URL は TOML の値として解釈できないため、Codex が文字列として受け取る。
  NEKO_API="$neko_api" command codex --config "model_providers.nekok.base_url=$neko_endpoint" "$@"
}
