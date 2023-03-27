# In CI, the module is expected to be loaded
if (!(Test-Path env:CI ))
{
    Import-Module $PSScriptRoot/../action.psm1 -Force
}

Describe 'Invoke-SentryServer' {
    It "works fine with a simple callback" {
        $output = Invoke-SentryServer {
            Param([string]$url)
            $url | Should -Be "http://127.0.0.1:8000"
        }
        $output | Should -BeOfType [string]
        $output | Should -Contain 'HTTP server listening on <ServerUri>'
    }
    It "rethrows an exception and recovers" {
        { Invoke-SentryServer { throw "hello there" } } | Should -Throw "hello there"
        $output = Invoke-SentryServer {}
        $output | Should -Contain 'HTTP server listening on <ServerUri>'
    }
}