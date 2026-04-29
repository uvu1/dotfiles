(&mise activate pwsh --shims ) | Out-String | Invoke-Expression
Invoke-Expression (&starship init powershell)

Import-Module PSReadLine

Set-PSReadLineOption -EditMode Emacs