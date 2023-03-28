Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
        Should -ActualValue $result.HasErrors() -BeFalse
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

    It "collects debug-files uploads" {
        $result = Invoke-SentryServer {
            Param([string]$url)
            Invoke-WebRequest -Uri "$url/api/0/projects/org/project/files/difs/assemble/" -Method Post `
                -Body '{"9a01653a":{"name":"file3.dylib","debug_id":"eb4a7644","chunks":["f84d"]},"abcd":{"name":"file2.so","debug_id":"foo","chunks":["ab"]}}'
            Invoke-WebRequest -Uri "$url/api/0/projects/org/project/files/difs/assemble/" -Method Post `
                -Body '{"9a01653a":{"name":"file1.dll","debug_id":"aa","chunks":["def"]}}'
        }
        Should -ActualValue $result.HasErrors() -BeFalse
        $result.UploadedDebugFiles() | Should -Be @('file3.dylib', 'file2.so', 'file1.dll')
    }
}