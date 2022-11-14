param(
    [Parameter(Mandatory = $true)][string] $RepoUrl,
    [Parameter(Mandatory = $true)][string] $OldTag,
    [Parameter(Mandatory = $true)][string] $NewTag
)

Set-StrictMode -Version latest

$prefix = 'https?://(www\.)?github.com/'
if (-not ($RepoUrl -match "^$prefix"))
{
    Write-Warning "Only github.com repositories are currently supported. Given RepoUrl doesn't look like one: $RepoUrl"
    return
}

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())
New-Item -ItemType Directory $tmpDir | Out-Null

try
{
    git clone --depth 1 $RepoUrl $tmpDir

    $file = $(Get-ChildItem -Path $tmpDir | Where-Object { $_.Name -match '^changelog(\.md|\.txt|)$' } )
    if ("$file" -eq "")
    {
        Write-Warning "Couldn't find a changelog"
        return
    }
    elseif ($file -is [Array])
    {
        Write-Warning "Multiple changelogs found: $file"
        return
    }
    Write-Host "Found changelog: $file"
    [string[]]$lines = Get-Content $file
}
finally
{
    Write-Host "Removing $tmpDir"
    Remove-Item -Recurse -Force -ErrorAction Continue -Path $tmpDir
}

$foundFirst = $false
$changelog = ""
for ($i = 0; $i -lt $lines.Count; $i++)
{
    $line = $lines[$i]

    if (-not $foundFirst)
    {
        if ($line -match "^#+ +v?$NewTag\b")
        {
            $foundFirst = $true
        }
        else
        {
            continue
        }
    }
    elseif ($line -match "^#+ +v?$OldTag\b")
    {
        break
    }

    $changelog += "$line`n"
}

$changelog = $changelog.Trim()
if ($changelog.Length -gt 1)
{
    $changelog = "# Changelog`n$changelog"
    # Increase header level by one.
    $changelog = $changelog -replace "(#+) ", '$1# '
    # Remove at-mentions.
    $changelog = $changelog -replace '@', ''
    # Make PR/issue references into links to the original repository (unless they already are links).
    $changelog = $changelog -replace '(?<!\[)#([0-9]+)', ('[#$1](' + $RepoUrl + '/issues/$1)')
    # Replace any links pointing to github.com so that the target PRs/Issues don't get na notification.
    $changelog = $changelog -replace ('\(' + $prefix), '(https://github-redirect.dependabot.com/'
}

# Limit the changelog length to ~60k to allow for other text in the PR body (total PR limit is 65536 characters).
$limit = 60000
if ($changelog.Length -gt $limit)
{
    $oldLength = $changelog.Length
    Write-Warning "Truncating changelog because it's $($changelog.Length - $limit) characters longer than the limit $limit."
    while ($changelog.Length -gt $limit)
    {
        $changelog = $changelog.Substring(0, $changelog.LastIndexOf("`n"))
    }
    $changelog += "`n`n> :warning: **Changelog content truncated by $($oldLength - $changelog.Length) characters because it was over the limit ($limit) and wouldn't fit into PR description.**"
}

$changelog
