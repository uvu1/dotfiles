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

# 1Password の参照を読み、空なら失敗する。
# op read は macOS の op と WSL の Windows op.exe の両方で使える。
_codex_secret() {
  local value
  value=$(op read --no-newline "$1") || return
  if [[ -z "$value" ]]; then
    print -u2 "codex: 1Password の $1 が空です。"
    return 1
  fi
  print -rn -- "$value"
}

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
  local endpoint api
  case "$selected_profile" in
    nekok)
      endpoint=$(_codex_secret 'op://Private/Nekok Free-Codex/username') || return
      api=$(_codex_secret 'op://Private/Nekok Free-Codex/credential') || return
      # URL は TOML の値として解釈できないため、Codex が文字列として受け取る。
      NEKO_API="$api" command codex --config "model_providers.nekok.base_url=$endpoint" "$@"
      ;;
    mistral)
      api=$(_codex_secret 'op://Private/Mistral-Vibe API/credential') || return
      MISTRAL_API_KEY="$api" command codex "$@"
      ;;
    *)
      command codex "$@"
      ;;
  esac
}
