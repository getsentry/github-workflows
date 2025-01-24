. "$PSScriptRoot/common/test-utils.ps1"

function SortVersions([Parameter(Mandatory = $true)][string[]] $List)
{
    $result = & "$PSScriptRoot/../scripts/sort-versions.ps1" $List
    if (-not $?)
    {
        throw $result
    }
    $result
}

RunTest "sort standard versions" {
    $sorted = SortVersions @('3.0.0', '5.4.11', 'v1.2.3', '5.4.1')
    AssertEqual @('v1.2.3', '3.0.0', '5.4.1', '5.4.11') $sorted
}

RunTest "sort standard versions v2" {
    $sorted = SortVersions @('3.0.0', 'v6.0', '5.4.11', '5.5', 'v1.2.3', '5.4.1')
    AssertEqual @('v1.2.3', '3.0.0', '5.4.1', '5.4.11', '5.5', 'v6.0') $sorted
}

# https://semver.org/#spec-item-11
RunTest "sort with pre-releases" {
    $sorted = SortVersions @('1.0.0-rc.1', '1.0.0', '1.0.0-beta.11', '1.0.0-alpha.1', '1.0.0-beta', '1.0.0-alpha.beta', '1.0.0-alpha', '1.0.0-beta.2')
    AssertEqual @('1.0.0-alpha', '1.0.0-alpha.1', '1.0.0-alpha.beta', '1.0.0-beta', '1.0.0-beta.2', '1.0.0-beta.11', '1.0.0-rc.1', '1.0.0') $sorted
}
