[CmdletBinding()]
param(
    [switch]$IncludePowerShell,
    [switch]$Yes
)

$ErrorActionPreference = "Stop"
$env:MISE_EXPERIMENTAL = "1"
$repoRoot = Split-Path -Parent $PSScriptRoot
$miseDir = Join-Path $repoRoot "mise"
$globalMiseConfig = Join-Path $HOME ".config/mise/config.toml"
$powerShellDotfileTargets = @(
    $globalMiseConfig,
    (Join-Path $HOME ".config/starship.toml"),
    (Join-Path $HOME "Documents/PowerShell")
)

function Invoke-Mise {
    param([Parameter(Mandatory)][string[]]$MiseArgs)

    & mise @MiseArgs
    if ($LASTEXITCODE -ne 0) {
        throw "mise failed with exit code $LASTEXITCODE"
    }
}

function Install-GitWindows {
    $variableName = "MISE_GITHUB_GITHUB_ATTESTATIONS"
    $previousValue = [Environment]::GetEnvironmentVariable($variableName, "Process")

    try {
        [Environment]::SetEnvironmentVariable($variableName, "false", "Process")
        Invoke-Mise -MiseArgs @("-C", $miseDir, "-E", "windows", "install", "git-windows")
    }
    finally {
        [Environment]::SetEnvironmentVariable($variableName, $previousValue, "Process")
    }
}

$targets = @(
    (Join-Path $HOME ".config/nvim"),
    (Join-Path $HOME ".config/wezterm"),
    (Join-Path $HOME ".config/mise"),
    (Join-Path $HOME ".config/starship.toml"),
    (Join-Path $HOME ".gitconfig"),
    (Join-Path $HOME "Documents/PowerShell")
)

Invoke-Mise -MiseArgs @(
    "-C", $miseDir,
    "-E", "windows",
    "dotfiles", "apply", "--dry-run", "--force", "--verbose"
)

if ($IncludePowerShell) {
    Invoke-Mise -MiseArgs (@(
        "-C", $miseDir,
        "-E", "windows-powershell",
        "dotfiles", "apply", "--dry-run", "--force", "--verbose"
    ) + $powerShellDotfileTargets)
}

Write-Host "The following chezmoi-applied paths will be deleted:"
$targets | ForEach-Object { Write-Host "  $_" }
$confirmation = if ($Yes) { "delete" } else { Read-Host "Type delete to continue" }

if ($confirmation -ne "delete") {
    throw "cancelled"
}

foreach ($target in $targets) {
    $fullTarget = [System.IO.Path]::GetFullPath($target)
    $fullHome = [System.IO.Path]::GetFullPath($HOME).TrimEnd('\') + '\'

    if (-not $fullTarget.StartsWith($fullHome, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "refusing path outside HOME: $fullTarget"
    }

    $item = Get-Item -LiteralPath $fullTarget -Force -ErrorAction SilentlyContinue
    if ($null -ne $item) {
        if ($null -ne $item.LinkType) {
            Remove-Item -LiteralPath $fullTarget -Force
        }
        else {
            Remove-Item -LiteralPath $fullTarget -Recurse -Force
        }
    }
}

Invoke-Mise -MiseArgs @(
    "-C", $miseDir,
    "-E", "windows",
    "dotfiles", "apply", "--dry-run", "--verbose", $globalMiseConfig
)
Invoke-Mise -MiseArgs @(
    "-C", $miseDir,
    "-E", "windows",
    "dotfiles", "apply", "--yes", $globalMiseConfig
)

Install-GitWindows
Invoke-Mise -MiseArgs @("-C", $miseDir, "-E", "windows", "install")
Invoke-Mise -MiseArgs @("-C", $miseDir, "-E", "windows", "ls", "--current")

Invoke-Mise -MiseArgs @(
    "-C", $miseDir,
    "-E", "windows",
    "dotfiles", "apply", "--dry-run", "--verbose"
)
Invoke-Mise -MiseArgs @(
    "-C", $miseDir,
    "-E", "windows",
    "dotfiles", "apply", "--yes"
)
Invoke-Mise -MiseArgs @(
    "-C", $miseDir,
    "-E", "windows",
    "dotfiles", "apply", "--yes"
)
Invoke-Mise -MiseArgs @(
    "-C", $miseDir,
    "-E", "windows",
    "dotfiles", "status", "--missing"
)
Invoke-Mise -MiseArgs @(
    "-C", $miseDir,
    "-E", "windows",
    "dotfiles", "status"
)

if ($IncludePowerShell) {
    Invoke-Mise -MiseArgs @(
        "-C", $miseDir,
        "-E", "windows-powershell",
        "install"
    )
    Invoke-Mise -MiseArgs (@(
        "-C", $miseDir,
        "-E", "windows-powershell",
        "dotfiles", "apply", "--dry-run", "--verbose"
    ) + $powerShellDotfileTargets)
    Invoke-Mise -MiseArgs (@(
        "-C", $miseDir,
        "-E", "windows-powershell",
        "dotfiles", "apply", "--yes"
    ) + $powerShellDotfileTargets)
    Invoke-Mise -MiseArgs (@(
        "-C", $miseDir,
        "-E", "windows-powershell",
        "dotfiles", "status", "--missing"
    ) + $powerShellDotfileTargets)
    Invoke-Mise -MiseArgs (@(
        "-C", $miseDir,
        "-E", "windows-powershell",
        "dotfiles", "status"
    ) + $powerShellDotfileTargets)
}
