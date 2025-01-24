param(
    [Parameter(Mandatory = $true)][string[]] $List
)

Set-StrictMode -Version latest

function GetComparableVersion([Parameter(Mandatory = $true)][string] $value)
{
    $value = $value -replace '^v', ''
    try {
        [System.Management.Automation.SemanticVersion]::Parse($value)
    } catch {
        Write-Error "Failed to parse semantic version '$value': $_"
    }
}

$List | Sort-Object -Property @{Expression = { GetComparableVersion $_ } }
