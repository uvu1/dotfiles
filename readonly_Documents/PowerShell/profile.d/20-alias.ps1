
Set-Alias -Name grep -Value rg
Set-Alias -Name which -Value Get-Command
Set-Alias -Name touch -Value New-Item
Set-Alias -Name code -Value code-insiders
Set-Alias -Name vim -Value nvim

function ls {
    eza --icons --group-directories-first --color=always $args
}

function cat {
    bat --style=plain --color=always --paging=always $args
}

function find {
    fd --color=always
}

function grep {
    rg --color=always
}

function wsl {
    wsl.exe --cd /home/uvu @args
}
