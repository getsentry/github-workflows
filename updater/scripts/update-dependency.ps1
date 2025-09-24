param(
    # Path to the dependency, which can be either of the following:
    #  - a submodule
    #  - a [.properties](https://en.wikipedia.org/wiki/.properties) file with `version` (e.g. 1.0.0) and `repo` (e.g. https://github.com/getsentry/dependency)
    #  - a script (.sh, .ps1) that takes the executes a given action based on a given argument:
    #    * `get-version` - return the currently specified dependency version
    #    * `get-repo` - return the repository url (e.g.  https://github.com/getsentry/dependency)
    #    * `set-version` - update the dependency version (passed as another string argument after this one)
    #  - a CMake file (.cmake) with FetchContent_Declare statements:
    #    * Use `path/to/file.cmake#DepName` to specify dependency name
    #    * Or just `path/to/file.cmake` if file contains single FetchContent_Declare
    [Parameter(Mandatory = $true)][string] $Path,
    # RegEx pattern that will be matched against available versions when picking the latest one
    [string] $Pattern = '',
    # RegEx pattern to match against GitHub release titles. Only releases with matching titles will be considered
    [string] $GhTitlePattern = '',
    # Specific version - if passed, no discovery is performed and the version is set directly
    [string] $Tag = ''
)

Set-StrictMode -Version latest
. "$PSScriptRoot/common.ps1"

# Parse CMake file with dependency name
if ($Path -match '^(.+\.cmake)(#(.+))?$') {
    $Path = $Matches[1]  # Set Path to file for existing logic
    if ($Matches[3]) {
        $cmakeDep = $Matches[3]
        # Validate dependency name follows CMake naming conventions
        if ($cmakeDep -notmatch '^[a-zA-Z][a-zA-Z0-9_.-]*$') {
            throw "Invalid CMake dependency name: '$cmakeDep'. Must start with letter and contain only alphanumeric, underscore, dot, or hyphen."
        }
    } else {
        $cmakeDep = $null  # Will auto-detect
    }
    $isCMakeFile = $true
} else {
    $cmakeDep = $null
    $isCMakeFile = $false
}

if (-not (Test-Path $Path )) {
    throw "Dependency $Path doesn't exit";
}

# If it's a directory, we consider it a submodule dependendency. Otherwise, it must a properties-style file or a script.
$isSubmodule = (Test-Path $Path -PathType Container)

function SetOutput([string] $name, $value) {
    if (Test-Path env:GITHUB_OUTPUT) {
        "$name=$value" | Tee-Object $env:GITHUB_OUTPUT -Append
    } else {
        "$name=$value"
    }
}

if (-not $isSubmodule) {
    $isScript = $Path -match '\.(ps1|sh)$'
    function DependencyConfig ([Parameter(Mandatory = $true)][string] $action, [string] $value = $null) {
        if ($isCMakeFile) {
            # CMake file handling
            switch ($action) {
                'get-version' {
                    $fetchContent = Parse-CMakeFetchContent $Path $cmakeDep
                    $currentValue = $fetchContent.GitTag
                    if ($currentValue -match '^[a-f0-9]{40}$') {
                        # Try to resolve hash to tag for version comparison
                        $repo = $fetchContent.GitRepository
                        $tagForHash = Find-TagForHash $repo $currentValue
                        return $tagForHash ?? $currentValue
                    }
                    return $currentValue
                }
                'get-repo' {
                    return (Parse-CMakeFetchContent $Path $cmakeDep).GitRepository
                }
                'set-version' {
                    Update-CMakeFile $Path $cmakeDep $value
                }
                default {
                    throw "Unknown action $action"
                }
            }
        } elseif ($isScript) {
            if (Get-Command 'chmod' -ErrorAction SilentlyContinue) {
                chmod +x $Path
                if ($LastExitCode -ne 0) {
                    throw 'chmod failed';
                }
            }
            try {
                $result = & $Path $action $value
                $failed = -not $?
            } catch {
                $result = $_
                $failed = $true
            }
            if ($failed) {
                throw "Script execution failed: $Path $action $value | output: $result"
            }
            return $result
        } else {
            switch ($action) {
                'get-version' {
                    return (Get-Content $Path -Raw | ConvertFrom-StringData).version
                }
                'get-repo' {
                    return (Get-Content $Path -Raw | ConvertFrom-StringData).repo
                }
                'set-version' {
                    $content = Get-Content $Path
                    $content = $content -replace '^(?<prop>version *= *).*$', "`${prop}$value"
                    $content | Out-File $Path

                    $readVersion = (Get-Content $Path -Raw | ConvertFrom-StringData).version

                    if ("$readVersion" -ne "$value") {
                        throw "Update failed - read-after-write yielded '$readVersion' instead of expected '$value'"
                    }
                }
                default {
                    throw "Unknown action $action"
                }
            }
        }
    }

    # Load CMake helper functions
    . "$PSScriptRoot/cmake-functions.ps1"
}

if ("$Tag" -eq '') {
    if ($isSubmodule) {
        git submodule update --init --no-fetch --single-branch $Path
        Push-Location $Path
        try {
            $originalTag = $(git describe --tags)
            git fetch --tags
            [string[]]$tags = $(git tag --list)
            $url = $(git remote get-url origin)
            $mainBranch = $(git remote show origin | Select-String 'HEAD branch: (.*)').Matches[0].Groups[1].Value
        } finally {
            Pop-Location
        }
    } else {
        $originalTag = DependencyConfig 'get-version'
        $url = DependencyConfig 'get-repo'

        # Get tags for a repo without cloning.
        [string[]]$tags = $(git ls-remote --refs --tags $url)
        $tags = $tags | ForEach-Object { ($_ -split '\s+')[1] -replace '^refs/tags/', '' }

        $headRef = ($(git ls-remote $url HEAD) -split '\s+')[0]
        if ("$headRef" -eq '') {
            throw "Couldn't determine repository head (no ref returned by ls-remote HEAD"
        }
        $mainBranch = (git ls-remote --heads $url | Where-Object { $_.StartsWith($headRef) }) -replace '.*\srefs/heads/', ''
    }

    $url = $url -replace '\.git$', ''

    # Filter by GitHub release titles if pattern is provided
    if ("$GhTitlePattern" -ne '') {
        Write-Host "Filtering tags by GitHub release title pattern '$GhTitlePattern'"

        # Parse GitHub repo owner/name from URL
        if ($url -notmatch 'github\.com[:/]([^/]+)/([^/]+?)(?:\.git)?$') {
            throw "Could not parse GitHub owner/repo from URL: $url"
        }

        $owner, $repo = $Matches[1], $Matches[2]

        # Fetch releases from GitHub API
        $releases = @(gh api "repos/$owner/$repo/releases" --jq '.[] | {tag_name: .tag_name, name: .name}' | ConvertFrom-Json)

        # Find tags that have matching release titles
        $validTags = @{}
        foreach ($release in $releases) {
            if ($release.name -match $GhTitlePattern) {
                $validTags[$release.tag_name] = $true
            }
        }

        # Filter tags to only include those with matching release titles
        $originalTagCount = $tags.Length
        $tags = @($tags | Where-Object { $validTags.ContainsKey($_) })
        Write-Host "GitHub release title filtering: $originalTagCount -> $($tags.Count) tags"
    }

    if ("$Pattern" -eq '') {
        # Use a default pattern that excludes pre-releases
        $Pattern = '^v?([0-9.]+)$'
    }

    Write-Host "Filtering tags with pattern '$Pattern'"
    $tags = $tags -match $Pattern

    if ($tags.Length -le 0) {
        throw "Found no tags matching pattern '$Pattern'"
    }

    $tags = & "$PSScriptRoot/sort-versions.ps1" $tags

    Write-Host "Sorted tags: $tags"
    $latestTag = $tags[-1]

    if (("$originalTag" -ne '') -and ("$latestTag" -ne '') -and ("$latestTag" -ne "$originalTag")) {
        do {
            # It's possible that the dependency was updated to a pre-release version manually in which case we don't want to
            # roll back, even though it's not the latest version matching the configured pattern.
            if ((GetComparableVersion $originalTag) -ge (GetComparableVersion $latestTag)) {
                Write-Host "SemVer represented by the original tag '$originalTag' is newer than the latest tag '$latestTag'. Skipping update."
                $latestTag = $originalTag
                break
            }

            # Verify that the latest tag actually points to a different commit. Otherwise, we don't need to update.
            $refs = $(git ls-remote --tags $url)
            $refOriginal = (($refs -match "refs/tags/$originalTag" ) -split '[ \t]') | Select-Object -First 1
            $refLatest = (($refs -match "refs/tags/$latestTag" ) -split '[ \t]') | Select-Object -First 1
            if ($refOriginal -eq $refLatest) {
                Write-Host "Latest tag '$latestTag' points to the same commit as the original tag '$originalTag'. Skipping update."
                $latestTag = $originalTag
                break
            }
        } while ($false)
    }

    $latestTagNice = ($latestTag -match '^[0-9]') ? "v$latestTag" : $latestTag

    SetOutput 'originalTag' $originalTag
    SetOutput 'latestTag' $latestTag
    SetOutput 'latestTagNice' $latestTagNice
    SetOutput 'url' $url
    SetOutput 'mainBranch' $mainBranch

    if ("$originalTag" -eq "$latestTag") {
        return
    }

    $Tag = $latestTag
}

if ($isSubmodule) {
    Write-Host "Updating submodule $Path to $Tag"
    Push-Location $Path
    git checkout $Tag
    Pop-Location
} else {
    Write-Host "Updating 'version' in $Path to $Tag"
    DependencyConfig 'set-version' $tag
}
