param(
    [Parameter(Mandatory = $true)][string] $RepoUrl,
    [Parameter(Mandatory = $true)][string] $OldTag,
    [Parameter(Mandatory = $true)][string] $NewTag
)

Set-StrictMode -Version latest
$PSNativeCommandErrorActionPreference = $false
$ErrorActionPreference = 'Stop'

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

# Function to generate changelog from git commits
function Get-ChangelogFromCommits {
    param($repoUrl, $oldTag, $newTag, $tmpDir)

    # Clone the repository
    $repoDir = Join-Path $tmpDir 'repo'
    Write-Host "Cloning repository to generate changelog from commits..."
    git clone --no-single-branch --quiet $repoUrl $repoDir
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Could not clone repository $repoUrl"
        return $null
    }

    if (-not (Test-Path $repoDir)) {
        Write-Warning "Repository directory was not created successfully"
        return $null
    }

    Push-Location $repoDir
    try {
        # Ensure we have both tags
        git fetch --tags --quiet
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not fetch tags from repository"
            return $null
        }

        # Get commit messages between tags
        Write-Host "Getting commits between $oldTag and $newTag..."
        $commitMessages = git log "$oldTag..$newTag" --pretty=format:'%s'
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not get commits between $oldTag and $newTag (exit code: $LASTEXITCODE)"
            return $null
        }

        if ([string]::IsNullOrEmpty($commitMessages)) {
            Write-Host "No commits found between $oldTag and $newTag"
            return $null
        }

        # Filter out version tag commits and format as list
        $commits = $commitMessages -split "`n" |
            Where-Object {
                $_ -and
                $_ -notmatch '^\s*v?\d+\.\d+\.\d+' -and  # Skip version commits
                $_.Trim().Length -gt 0
            } |
            ForEach-Object { "- $_" }

        if ($commits.Count -eq 0) {
            Write-Host "No meaningful commits found between $oldTag and $newTag"
            return $null
        }

        # Create changelog from commits
        $changelog = "## Changelog`n`n"
        $changelog += "### Commits between $oldTag and $newTag`n`n"
        $changelog += $commits -join "`n"

        Write-Host "Generated changelog from $($commits.Count) commits"
        return $changelog
    }
    catch {
        Write-Warning "Error generating changelog from commits: $($_.Exception.Message)"
        return $null
    }
    finally {
        Pop-Location
        # Ensure repository directory is cleaned up
        if (Test-Path $repoDir) {
            try {
                Remove-Item -Recurse -Force $repoDir -ErrorAction SilentlyContinue
                Write-Host "Cleaned up temporary repository directory"
            }
            catch {
                Write-Warning "Could not clean up temporary repository directory: $repoDir"
            }
        }
    }
}

# Function to generate changelog from diff between changelog files
function Get-ChangelogFromDiff {
    param($oldTag, $newTag, $tmpDir)

    # Try to fetch changelog files for both tags
    $oldChangelogPath = Join-Path $tmpDir 'old-changelog.md'
    $hasOldChangelog = Get-ChangelogContent $oldTag $oldChangelogPath

    $newChangelogPath = Join-Path $tmpDir 'new-changelog.md'
    $hasNewChangelog = Get-ChangelogContent $newTag $newChangelogPath

    # Return null if we don't have both changelog files
    if (-not $hasOldChangelog -or -not $hasNewChangelog) {
        return $null
    }

    Write-Host "Generating changelog diff between $oldTag and $newTag..."

    # Generate diff using git diff --no-index
    # git diff returns exit code 1 when differences are found, which is expected behavior
    $fullDiff = git diff --no-index $oldChangelogPath $newChangelogPath

    # The first lines are diff metadata, skip them
    $fullDiff = $fullDiff -split "`n" | Select-Object -Skip 4
    if ([string]::IsNullOrEmpty("$fullDiff")) {
        Write-Host "No differences found between $oldTag and $newTag"
        return $null
    } else {
        Write-Host "Successfully created a changelog diff - $($fullDiff.Count) lines"
    }

    # Extract only the added lines (lines starting with + but not ++)
    $addedLines = $fullDiff | Where-Object { $_ -match '^[+][^+]*' } | ForEach-Object { $_.Substring(1) }

    if ($addedLines.Count -eq 0) {
        Write-Host "No changelog additions found between $oldTag and $newTag"
        return $null
    }

    # Create clean changelog from added lines
    $changelog = ($addedLines -join "`n").Trim()

    if ($changelog.Length -eq 0) {
        return $null
    }

    # Add header if needed
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

    return $changelog
}

# Function to sanitize and format changelog content
function Format-ChangelogContent {
    param($changelog, $repoUrl)

    if ([string]::IsNullOrEmpty($changelog)) {
        return $null
    }

    # Apply standard formatting
    # Remove at-mentions
    $changelog = $changelog -replace '@', ''

    # Make PR/issue references into links to the original repository (unless they already are links)
    $changelog = $changelog -replace '(?<!\[)#([0-9]+)(?![\]0-9])', ('[#$1](' + $repoUrl + '/issues/$1)')

    # Replace any links pointing to github.com so that the target PRs/Issues don't get notification
    $changelog = $changelog -replace ('\(' + $prefix), '(https://github-redirect.dependabot.com/'

    # Limit the changelog length to ~60k to allow for other text in the PR body (total PR limit is 65536 characters)
    $limit = 60000
    if ($changelog.Length -gt $limit) {
        $oldLength = $changelog.Length
        Write-Warning "Truncating changelog because it's $($changelog.Length - $limit) characters longer than the limit $limit."
        while ($changelog.Length -gt $limit) {
            $lastNewlineIndex = $changelog.LastIndexOf("`n")
            if ($lastNewlineIndex -eq -1) {
                # No newlines found, just truncate to limit
                $changelog = $changelog.Substring(0, $limit)
                break
            }
            $changelog = $changelog.Substring(0, $lastNewlineIndex)
        }
        $changelog += "`n`n> :warning: **Changelog content truncated by $($oldLength - $changelog.Length) characters because it was over the limit ($limit) and wouldn't fit into PR description.**"
    }

    Write-Host "Final changelog length: $($changelog.Length) characters"
    return $changelog
}

try {
    Write-Host 'Fetching CHANGELOG files for comparison...'

    $changelog = $null

    # Try changelog file diff first, fall back to git commits if not available
    $changelog = Get-ChangelogFromDiff $OldTag $NewTag $tmpDir

    # Fall back to git commits if no changelog files or no diff found
    if (-not $changelog) {
        Write-Host "No changelog files found or no changes detected, falling back to git commits..."
        $changelog = Get-ChangelogFromCommits $RepoUrl $OldTag $NewTag $tmpDir
    }

    # Apply formatting and output result
    if ($changelog) {
        $formattedChangelog = Format-ChangelogContent $changelog $RepoUrl
        if ($formattedChangelog) {
            Write-Output $formattedChangelog
        } else {
            Write-Host "No changelog content to display after formatting"
        }
    } else {
        Write-Host "No changelog found between $OldTag and $NewTag"
    }
} catch {
    Write-Warning "Failed to get changelog: $($_.Exception.Message)"
} finally {
    if (Test-Path $tmpDir) {
        Write-Host 'Cleaning up temporary files...'
        Remove-Item -Recurse -Force -ErrorAction Continue $tmpDir
        Write-Host 'Cleanup complete.'
    }
}

# This resets the $LASTEXITCODE set by git diff above.
# Note that this only runs in the successful path.
exit 0
