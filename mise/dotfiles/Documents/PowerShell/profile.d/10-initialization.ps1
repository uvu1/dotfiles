if (Get-Command mise -ErrorAction SilentlyContinue) {
    (& mise activate pwsh --shims) | Out-String | Invoke-Expression
}

if (Get-Command dotflow -ErrorAction SilentlyContinue) {
    (& dotflow shell-init powershell) | Out-String | Invoke-Expression
}

if (Get-Command starship -ErrorAction SilentlyContinue) {
    (& starship init powershell) | Out-String | Invoke-Expression
}

Import-Module PSReadLine

Set-PSReadLineOption -EditMode Emacs
