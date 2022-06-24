param(
    [Parameter(Mandatory = $true)][string] $Path,
    [string] $Tag = ""
)

Set-StrictMode -Version latest

if (-not (Test-Path $Path ))
{
    throw "Dependency $Path doesn't exit";
}

# If it's a directory, we consider it a submodule dependendency. Otherwise, it must a properties-style file
$isSubmodule = (Test-Path $Path -PathType Container)

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
            $conf = Get-Content $Path -Raw | ConvertFrom-StringData
            $originalTag = $conf.version
            $url = $conf.repo

            # Check out to a temp directory to find out the tags.
            # We could use GH APIs instead but we already had the code to do this with `git` command.
            $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())
            Register-EngineEvent PowerShell.Exiting –Action { Remove-Item -Recurse -ErrorAction Continue -Path $tmpDir }
            git clone --no-checkout --depth 1 $url $tmpDir
            Push-Location $tmpDir
        }

        $url = $url -replace '\.git$', ''
        git fetch --tags
        $latestTagCommit = $(git rev-list --tags --max-count=1)
        $latestTag = $(git describe --tags $latestTagCommit)
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

    $content = Get-Content $Path
    $content = $content -replace "^(?<prop>version *= *).*$", "`${prop}$Tag"
    $content | Out-File $Path

    $readVersion = (Get-Content $Path -Raw | ConvertFrom-StringData).version

    if ("$readVersion" -ne "$Tag")
    {
        throw "Update failed - read-after-write yielded '$readVersion' instead of expected '$Tag'"
    }
}
