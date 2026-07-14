[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($MyInvocation.UnboundArguments.Count -ne 0) {
    [Console]::Error.WriteLine("dotfiles-update: this command does not accept arguments")
    exit 2
}

& dotflow update
exit $LASTEXITCODE
