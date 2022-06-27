param(
    [Parameter(Mandatory = $true)][string] $Name,
    [Parameter(Mandatory = $true)][string] $PR,
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

# What line we want to insert at - the empty line at the end of the currently unreleased Features section.
$sectionEnd = $i

$tagAnchor = $NewTag.Replace('.', '')
$newTagNice = ($NewTag -match "^[0-9]") ? "v$NewTag" : $NewTag

$PullRequestMD = "[#$($PR | Split-Path -Leaf)]($PR)"

# First check if an existing entry for the same dependency exists among unreleased features - if so, update it instead of adding a new one.
$updated = $false
for ($i = 0; $i -lt $sectionEnd - 2; $i++)
{
    if (($lines[$i] -match "^- Bump $Name to") -and `
        ($lines[$i + 1] -match "^  - \[changelog\]\($RepoUrl") -and `
        ($lines[$i + 2] -match "^  - \[diff\]\($RepoUrl"))
    {
        Write-Host "Found an existing changelog entry at $($i):"
        Write-Host "  ", $lines[$i]
        Write-Host "  ", $lines[$i + 1]
        Write-Host "  ", $lines[$i + 2]

        $lines[$i] = $lines[$i] -replace "Bump $Name to .* \(", "Bump $Name to $newTagNice ("
        $lines[$i] = $lines[$i] -replace "\)$", ", $PullRequestMD)"
        $lines[$i + 1] = "  - [changelog]($RepoUrl/blob/$MainBranch/CHANGELOG.md#$tagAnchor)"
        $lines[$i + 2] = $lines[$i + 2] -replace "\.\.\..*\)$", "...$NewTag)"

        Write-Host "Updating the entry to: "
        Write-Host "  ", $lines[$i]
        Write-Host "  ", $lines[$i + 1]
        Write-Host "  ", $lines[$i + 2]
        $updated = $true
        break;
    }
}

if (!$updated)
{
    $entry = @("- Bump $Name to $newTagNice ($PullRequestMD)",
        "  - [changelog]($RepoUrl/blob/$MainBranch/CHANGELOG.md#$tagAnchor)",
        "  - [diff]($RepoUrl/compare/$OldTag...$NewTag)",
        "")

    Write-Host "Adding a changelog entry at line $($sectionEnd):"
    foreach ($line in $entry)
    {
        Write-Host "  ", $line
    }
    $lines = $lines[0..($sectionEnd - 2)] + $entry + $lines[$sectionEnd..($lines.Count - 1)]
}

$lines | Out-File $file
