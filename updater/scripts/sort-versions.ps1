param(
    [Parameter(Mandatory = $true)][string[]] $List
)

Set-StrictMode -Version latest
. "$PSScriptRoot/common.ps1"

$List `
    | Where-Object { $null -ne (GetComparableVersion $_)  } `
    | Sort-Object -Property @{Expression = { GetComparableVersion $_ } }
