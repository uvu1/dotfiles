[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($MyInvocation.UnboundArguments.Count -ne 0) {
    [Console]::Error.WriteLine("bootstrap-windows: this command does not accept arguments")
    exit 2
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$miseDir = Join-Path $repoRoot "mise"
$wingetConfig = Join-Path $repoRoot ".config/configuration.winget"
$env:MISE_EXPERIMENTAL = "1"

function Invoke-Checked {
    param(
        [Parameter(Mandatory)][string]$Program,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Program failed with exit code $LASTEXITCODE"
    }
}

if ($null -eq (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget 1.6.2631 or newer is required. Install or update App Installer first."
}

[string]$wingetVersionOutput = & winget --version
if ($LASTEXITCODE -ne 0) {
    throw "failed to determine the winget version"
}

$wingetVersion = [Version]$wingetVersionOutput.Trim().TrimStart("v")
$minimumWingetVersion = [Version]"1.6.2631"
if ($wingetVersion -lt $minimumWingetVersion) {
    throw "winget $minimumWingetVersion or newer is required; found $wingetVersion"
}

# A first-time enable can return non-zero even when the Store component becomes
# available. The following validate call is the authoritative readiness check.
& winget configure --enable
Invoke-Checked -Program "winget" -Arguments @(
    "configure", "validate", "-f", $wingetConfig,
    "--disable-interactivity"
)
Invoke-Checked -Program "winget" -Arguments @(
    "configure", "-f", $wingetConfig,
    "--accept-configuration-agreements",
    "--disable-interactivity"
)
Invoke-Checked -Program "winget" -Arguments @(
    "configure", "test", "-f", $wingetConfig,
    "--accept-configuration-agreements",
    "--disable-interactivity"
)

$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machinePath;$userPath"

if ($null -eq (Get-Command mise -ErrorAction SilentlyContinue)) {
    throw "mise was installed but is not available on PATH. Open a new PowerShell and rerun this script."
}

Invoke-Checked -Program "mise" -Arguments @("-C", $miseDir, "trust", "-a")
Invoke-Checked -Program "mise" -Arguments @("-C", $miseDir, "-E", "windows", "install")
Invoke-Checked -Program "mise" -Arguments @(
    "-C", $miseDir, "-E", "windows",
    "dotfiles", "apply", "--dry-run", "--verbose"
)
Invoke-Checked -Program "mise" -Arguments @(
    "-C", $miseDir, "-E", "windows",
    "dotfiles", "apply", "--yes"
)
Invoke-Checked -Program "mise" -Arguments @(
    "-C", $miseDir, "-E", "windows",
    "dotfiles", "status", "--missing"
)
Invoke-Checked -Program "mise" -Arguments @(
    "-C", $miseDir, "-E", "windows",
    "dotfiles", "status"
)
Invoke-Checked -Program "mise" -Arguments @(
    "-C", $miseDir, "-E", "windows",
    "exec", "--", "dotflow", "doctor"
)
