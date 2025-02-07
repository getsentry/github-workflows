
BeforeAll {
    function SortVersions([Parameter(Mandatory = $true)][string[]] $List)
    {
        $result = & "$PSScriptRoot/../scripts/sort-versions.ps1" $List
        if (-not $?)
        {
            throw $result
        }
        $result
    }
}

Describe 'sort-versions' {
    It 'standard versions' {
        $sorted = SortVersions @('3.0.0', '5.4.11', 'v1.2.3', '5.4.1')
        $sorted | Should -Be @('v1.2.3', '3.0.0', '5.4.1', '5.4.11')
    }

    It 'standard versions v2' {
        $sorted = SortVersions @('3.0.0', 'v6.0', '5.4.11', '5.5', 'v1.2.3', '5.4.1')
        $sorted | Should -Be @('v1.2.3', '3.0.0', '5.4.1', '5.4.11', '5.5', 'v6.0')
    }

    # https://semver.org/#spec-item-11
    It 'pre-releases' {
        $sorted = SortVersions @('1.0.0-rc.1', '1.0.0', '1.0.0-beta.11', '1.0.0-alpha.1', '1.0.0-beta', '1.0.0-alpha.beta', '1.0.0-alpha', '1.0.0-beta.2')
        $sorted | Should -Be @('1.0.0-alpha', '1.0.0-alpha.1', '1.0.0-alpha.beta', '1.0.0-beta', '1.0.0-beta.2', '1.0.0-beta.11', '1.0.0-rc.1', '1.0.0')
    }
}
