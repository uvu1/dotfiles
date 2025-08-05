alias vim="nvim"
alias vi="nvim"

alias gst="git status"
alias gco="git checkout"
alias gcm="git commit -m"
alias gpl="git pull"
alias gps="git push"
alias gbr="git branch"

alias ls="eza --icons --group-directories-first --color=always"
alias cat="bat --style=plain --color=always --paging=always"
alias fd="fd --color=always --hidden --exclude .git"
alias find="fd --color=always --hidden --exclude .git"
alias grep="rg --color=always --line-number --smart-case"
alias rg="rg --color=always --line-number --smart-case"

nvim() {
    if ! pidof socat > /dev/null 2>&1; then
        [ -e /tmp/discord-ipc-0 ] && rm -f /tmp/discord-ipc-0
        socat UNIX-LISTEN:/tmp/discord-ipc-0,fork \
            EXEC:"npiperelay.exe //./pipe/discord-ipc-0" 2>/dev/null &
    fi

    if [ $# -eq 0 ]; then
        command nvim
    else
        command nvim "$@"
    fi
}
