# CMake FetchContent helper functions for update-dependency.ps1

function Parse-CMakeFetchContent($filePath, $depName) {
    $content = Get-Content $filePath -Raw

    if ($depName) {
        $pattern = "FetchContent_Declare\s*\(\s*$depName\s+([^)]+)\)"
    } else {
        # Find all FetchContent_Declare blocks
        $allMatches = [regex]::Matches($content, "FetchContent_Declare\s*\(\s*([a-zA-Z0-9_-]+)", 'Singleline')
        if ($allMatches.Count -eq 1) {
            $depName = $allMatches[0].Groups[1].Value
            $pattern = "FetchContent_Declare\s*\(\s*$depName\s+([^)]+)\)"
        } else {
            throw "Multiple FetchContent declarations found. Use #DepName syntax."
        }
    }

    $match = [regex]::Match($content, $pattern, 'Singleline,IgnoreCase')
    if (-not $match.Success) {
        throw "FetchContent_Declare for '$depName' not found in $filePath"
    }
    $block = $match.Groups[1].Value

    # Look for GIT_REPOSITORY and GIT_TAG patterns specifically
    # Exclude matches that are in comments (lines starting with #)
    $repoMatch = [regex]::Match($block, '(?m)^\s*GIT_REPOSITORY\s+(\S+)')
    $tagMatch = [regex]::Match($block, '(?m)^\s*GIT_TAG\s+(\S+)')

    $repo = if ($repoMatch.Success) { $repoMatch.Groups[1].Value } else { "" }
    $tag = if ($tagMatch.Success) { $tagMatch.Groups[1].Value } else { "" }

    if ([string]::IsNullOrEmpty($repo) -or [string]::IsNullOrEmpty($tag)) {
        throw "Could not parse GIT_REPOSITORY or GIT_TAG from FetchContent_Declare block"
    }

    return @{ GitRepository = $repo; GitTag = $tag; DepName = $depName }
}

function Find-TagForHash($repo, $hash) {
    try {
        $refs = git ls-remote --tags $repo
        foreach ($ref in $refs) {
            $commit, $tagRef = $ref -split '\s+', 2
            if ($commit -eq $hash) {
                return $tagRef -replace '^refs/tags/', ''
            }
        }
        return $null
    }
    catch {
        Write-Host "Warning: Could not resolve hash $hash to tag name: $_"
        return $null
    }
}

function Update-CMakeFile($filePath, $depName, $newValue) {
    $content = Get-Content $filePath -Raw
    $fetchContent = Parse-CMakeFetchContent $filePath $depName
    $originalValue = $fetchContent.GitTag
    $repo = $fetchContent.GitRepository
    $wasHash = $originalValue -match '^[a-f0-9]{40}$'

    if ($wasHash) {
        # Convert tag to hash and add comment
        $newHashRefs = git ls-remote $repo "refs/tags/$newValue"
        if (-not $newHashRefs) {
            throw "Tag $newValue not found in repository $repo"
        }
        $newHash = ($newHashRefs -split '\s+')[0]
        $replacement = "$newHash # $newValue"

        # Validate ancestry: ensure old hash is reachable from new tag
        # Note: Skipping ancestry check for now as it requires local repository
        # TODO: Implement proper ancestry validation for remote repositories
        Write-Host "Warning: Skipping ancestry validation for hash update from $originalValue to $newValue"
    } else {
        $replacement = $newValue
    }

    # Update GIT_TAG value, preserving formatting
    $pattern = "(FetchContent_Declare\s*\(\s*$depName\s+[^)]*GIT_TAG\s+)\S+([^#\r\n]*).*?(\s*[^)]*\))"
    $newContent = [regex]::Replace($content, $pattern, "`${1}$replacement`${3}", 'Singleline')

    if ($newContent -eq $content) {
        throw "Failed to update GIT_TAG in $filePath - pattern may not have matched"
    }

    $newContent | Out-File $filePath -NoNewline

    # Verify the update worked
    $verifyContent = Parse-CMakeFetchContent $filePath $depName
    $expectedValue = $wasHash ? $newHash : $newValue
    if ($verifyContent.GitTag -notmatch [regex]::Escape($expectedValue)) {
        throw "Update verification failed - read-after-write did not match expected value"
    }
}