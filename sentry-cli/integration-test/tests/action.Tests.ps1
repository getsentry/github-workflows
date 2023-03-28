# In CI, the module is expected to be loaded
if (!(Test-Path env:CI ))
{
    Import-Module $PSScriptRoot/../action.psm1 -Force
}

Describe 'Invoke-SentryServer' {
    It "works fine with a simple callback" {
        $result = Invoke-SentryServer {
            Param([string]$url)
            $url | Should -Be "http://127.0.0.1:8000"
            "custom script output"
        }
        Should -ActualValue $result.ServerStdOut -HaveType [string[]]
        Should -ActualValue $result.ServerStdErr -HaveType [string[]]
        Should -ActualValue $result.ScriptOutput -HaveType [string[]]
        $result.ServerStdErr.Length | Should -Be 0
        $result.ServerStdOut.Length | Should -BeGreaterThan 1
        $result.ServerStdOut[0] | Should -Match "Server started successfully in [0-9]+ ms."
        $result.ServerStdOut | Should -Contain 'HTTP server listening on <ServerUri>'
        $result.ScriptOutput | Should -Be "custom script output"
    }

    It "rethrows an exception and recovers" {
        { Invoke-SentryServer { throw "hello there" } } | Should -Throw "hello there"
        $result = Invoke-SentryServer {}
        $result.ServerStdOut | Should -Contain 'HTTP server listening on <ServerUri>'
    }
}