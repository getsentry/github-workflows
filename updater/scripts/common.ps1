
function GetComparableVersion([Parameter(Mandatory = $true)][string] $value)
{
    $value = $value -replace '^v', ''
    try {
        [System.Management.Automation.SemanticVersion]::Parse($value)
    } catch {
        Write-Warning "Failed to parse string '$value' as semantic version: $_"
        $null
    }
}
