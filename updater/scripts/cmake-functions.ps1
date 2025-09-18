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
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to fetch tags from repository $repo (git ls-remote failed with exit code $LASTEXITCODE)"
        }
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

function Test-HashAncestry($repo, $oldHash, $newHash) {
    try {
        # Create a temporary directory for git operations
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        try {
            Push-Location $tempDir

            # Initialize a bare repository and add the remote
            git init --bare 2>$null | Out-Null
            git remote add origin $repo 2>$null | Out-Null

            # Fetch both commits
            git fetch origin $oldHash 2>$null | Out-Null
            git fetch origin $newHash 2>$null | Out-Null

            # Check if old hash is ancestor of new hash
            git merge-base --is-ancestor $oldHash $newHash 2>$null
            $isAncestor = $LastExitCode -eq 0

            return $isAncestor
        }
        finally {
            Pop-Location
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Host "Error: Could not validate ancestry for $oldHash -> $newHash : $_"
        # When in doubt, fail safely to prevent incorrect updates
        return $false
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
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to fetch tag $newValue from repository $repo (git ls-remote failed with exit code $LASTEXITCODE)"
        }
        if (-not $newHashRefs) {
            throw "Tag $newValue not found in repository $repo"
        }
        $newHash = ($newHashRefs -split '\s+')[0]
        $replacement = "$newHash # $newValue"

        # Validate ancestry: ensure old hash is reachable from new tag
        if (-not (Test-HashAncestry $repo $originalValue $newHash)) {
            throw "Cannot update: hash $originalValue is not in history of tag $newValue"
        }
    } else {
        $replacement = $newValue
    }

    # Update GIT_TAG value, replacing entire line content after GIT_TAG
    # This removes potentially outdated version-specific comments
    $pattern = "(FetchContent_Declare\s*\(\s*$depName\s+[^)]*GIT_TAG\s+)[^\r\n]+(\r?\n[^)]*\))"
    $newContent = [regex]::Replace($content, $pattern, "`${1}$replacement`${2}", 'Singleline')

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
