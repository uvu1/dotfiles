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

Set-PSReadLineKeyHandler -Key Tab -ScriptBlock {
    Invoke-FzfTabCompletion
}

Set-PsFzfOption `
    -PSReadlineChordProvider 'Ctrl+t' `
    -PSReadlineChordReverseHistory 'Ctrl+r'

Set-PsFzfOption -TabExpansion

Set-PsFzfOption -TabCompletionPreviewWindow 'hidden|down|right|right:hidden'