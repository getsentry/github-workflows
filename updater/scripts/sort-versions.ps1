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
        Write-Warning "Failed to parse semantic version '$value': $_"
        $null
    }
}

$List `
    | Where-Object { $null -ne (GetComparableVersion $_)  } `
    | Sort-Object -Property @{Expression = { GetComparableVersion $_ } }
