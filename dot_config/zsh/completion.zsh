autoload -Uz compinit

ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
mkdir -p "${ZSH_COMPDUMP:h}"

compinit -d "$ZSH_COMPDUMP"

source <(kubectl completion zsh)
eval "$(gh completion -s zsh)"