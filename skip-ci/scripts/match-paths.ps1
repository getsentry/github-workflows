# Returns $true when every file matches the patterns.
# A pattern starting with '!' takes matching files back out; the last pattern that matches a file decides.
# '**' matches any characters including '/', and a leading '**/' also matches files at the root;
# '*' matches any characters except '/'; '?' matches one character except '/'. Matching is case-sensitive.
param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]] $Files,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][string[]] $Patterns
)

Set-StrictMode -Version latest

function ConvertTo-Regex([string] $glob)
{
    $regex = ''
    $i = 0
    while ($i -lt $glob.Length)
    {
        if ($glob.Substring($i).StartsWith('**/'))
        {
            $regex += '(?:.*/)?'
            $i += 3
        }
        elseif ($glob.Substring($i).StartsWith('**'))
        {
            $regex += '.*'
            $i += 2
        }
        elseif ($glob[$i] -eq '*')
        {
            $regex += '[^/]*'
            $i++
        }
        elseif ($glob[$i] -eq '?')
        {
            $regex += '[^/]'
            $i++
        }
        else
        {
            $regex += [regex]::Escape([string]$glob[$i])
            $i++
        }
    }
    "^$regex$"
}

$rules = @(foreach ($pattern in $Patterns)
    {
        $pattern = $pattern.Trim()
        if ($pattern -eq '' -or $pattern.StartsWith('#'))
        {
            continue
        }
        $exclude = $pattern.StartsWith('!')
        if ($exclude)
        {
            $pattern = $pattern.Substring(1)
        }
        [pscustomobject]@{ Regex = ConvertTo-Regex $pattern; Exclude = $exclude }
    })

if ($Files.Count -eq 0 -or $rules.Count -eq 0)
{
    return $false
}

foreach ($file in $Files)
{
    $matched = $false
    foreach ($rule in $rules)
    {
        if ($file -cmatch $rule.Regex)
        {
            $matched = -not $rule.Exclude
        }
    }
    if (-not $matched)
    {
        return $false
    }
}
return $true
