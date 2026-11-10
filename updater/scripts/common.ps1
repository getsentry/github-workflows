
$FallbackVersionPattern = '^v?(?<version>.+)$'

function GetVersionFromTag([string] $tag, [string] $pattern = '')
{
    if ($pattern -ne '' -and $tag -match $pattern -and $Matches.ContainsKey('version'))
    {
        return $Matches['version']
    }
    if ($tag -match $FallbackVersionPattern)
    {
        return $Matches['version']
    }
    return $tag
}

# E.g. `cli@` for both `cli@1.2.3` and `cli@v1.2.3`
function GetTagPrefix([string] $tag, [string] $pattern)
{
    $match = [regex]::Match($tag, $pattern, 'IgnoreCase')
    if (-not $match.Success -or -not $match.Groups['version'].Success)
    {
        return ''
    }
    return $tag.Substring(0, $match.Groups['version'].Index) -replace 'v$', ''
}

function GetVersionAfterPrefix([string] $tag, [string] $prefix)
{
    if ($tag -match ('^' + [regex]::Escape($prefix) + 'v?(?<version>.+)$'))
    {
        return $Matches['version']
    }
    return $null
}

function GetComparableVersion([string] $value)
{
    $value = $value -replace '^v', ''
    try {
        [System.Management.Automation.SemanticVersion]::Parse($value)
    } catch {
        Write-Warning "Failed to parse string '$value' as semantic version: $_"
        $null
    }
}
