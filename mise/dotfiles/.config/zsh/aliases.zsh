alias edit="nvim"
alias code="nvim"
alias vim="nvim"

if [[ -n ${WSL_DISTRO_NAME:-} ]]; then
  alias op="/mnt/c/Users/${USER}/AppData/Local/Microsoft/WinGet/Links/op.exe"
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
  if [[ "$1" == "--profile" && "$2" == "nekok" ]]; then
    local neko_ref='op://Personal/Nekok Free-Codex/credential'
    if [[ -n ${WSL_DISTRO_NAME:-} ]]; then
      # Windows の op.exe run は WSL 側の codex を起動できない。
      local neko_api
      neko_api=$(op read --no-newline "$neko_ref") || return
      NEKO_API="$neko_api" command codex "$@"
    else
      NEKO_API="$neko_ref" op run -- codex "$@"
    fi
  else
    command codex "$@"
  fi
}
