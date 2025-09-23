param(
    [Parameter(Mandatory = $true)][string] $RepoUrl,
    [Parameter(Mandatory = $true)][string] $OldTag,
    [Parameter(Mandatory = $true)][string] $NewTag
)

Set-StrictMode -Version latest

$prefix = 'https?://(www\.)?github.com/'
if (-not ($RepoUrl -match "^$prefix([^/]+)/([^/]+?)(?:\.git)?/?$")) {
    Write-Warning "Only https://github.com repositories are currently supported. Could not parse repository from URL: $RepoUrl"
    return
}

$repoOwner = $matches[2]
$repoName = $matches[3]
$apiRepo = "$repoOwner/$repoName"

# Create temporary directory for changelog files
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())
New-Item -ItemType Directory $tmpDir | Out-Null

# Function to try different changelog filenames
function Get-ChangelogContent {
    param($ref, $filePath)

    $changelogNames = @('CHANGELOG.md', 'changelog.md', 'CHANGELOG.txt', 'changelog.txt', 'CHANGELOG')

    foreach ($name in $changelogNames) {
        try {
            # Try fetching directly from raw.githubusercontent.com
            $rawUrl = "https://raw.githubusercontent.com/$apiRepo/$ref/$name"
            $content = Invoke-RestMethod -Uri $rawUrl -Method Get -ErrorAction SilentlyContinue
            if ($content) {
                Set-Content -Path $filePath -Value $content -Encoding UTF8
                Write-Host "Found $name for ref $ref"
                return $true
            }
        } catch {
            # Continue to next filename
        }
    }
    return $false
}

$result = ''
try {
    Write-Host 'Fetching CHANGELOG files for comparison...'

    # Fetch old changelog
    $oldChangelogPath = Join-Path $tmpDir 'old-changelog.md'
    if (-not (Get-ChangelogContent $OldTag $oldChangelogPath)) {
        Write-Warning "Could not find changelog at $OldTag"
        $result = ''
    }
    else {
        # Fetch new changelog
        $newChangelogPath = Join-Path $tmpDir 'new-changelog.md'
        if (-not (Get-ChangelogContent $NewTag $newChangelogPath)) {
            Write-Warning "Could not find changelog at $NewTag"
            $result = ''
        }
        else {

        Write-Host "Generating changelog diff between $OldTag and $NewTag..."

        # Generate diff using git diff --no-index
        $fullDiff = git diff --no-index $oldChangelogPath $newChangelogPath

        # The first lines are diff metadata, skip them
        $fullDiff = $fullDiff -split "`n" | Select-Object -Skip 4

        if ([string]::IsNullOrEmpty($fullDiff)) {
            Write-Host "No differences found between $OldTag and $NewTag"
            $result = ''
        }
        else {

            # Extract only the added lines (lines starting with + but not ++)
            $addedLines = $fullDiff | Where-Object { $_ -match '^[+][^+]*' } | ForEach-Object { $_.Substring(1) }

            if ($addedLines.Count -gt 0) {
                # Create clean changelog from added lines
                $changelog = ($addedLines -join "`n").Trim()

                # Apply formatting to clean changelog
                if ($changelog.Length -gt 0) {
                    # Add header
                    if (-not ($changelog -match '^(##|#) Changelog')) {
                        $changelog = "## Changelog`n`n$changelog"
                    }

                    # Increase header level by one for content (not the main header)
                    $changelog = $changelog -replace '(^|\n)(#+) ', '$1$2# ' -replace '^### Changelog', '## Changelog'

                    # Only add details section if there are deletions or modifications (not just additions)
                    $hasModifications = $fullDiff | Where-Object { $_ -match '^[-]' -and $_ -notmatch '^[-]{3}' }
                    if ($hasModifications) {
                        $changelog += "`n`n<details>`n<summary>Full CHANGELOG.md diff</summary>`n`n"
                        $changelog += '```diff' + "`n"
                        $changelog += $fullDiff -join "`n"
                        $changelog += "`n" + '```' + "`n`n</details>"
                    }

                    # Apply standard formatting
                    # Remove at-mentions.
                    $changelog = $changelog -replace '@', ''
                    # Make PR/issue references into links to the original repository (unless they already are links).
                    $changelog = $changelog -replace '(?<!\[)#([0-9]+)(?![\]0-9])', ('[#$1](' + $RepoUrl + '/issues/$1)')
                    # Replace any links pointing to github.com so that the target PRs/Issues don't get na notification.
                    $changelog = $changelog -replace ('\(' + $prefix), '(https://github-redirect.dependabot.com/'

                    # Limit the changelog length to ~60k to allow for other text in the PR body (total PR limit is 65536 characters).
                    $limit = 60000
                    if ($changelog.Length -gt $limit) {
                        $oldLength = $changelog.Length
                        Write-Warning "Truncating changelog because it's $($changelog.Length - $limit) characters longer than the limit $limit."
                        while ($changelog.Length -gt $limit) {
                            $changelog = $changelog.Substring(0, $changelog.LastIndexOf("`n"))
                        }
                        $changelog += "`n`n> :warning: **Changelog content truncated by $($oldLength - $changelog.Length) characters because it was over the limit ($limit) and wouldn't fit into PR description.**"
                    }

                    $result = $changelog
                } else {
                    $result = ''
                }
            } else {
                Write-Host "No changelog additions found between $OldTag and $NewTag"
                $result = ''
            }
        }
        }
    }
} catch {
    Write-Warning "Failed to get changelog: $($_.Exception.Message)"
    $result = ''
} finally {
    if (Test-Path $tmpDir) {
        Write-Host 'Cleaning up temporary files...'
        Remove-Item -Recurse -Force -ErrorAction Continue $tmpDir
    }
}

# Output the result
$result
