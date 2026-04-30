kubectl completion powershell | Out-String | Invoke-Expression
Invoke-Expression -Command $(gh completion -s powershell | Out-String)
