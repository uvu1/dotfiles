if (Get-Command kubectl -ErrorAction SilentlyContinue) {
    kubectl completion powershell | Out-String | Invoke-Expression
}

if (Get-Command gh -ErrorAction SilentlyContinue) {
    gh completion -s powershell | Out-String | Invoke-Expression
}
