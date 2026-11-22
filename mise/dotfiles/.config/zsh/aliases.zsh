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

alias bat="bat --style=plain --color=always --paging=always"
alias fd="fd --color=always --hidden --exclude .git"
alias rg="rg --color=always"
alias ls="eza --icons --group-directories-first --color=always"
