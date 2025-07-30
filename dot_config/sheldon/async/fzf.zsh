export FZF_DEFAULT_OPTS="--height 40% --border --reverse "

function ghq_fzf_change_directory() {
  local src=$(ghq list | fzf --preview "eza -l -g -a --icons $(ghq root)/{} | tail -n+4 | awk '{print \$6\"/\"\$8\" \"\$9 \" \" \$10}'")
  if [ -n "$src" ]; then
    BUFFER="cd $(ghq root)/$src"
    zle accept-line
  fi
  zle -R
}

function zoxide-fzf() {
    local src=$(zoxide query -l | fzf --preview "eza -l -g -a --icons {} | tail -n+4 | awk '{print \$6\"/\"\$8\" \"\$9 \" \" \$10}'")
    if [ -n "$src" ]; then
        BUFFER="z $src"
        zle accept-line
    fi
    zle -R -c
}

#zle -N ghq_fzf_change_directory
#bindkey '^g' ghq_fzf_change_directory
zle -N zoxide-fzf
bindkey '^z' zoxide-fzf

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*:default' menu select=1
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:*' use-fzf-default-opts yes
