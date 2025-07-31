$ENV:STARSHIP_CONFIG = "$HOME\.config\starship\starship.toml"
$ENV:EDITOR="nvim"
$ENV:FZF_DEFAULT_OPTS="--height 40% --border --reverse "
Invoke-Expression -Command $(chezmoi completion powershell | Out-String)
Invoke-Expression (& { (starship init powershell | Out-String) })
Invoke-Expression (& { (zoxide init powershell | Out-String) })
(&mise activate pwsh) | Out-String | Invoke-Expression

Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-Alias -Name grep -Value rg
Set-Alias -Name which -Value Get-Command
Set-Alias -Name touch -Value New-Item
Set-Alias -Name code -Value $ENV:EDITOR
Set-Alias -Name edit -Value $ENV:EDITOR

function Get-FzfRepo {
    $repo = $(ghq list | fzf)
    Set-Location ( Join-Path $(ghq root) $repo)
}

Set-PSReadLineKeyHandler -Chord Ctrl+g -ScriptBlock {
    Get-FzfRepo
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}

function Get-HistoryFzf {
    Invoke-Expression ((Get-Content $(Get-PSReadLineOption).HistorySavePath) | fzf)
}

Set-PSReadLineKeyHandler -Chord Ctrl+r -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    Get-HistoryFzf
}

function gst {
    git status
}

function gadd {
    git add
}

function gcm {
    git commit -m
}

function gps{
    git push
}

function gpl {
    git pull
}

function cat {
    bat --style=plain
}

function ls {
    eza --icons
}

