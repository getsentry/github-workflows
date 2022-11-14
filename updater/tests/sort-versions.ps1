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

# TODO, currently doesn't respect (order) stuff like RC, Beta, etc.
# RunTest "sort with pre-releases" {
#     $sorted = SortVersions @('3.0.0', '5.4.11', 'v1.2.3', '5.4.1', '5.4.11-rc.0')
#     AssertEqual @('v1.2.3', '3.0.0', '5.4.1', '5.4.11-rc.0', '5.4.11') $sorted
# }
