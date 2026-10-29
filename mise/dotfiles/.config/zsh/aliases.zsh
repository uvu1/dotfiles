alias edit="nvim"
alias code="nvim"
alias vim="nvim"

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
    NEKO_API='op://Personal/Nekok Free-Codex/credential' \
      op run -- codex "$@"
  else
    command codex "$@"
  fi
}
