param(
    # Path to the dependency, which can be either of the following:
    #  - a submodule
    #  - a [.properties](https://en.wikipedia.org/wiki/.properties) file with `version` (e.g. 1.0.0) and `repo` (e.g. https://github.com/getsentry/dependency)
    #  - a script (.sh, .ps1) that takes the executes a given action based on a given argument:
    #    * `get-version` - return the currently specified dependency version
    #    * `get-repo` - return the repository url (e.g.  https://github.com/getsentry/dependency)
    #    * `set-version` - update the dependency version (passed as another string argument after this one)
    [Parameter(Mandatory = $true)][string] $Path,
    # RegEx pattern that will be matched against available versions when picking the latest one
    [string] $Pattern = '',
    # Specific version - if passed, no discovery is performed and the version is set directly
    [string] $Tag = ''
)

Set-StrictMode -Version latest

if (-not (Test-Path $Path ))
{
    throw "Dependency $Path doesn't exit";
}

# If it's a directory, we consider it a submodule dependendency. Otherwise, it must a properties-style file
$isSubmodule = (Test-Path $Path -PathType Container)

if (-not $isSubmodule)
{
    $isScript = $Path -match '\.(ps1|sh)$'
    function DependencyConfig ([Parameter(Mandatory = $true)][string] $action, [string] $value = $null)
    {
        if ($isScript)
        {
            if (Get-Command 'chmod' -ErrorAction SilentlyContinue)
            {
                chmod +x $Path
            }
            $result = & $Path $action $value
            if (-not $?)
            {
                throw "Script execution failed: $Path $action $value | output: $result"
            }
            return $result
        }
        else
        {
            switch ($action)
            {
                "get-version"
                {
                    return (Get-Content $Path -Raw | ConvertFrom-StringData).version
                }
                "get-repo"
                {
                    return (Get-Content $Path -Raw | ConvertFrom-StringData).repo
                }
                "set-version"
                {
                    $content = Get-Content $Path
                    $content = $content -replace "^(?<prop>version *= *).*$", "`${prop}$value"
                    $content | Out-File $Path

                    $readVersion = (Get-Content $Path -Raw | ConvertFrom-StringData).version

                    if ("$readVersion" -ne "$value")
                    {
                        throw "Update failed - read-after-write yielded '$readVersion' instead of expected '$value'"
                    }
                }
                Default
                {
                    throw "Unknown action $action"
                }
            }
        }
    }
}

if ("$Tag" -eq "")
{
    try
    {
        if ($isSubmodule)
        {
            git submodule update --init --no-fetch --single-branch $Path
            Push-Location $Path
            $originalTag = $(git describe --tags)
            $url = $(git remote get-url origin)
        }
        else
        {
            $originalTag = DependencyConfig 'get-version'
            $url = DependencyConfig 'get-repo'

            # Check out to a temp directory to find out the tags.
            # We could use GH APIs instead but we already had the code to do this with `git` command.
            $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())
            Register-EngineEvent PowerShell.Exiting –Action { Remove-Item -Recurse -ErrorAction Continue -Path $tmpDir }
            git clone --no-checkout --depth 1 $url $tmpDir
            Push-Location $tmpDir
        }

        $url = $url -replace '\.git$', ''
        git fetch --tags
        [string[]]$tags = $(git -c 'versionsort.suffix=-' tag --list --sort=-v:refname)

        if ("$pattern" -ne '')
        {
            Write-Host "Filtering tags with pattern '$pattern'"
            $tags = $tags -match $Pattern
        }

        if ($tags.Length -le 0) {
            throw ("$pattern" -eq '') ? 'No tags found' : "No tags match pattern '$pattern'"
        }

        $latestTag = $tags[0]
        $mainBranch = $(git remote show origin | Select-String "HEAD branch: (.*)").Matches[0].Groups[1].Value
    }
    finally
    {
        Pop-Location
    }

    $latestTagNice = ($latestTag -match "^[0-9]") ? "v$latestTag" : $latestTag

    Write-Host '::echo::on'
    Write-Host "::set-output name=originalTag::$originalTag"
    Write-Host "::set-output name=latestTag::$latestTag"
    Write-Host "::set-output name=latestTagNice::$latestTagNice"
    Write-Host "::set-output name=url::$url"
    Write-Host "::set-output name=mainBranch::$mainBranch"

    $Tag = $latestTag
}

if ($isSubmodule)
{
    Write-Host "Updating submodule $Path to $Tag"
    Push-Location $Path
    git checkout $Tag
    Pop-Location
}
else
{
    Write-Host "Updating 'version' in $Path to $Tag"
    DependencyConfig 'set-version' $tag
}
