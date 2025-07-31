$ENV:STARSHIP_CONFIG = "$HOME\.config\starship\starship.toml"
Invoke-Expression -Command $(chezmoi completion powershell | Out-String)
Invoke-Expression (& { (starship init powershell | Out-String) })
Invoke-Expression (& { (zoxide init powershell | Out-String) })
(&mise activate pwsh) | Out-String | Invoke-Expression

