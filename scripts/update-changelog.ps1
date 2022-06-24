
param(
    [Parameter(Mandatory = $true)][string] $Name,
    [Parameter(Mandatory = $true)][Int32] $PR,
    [Parameter(Mandatory = $true)][string] $RepoUrl,
    [Parameter(Mandatory = $true)][string] $MainBranch,
    [Parameter(Mandatory = $true)][string] $OldTag,
    [Parameter(Mandatory = $true)][string] $NewTag
)

Set-StrictMode -Version latest

$file = $(Get-ChildItem | Where-Object { $_.Name -match '^changelog(\.md|\.txt|)$' } )
if ("$file" -eq "")
{
    throw "Couldn't find a changelog"
}
elseif ($file -is [Array])
{
    throw "Multiple changelogs found: $file"
}
Write-Host "Found changelog: $file"

[string[]]$lines = Get-Content $file

# Make sure that there's an `Unreleased` header
for ($i = 0; $i -lt $lines.Count; $i++)
{
    $line = $lines[$i]

    # Skip the "Changelog" header and empty lines at the beginning.
    if ($line -match "changelog" -or $line.Trim().Length -eq 0)
    {
        continue
    }

    # Next, we expect a header for the current version or "Unreleased".
    if (-not $line.StartsWith("#"))
    {
        throw "Unexpected changelog line: $line"
    }

    # If it's an existing version instead of "Unreleased".
    if (-not ($line -match "unreleased"))
    {
        Write-Host "Adding a new '## Unreleased' section"
        $lines = $lines[0..($i - 1)] + @("## Unreleased", "") + $lines[$i..($lines.Count - 1)]
    }
    break
}

# Make sure that there's a `Features` header
for ($i = 0; $i -lt $lines.Count; $i++)
{
    $line = $lines[$i]

    # Skip the "Changelog" header and empty lines at the beginning.
    if ($line -match "changelog" -or $line -match "unreleased" -or $line.Trim().Length -eq 0)
    {
        continue
    }

    # Next, we expect a header
    if (-not $line.StartsWith("#"))
    {
        throw "Unexpected changelog line: $line"
    }

    # add Features as the first sub-header
    if (-not ($line -match "features"))
    {
        Write-Host "Adding a new '### Features' section"
        $lines = $lines[0..($i - 1)] + @("### Features", "", "") + $lines[$i..($lines.Count - 1)]
    }
    break
}

# Find the last point in the first `Features` header
for ($i = 0; $i -lt $lines.Count; $i++)
{
    $line = $lines[$i]
    if ($line -match "Features")
    {
        # Find the next header and then go backward until we find a non-empty line
        for ($i++; $i -lt $lines.Count -and -not $lines[$i].StartsWith("#"); $i++) {}
        for ($i--; $i -gt 0 -and $lines[$i].Trim().Length -eq 0; $i++) {}
        break
    }
}

$tagAnchor = $NewTag.Replace('.', '')
$newTagNice = ($NewTag -match "^[0-9]") ? "v$NewTag" : $NewTag
$entry = @("- Bump $Name to $newTagNice ([#$PR](https://github.com/getsentry/sentry-unity/pull/$PR))",
    "  - [changelog]($RepoUrl/blob/$MainBranch/CHANGELOG.md#$tagAnchor)",
    "  - [diff]($RepoUrl/compare/$OldTag...$NewTag)",
    "")

Write-Host "Adding a changelog entry at line $($i):"
foreach ($line in $entry)
{
    Write-Host $line
}

$lines = $lines[0..($i - 2)] + $entry + $lines[$i..($lines.Count - 1)]
$lines | Out-File $file