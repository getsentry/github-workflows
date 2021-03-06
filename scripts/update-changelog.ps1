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
        throw "Unexpected changelog line - expecting a version header at this point, such as '## Unreleased', but found: '$line'"
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
:outer for ($i = 0; $i -lt $lines.Count; $i++)
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
        throw "Unexpected changelog line - expecting a section header at this point, such as '### Features', but found: '$line'"
    }

    if (-not ($line -match "features"))
    {
        # If it's a version-specific section header but not "Features", skip all the items in this section
        if ($line.StartsWith("###"))
        {
            for ($i = $i + 1; $i -lt $lines.Count - 1; $i++)
            {
                if ($lines[$i + 1].StartsWith("#"))
                {
                    continue outer
                }
            }
        }

        # add Features as the first sub-header
        Write-Host "Adding a new '### Features' section at line $i"
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
        Write-Host "Found a Features header at $i"
        # Find the next header and then go backward until we find a non-empty line
        for ($i++; $i -lt $lines.Count -and -not $lines[$i].StartsWith("#"); $i++) {}
        for ($i--; $i -gt 0 -and $lines[$i].Trim().Length -eq 0; $i--) {}
        $i += ($lines[$i] -match "Features") ? 2 : 1
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
for ($i = 0; $i -lt $sectionEnd; $i++)
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
        "  - [diff]($RepoUrl/compare/$OldTag...$NewTag)")

    Write-Host "Adding a changelog entry at line $($sectionEnd):"
    foreach ($line in $entry)
    {
        Write-Host "  ", $line
    }
    $linesPost = $lines.Count -gt $sectionEnd ? $lines[$sectionEnd..($lines.Count - 1)] : @()
    $lines = $lines[0..($sectionEnd - 1)] + $entry + $linesPost
}

$lines | Out-File $file
