param(
    [Parameter(Mandatory = $true)][string] $RepoUrl,
    [Parameter(Mandatory = $true)][string] $OldTag,
    [Parameter(Mandatory = $true)][string] $NewTag
)

Set-StrictMode -Version latest

$prefix = '^https://(www\.)?github.com/'
if (-not ($RepoUrl -match $prefix)) {
    Write-Warning "Only github.com repositories are currently supported. Given RepoUrl doesn't look like one: $RepoUrl"
    return
}

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())

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

    if (-not $foundFirst) {
        if ($line -match "^#+ +v?$NewTag\b") {
            $foundFirst = $true
        } else {
            continue
        }
    } elseif ($line -match "^#+ +v?$OldTag\b") {
        break
    }

    $changelog += "$line`n"
}

$changelog = $changelog.Trim()
if ($changelog.Length -gt 1) {
    $changelog = "# Changelog`n$changelog"
    # Increase header level by one.
    $changelog = $changelog -replace "(#+) ",'$1# '
    # Remove at-mentions.
    $changelog = $changelog -replace '@',''
    # Make PR/issue references into links to the original repository (unless they already are links).
    $changelog = $changelog -replace '(?<!\[)#([0-9]+)', ('[#$1](' + $RepoUrl + '/issues/$1)')
}
$changelog
