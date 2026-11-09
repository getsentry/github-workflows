param(
    [Parameter(Mandatory = $true)][string[]] $List,
    [string] $Pattern = ''
)

Set-StrictMode -Version latest
. "$PSScriptRoot/common.ps1"

$List `
    | Where-Object { $null -ne (GetComparableVersion (GetVersionFromTag $_ $Pattern)) } `
    | Sort-Object -Property @{Expression = { GetComparableVersion (GetVersionFromTag $_ $Pattern) } }
