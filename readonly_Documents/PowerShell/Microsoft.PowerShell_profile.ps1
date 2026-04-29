$profileDir = Join-Path $global:ProfileRoot "profile.d"

if (Test-Path $profileDir) {
    Get-ChildItem -Path $profileDir -Filter "*.ps1" |
        Sort-Object Name |
        ForEach-Object {
            . $_.FullName
        }
}
