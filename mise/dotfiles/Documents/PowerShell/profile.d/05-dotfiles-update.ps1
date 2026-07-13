function global:Update-Dotfiles {
    [CmdletBinding()]
    param()

    $updateScript = Join-Path $HOME "dotfiles/scripts/update-windows.ps1"
    if (-not (Test-Path -LiteralPath $updateScript -PathType Leaf)) {
        throw "dotfiles update script not found: $updateScript"
    }

    & (Join-Path $PSHOME "pwsh.exe") -NoProfile -File $updateScript
    if ($LASTEXITCODE -ne 0) {
        throw "dotfiles-update failed with exit code $LASTEXITCODE"
    }
}

Set-Alias -Name dotfiles-update -Value Update-Dotfiles -Scope Global -Force
