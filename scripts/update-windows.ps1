[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$env:MISE_EXPERIMENTAL = "1"

if ($MyInvocation.UnboundArguments.Count -ne 0) {
    throw "this command does not accept arguments"
}

$stage = "initialization"
$repoRoot = Join-Path $HOME "migrate-dotfiles"
$miseDir = Join-Path $repoRoot "mise"
$globalMiseConfig = Join-Path $HOME ".config/mise/config.toml"
$powerShellTargets = @(
    $globalMiseConfig,
    (Join-Path $HOME ".config/starship.toml"),
    (Join-Path $HOME "Documents/PowerShell")
)

function Write-Stage {
    param([Parameter(Mandatory)][string]$Name)

    $script:stage = $Name
    Write-Host "`n==> $Name"
}

function Invoke-Native {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$ArgumentList
    )

    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath failed with exit code $LASTEXITCODE"
    }
}

function Get-GitValue {
    param([Parameter(Mandatory)][string[]]$ArgumentList)

    $output = & git -C $repoRoot @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "git failed with exit code $LASTEXITCODE"
    }

    return ($output -join "`n").Trim()
}

try {
    Write-Stage "preflight checks"

    foreach ($requiredCommand in @("git", "mise")) {
        if ($null -eq (Get-Command $requiredCommand -ErrorAction SilentlyContinue)) {
            throw "required command not found: $requiredCommand"
        }
    }

    if (-not (Test-Path -LiteralPath $repoRoot -PathType Container)) {
        throw "repository not found: $repoRoot"
    }

    $insideWorktree = Get-GitValue -ArgumentList @("rev-parse", "--is-inside-work-tree")
    if ($insideWorktree -ne "true") {
        throw "not a Git worktree: $repoRoot"
    }

    $actualRoot = [System.IO.Path]::GetFullPath((Get-GitValue -ArgumentList @("rev-parse", "--show-toplevel")))
    $expectedRoot = [System.IO.Path]::GetFullPath($repoRoot)
    if (-not $actualRoot.Equals($expectedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Git worktree root must be exactly $repoRoot"
    }

    $branch = Get-GitValue -ArgumentList @("branch", "--show-current")
    if ($branch -ne "master") {
        $displayBranch = if ([string]::IsNullOrEmpty($branch)) { "detached HEAD" } else { $branch }
        throw "expected branch master, found $displayBranch"
    }

    $origin = Get-GitValue -ArgumentList @("remote", "get-url", "origin")
    $allowedOrigins = @(
        "https://github.com/uvu1/dotfiles",
        "https://github.com/uvu1/dotfiles.git",
        "git@github.com:uvu1/dotfiles.git"
    )
    if ($origin -notin $allowedOrigins) {
        throw "origin must point to uvu1/dotfiles, found $origin"
    }

    $worktreeStatus = Get-GitValue -ArgumentList @("status", "--porcelain=v1", "--untracked-files=all")
    if (-not [string]::IsNullOrEmpty($worktreeStatus)) {
        [Console]::Error.WriteLine("dotfiles-update: worktree is not clean:`n$worktreeStatus")
        throw "commit or restore these changes before updating"
    }

    Write-Stage "fast-forward master"
    Invoke-Native -FilePath "git" -ArgumentList @("-C", $repoRoot, "pull", "--ff-only", "origin", "master")

    $localHead = Get-GitValue -ArgumentList @("rev-parse", "HEAD")
    $fetchedHead = Get-GitValue -ArgumentList @("rev-parse", "FETCH_HEAD")
    if ($localHead -ne $fetchedHead) {
        throw "local master does not exactly match origin/master after pull"
    }

    Write-Stage "trust mise configs"
    foreach ($configFile in @("mise.toml", "mise.windows.toml", "mise.windows-powershell.toml")) {
        Invoke-Native -FilePath "mise" -ArgumentList @("trust", (Join-Path $miseDir $configFile))
    }

    Write-Stage "install Windows tools"
    Invoke-Native -FilePath "mise" -ArgumentList @("-C", $miseDir, "-E", "windows", "install")

    Write-Stage "install PowerShell tools"
    Invoke-Native -FilePath "mise" -ArgumentList @("-C", $miseDir, "-E", "windows-powershell", "install")

    Write-Stage "apply Windows dotfiles"
    Invoke-Native -FilePath "mise" -ArgumentList @("-C", $miseDir, "-E", "windows", "dotfiles", "apply", "--yes")

    Write-Stage "apply PowerShell dotfiles"
    Invoke-Native -FilePath "mise" -ArgumentList (@("-C", $miseDir, "-E", "windows-powershell", "dotfiles", "apply", "--yes") + $powerShellTargets)

    Write-Stage "verify dotfiles"
    Invoke-Native -FilePath "mise" -ArgumentList @("-C", $miseDir, "-E", "windows", "dotfiles", "status", "--missing")
    Invoke-Native -FilePath "mise" -ArgumentList @("-C", $miseDir, "-E", "windows", "dotfiles", "status")
    Invoke-Native -FilePath "mise" -ArgumentList (@("-C", $miseDir, "-E", "windows-powershell", "dotfiles", "status", "--missing") + $powerShellTargets)
    Invoke-Native -FilePath "mise" -ArgumentList (@("-C", $miseDir, "-E", "windows-powershell", "dotfiles", "status") + $powerShellTargets)

    Write-Host "`ndotfiles-update: complete at $localHead"
}
catch {
    [Console]::Error.WriteLine("dotfiles-update: failed during ${stage}: $($_.Exception.Message)")
    exit 1
}
